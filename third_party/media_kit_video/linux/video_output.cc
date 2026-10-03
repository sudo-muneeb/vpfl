// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output.h"
#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/texture_sw.h"

#include <epoxy/gl.h>
#include <gdk/gdkwayland.h>
#include <gdk/gdkx.h>

struct _VideoOutput {
  GObject parent_instance;
  TextureGL* texture_gl;
  TextureSW* texture_sw;
  EGLDisplay egl_display;
  EGLContext egl_context;
  EGLSurface egl_surface;
  EGLDisplay flutter_display;
  EGLContext flutter_context;
  gpointer native_display;
  gboolean wayland;
  gint hardware_rendering;
  guint8* pixel_buffer;
  GMutex mutex;
  gint frame_pending;
  gint fallback_pending;
  gint destroyed;
  mpv_handle* handle;
  mpv_render_context* render_context;
  gint64 width;
  gint64 height;
  VideoOutputConfiguration configuration;
  TextureUpdateCallback texture_update_callback;
  gpointer texture_update_callback_context;
  FlTextureRegistrar* texture_registrar;
};

G_DEFINE_TYPE(VideoOutput, video_output, G_TYPE_OBJECT)

static void video_output_start_software(VideoOutput* self);

static gboolean video_output_deliver_frame(gpointer data) {
  VideoOutput* self = VIDEO_OUTPUT(data);
  g_atomic_int_set(&self->frame_pending, 0);
  if (g_atomic_int_get(&self->destroyed)) return G_SOURCE_REMOVE;
  if (self->texture_gl != nullptr &&
      g_atomic_int_get(&self->hardware_rendering)) {
    fl_texture_registrar_mark_texture_frame_available(
        self->texture_registrar, FL_TEXTURE(self->texture_gl));
  } else if (self->texture_sw != nullptr && self->render_context != nullptr) {
    g_mutex_lock(&self->mutex);
    const gint64 width = video_output_get_width(self);
    const gint64 height = video_output_get_height(self);
    if (width > 0 && height > 0 &&
        width <= SW_RENDERING_MAX_WIDTH && height <= SW_RENDERING_MAX_HEIGHT) {
      gint32 size[]{static_cast<gint32>(width), static_cast<gint32>(height)};
      gint32 pitch = 4 * size[0];
      mpv_render_param params[]{
          {MPV_RENDER_PARAM_SW_SIZE, size},
          {MPV_RENDER_PARAM_SW_FORMAT, (void*)"rgb0"},
          {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
          {MPV_RENDER_PARAM_SW_POINTER, self->pixel_buffer},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      if (mpv_render_context_render(self->render_context, params) == 0) {
        fl_texture_registrar_mark_texture_frame_available(
            self->texture_registrar, FL_TEXTURE(self->texture_sw));
      }
    }
    g_mutex_unlock(&self->mutex);
  }
  return G_SOURCE_REMOVE;
}

static void video_output_frame_callback(void* data) {
  VideoOutput* self = VIDEO_OUTPUT(data);
  if (g_atomic_int_get(&self->destroyed)) return;
  if (g_atomic_int_compare_and_exchange(&self->frame_pending, 0, 1)) {
    g_main_context_invoke_full(nullptr, G_PRIORITY_DEFAULT,
                               video_output_deliver_frame,
                               g_object_ref(self), g_object_unref);
  }
}

static void video_output_release_gpu(VideoOutput* self) {
  if (self->render_context != nullptr) {
    mpv_render_context_set_update_callback(self->render_context, nullptr, nullptr);
  }
  if (self->egl_context != EGL_NO_CONTEXT) {
    if (eglMakeCurrent(self->egl_display, self->egl_surface,
                       self->egl_surface, self->egl_context)) {
      if (self->render_context != nullptr) {
        mpv_render_context_free(self->render_context);
        self->render_context = nullptr;
      }
      if (self->texture_gl != nullptr) texture_gl_release(self->texture_gl);
      eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                     EGL_NO_CONTEXT);
    } else {
      g_printerr("media_kit: Could not activate video context for cleanup: 0x%x\n",
                 eglGetError());
      // Avoid making mpv or GL calls without the context they require.
    }
    eglDestroyContext(self->egl_display, self->egl_context);
    self->egl_context = EGL_NO_CONTEXT;
  }
  if (self->egl_surface != EGL_NO_SURFACE) {
    eglDestroySurface(self->egl_display, self->egl_surface);
    self->egl_surface = EGL_NO_SURFACE;
  }
  g_atomic_int_set(&self->hardware_rendering, 0);
}

static gboolean video_output_software_fallback(gpointer data) {
  VideoOutput* self = VIDEO_OUTPUT(data);
  g_atomic_int_set(&self->fallback_pending, 0);
  if (g_atomic_int_get(&self->destroyed) || self->texture_gl == nullptr) {
    return G_SOURCE_REMOVE;
  }
  g_printerr("media_kit: Switching to software video output.\n");
  fl_texture_registrar_unregister_texture(self->texture_registrar,
                                          FL_TEXTURE(self->texture_gl));
  g_mutex_lock(&self->mutex);
  video_output_release_gpu(self);
  g_object_unref(self->texture_gl);
  self->texture_gl = nullptr;
  g_mutex_unlock(&self->mutex);
  // A failed EGL cleanup can leave mpv's GL context alive. Creating another
  // render context on that handle is unsafe; report the renderer as unavailable.
  if (self->render_context == nullptr) video_output_start_software(self);
  if (self->texture_update_callback != nullptr) {
    self->texture_update_callback(video_output_get_texture_id(self), 1, 1,
                                  self->texture_update_callback_context);
  }
  return G_SOURCE_REMOVE;
}

void video_output_fail_gpu(VideoOutput* self, const char* reason) {
  g_printerr("media_kit: GPU video output failed: %s\n", reason);
  if (!g_atomic_int_get(&self->destroyed) &&
      g_atomic_int_compare_and_exchange(&self->fallback_pending, 0, 1)) {
    g_main_context_invoke_full(nullptr, G_PRIORITY_DEFAULT,
                               video_output_software_fallback,
                               g_object_ref(self), g_object_unref);
  }
}

static void video_output_dispose(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);
  video_output_stop(self);
  if (self->texture_gl != nullptr) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_gl));
    g_mutex_lock(&self->mutex);
    video_output_release_gpu(self);
    g_object_unref(self->texture_gl);
    self->texture_gl = nullptr;
    g_mutex_unlock(&self->mutex);
  }
  if (self->texture_sw != nullptr) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    if (self->render_context != nullptr) {
      mpv_render_context_set_update_callback(self->render_context, nullptr, nullptr);
      mpv_render_context_free(self->render_context);
      self->render_context = nullptr;
    }
    g_free(self->pixel_buffer);
    self->pixel_buffer = nullptr;
    g_object_unref(self->texture_sw);
    self->texture_sw = nullptr;
  }
  g_mutex_clear(&self->mutex);
  g_free(self->texture_update_callback_context);
  G_OBJECT_CLASS(video_output_parent_class)->dispose(object);
}

void video_output_stop(VideoOutput* self) {
  g_atomic_int_set(&self->destroyed, 1);
  if (self->render_context != nullptr) {
    mpv_render_context_set_update_callback(self->render_context, nullptr, nullptr);
  }
}

static void video_output_class_init(VideoOutputClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_dispose;
}

static void video_output_init(VideoOutput* self) {
  self->texture_gl = nullptr;
  self->texture_sw = nullptr;
  self->egl_display = EGL_NO_DISPLAY;
  self->egl_context = EGL_NO_CONTEXT;
  self->egl_surface = EGL_NO_SURFACE;
  self->flutter_display = EGL_NO_DISPLAY;
  self->flutter_context = EGL_NO_CONTEXT;
  self->native_display = nullptr;
  self->wayland = FALSE;
  g_atomic_int_set(&self->hardware_rendering, 0);
  self->pixel_buffer = nullptr;
  self->handle = nullptr;
  self->render_context = nullptr;
  self->width = 0;
  self->height = 0;
  self->texture_update_callback = nullptr;
  self->texture_update_callback_context = nullptr;
  self->texture_registrar = nullptr;
  g_mutex_init(&self->mutex);
}

static void video_output_start_software(VideoOutput* self) {
#ifdef MPV_RENDER_API_TYPE_SW
  self->pixel_buffer = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
  self->texture_sw = texture_sw_new(self);
  if (!fl_texture_registrar_register_texture(
          self->texture_registrar, FL_TEXTURE(self->texture_sw))) {
    g_printerr("media_kit: Could not register software video texture.\n");
    g_object_unref(self->texture_sw);
    self->texture_sw = nullptr;
    g_clear_pointer(&self->pixel_buffer, g_free);
    return;
  }
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_SW},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  const int result = mpv_render_context_create(
      &self->render_context, self->handle, params);
  if (result < 0) {
    g_printerr("media_kit: Could not create software mpv context: %d\n", result);
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    g_object_unref(self->texture_sw);
    self->texture_sw = nullptr;
    g_clear_pointer(&self->pixel_buffer, g_free);
    return;
  }
  mpv_render_context_set_update_callback(self->render_context,
                                         video_output_frame_callback, self);
  g_print("media_kit: VideoOutput: S/W rendering.\n");
#else
  g_printerr("media_kit: Software rendering is unavailable in this libmpv.\n");
#endif
}

VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              FlView* view,
                              gint64 handle,
                              VideoOutputConfiguration configuration) {
  VideoOutput* self = VIDEO_OUTPUT(g_object_new(video_output_get_type(), nullptr));
  self->texture_registrar = texture_registrar;
  self->handle = reinterpret_cast<mpv_handle*>(handle);
  self->width = configuration.width;
  self->height = configuration.height;
  self->configuration = configuration;
  mpv_set_option_string(self->handle, "video-sync", "audio");

  if (configuration.enable_hardware_acceleration) {
    GdkDisplay* display = gdk_display_get_default();
    if (display != nullptr && GDK_IS_WAYLAND_DISPLAY(display)) {
      self->wayland = TRUE;
      self->native_display = gdk_wayland_display_get_wl_display(display);
    } else if (display != nullptr && GDK_IS_X11_DISPLAY(display)) {
      self->native_display = gdk_x11_display_get_xdisplay(display);
    }
    if (self->native_display != nullptr) {
      self->texture_gl = texture_gl_new(self);
      if (fl_texture_registrar_register_texture(
              texture_registrar, FL_TEXTURE(self->texture_gl))) {
        // Flutter invokes populate with its actual raster EGL context current.
        // The first notification bootstraps mpv; later ones come from mpv.
        fl_texture_registrar_mark_texture_frame_available(
            texture_registrar, FL_TEXTURE(self->texture_gl));
        g_print("media_kit: VideoOutput: Waiting for Flutter raster context.\n");
        return self;
      }
      g_object_unref(self->texture_gl);
      self->texture_gl = nullptr;
      g_printerr("media_kit: Could not register GPU video texture.\n");
    } else {
      g_printerr("media_kit: Unsupported GTK display for GPU video.\n");
    }
  }
  video_output_start_software(self);
  return self;
}

bool video_output_prepare_gpu(VideoOutput* self, EGLDisplay flutter_display,
                              EGLContext flutter_context) {
  if (g_atomic_int_get(&self->destroyed) ||
      g_atomic_int_get(&self->fallback_pending)) return false;
  if (self->render_context != nullptr) {
    if (self->flutter_display == flutter_display &&
        self->flutter_context == flutter_context) return true;
    video_output_fail_gpu(self, "Flutter raster EGL context changed");
    return false;
  }
  if (flutter_display == EGL_NO_DISPLAY || flutter_context == EGL_NO_CONTEXT) {
    video_output_fail_gpu(self, "Flutter raster EGL context unavailable");
    return false;
  }
  if (g_strcmp0(g_getenv("VPFL_TEST_FAIL_GPU_INIT"), "1") == 0) {
    video_output_fail_gpu(self, "GPU initialization failure injected for test");
    return false;
  }
  EGLint config_id = 0;
  EGLint client_version = 2;
  if (!eglQueryContext(flutter_display, flutter_context, EGL_CONFIG_ID,
                       &config_id) ||
      !eglQueryContext(flutter_display, flutter_context,
                       EGL_CONTEXT_CLIENT_VERSION, &client_version)) {
    video_output_fail_gpu(self, "Could not inspect Flutter EGL context");
    return false;
  }
  EGLConfig config = nullptr;
  EGLint count = 0;
  EGLint attributes[] = {EGL_CONFIG_ID, config_id, EGL_NONE};
  if (!eglChooseConfig(flutter_display, attributes, &config, 1, &count) ||
      count == 0) {
    video_output_fail_gpu(self, "Flutter EGL config unavailable");
    return false;
  }
  EGLint surface_types = 0;
  if (!eglGetConfigAttrib(flutter_display, config, EGL_SURFACE_TYPE,
                          &surface_types) ||
      !(surface_types & EGL_PBUFFER_BIT)) {
    video_output_fail_gpu(self, "Flutter EGL config has no pbuffer support");
    return false;
  }
  self->egl_display = flutter_display;
  self->flutter_display = flutter_display;
  self->flutter_context = flutter_context;
  const EGLenum previous_api = eglQueryAPI();
  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    video_output_fail_gpu(self, "OpenGL ES EGL API unavailable");
    return false;
  }
  EGLint context_attributes[] = {
      EGL_CONTEXT_CLIENT_VERSION, client_version, EGL_NONE};
  self->egl_context = eglCreateContext(
      flutter_display, config, flutter_context, context_attributes);
  EGLint surface_attributes[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
  if (self->egl_context != EGL_NO_CONTEXT) {
    self->egl_surface = eglCreatePbufferSurface(
        flutter_display, config, surface_attributes);
  }
  eglBindAPI(previous_api);
  if (self->egl_context == EGL_NO_CONTEXT ||
      self->egl_surface == EGL_NO_SURFACE) {
    g_printerr("media_kit: Could not create shared EGL context: 0x%x\n",
               eglGetError());
    video_output_fail_gpu(self, "Shared EGL context unavailable");
    return false;
  }
  const EGLSurface flutter_draw = eglGetCurrentSurface(EGL_DRAW);
  const EGLSurface flutter_read = eglGetCurrentSurface(EGL_READ);
  if (!eglMakeCurrent(self->egl_display, self->egl_surface,
                      self->egl_surface, self->egl_context)) {
    g_printerr("media_kit: Could not make shared context current: 0x%x\n",
               eglGetError());
    video_output_fail_gpu(self, "Shared EGL context could not be activated");
    return false;
  }
  mpv_opengl_init_params gl_init_params{
      [](auto, auto name) { return (void*)eglGetProcAddress(name); }, nullptr};
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_OPENGL},
      {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
      {MPV_RENDER_PARAM_INVALID, nullptr},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  if (self->native_display != nullptr) {
    params[2].type = self->wayland ? MPV_RENDER_PARAM_WL_DISPLAY
                                   : MPV_RENDER_PARAM_X11_DISPLAY;
    params[2].data = self->native_display;
  }
  const int result = mpv_render_context_create(
      &self->render_context, self->handle, params);
  if (!eglMakeCurrent(flutter_display, flutter_draw, flutter_read,
                      flutter_context)) {
    g_printerr("media_kit: Could not restore Flutter context after init: 0x%x\n",
               eglGetError());
    video_output_fail_gpu(self, "Flutter EGL context restore failed");
    return false;
  }
  if (result < 0) {
    g_printerr("media_kit: Could not create mpv GPU context: %d\n", result);
    video_output_fail_gpu(self, "mpv GPU renderer unavailable");
    return false;
  }
  g_atomic_int_set(&self->hardware_rendering, 1);
  mpv_render_context_set_update_callback(self->render_context,
                                         video_output_frame_callback, self);
  g_print("media_kit: VideoOutput: H/W rendering with shared Flutter EGL context.\n");
  if (self->texture_update_callback != nullptr) {
    self->texture_update_callback(video_output_get_texture_id(self), 1, 1,
                                  self->texture_update_callback_context);
  }
  return true;
}

void video_output_lock(VideoOutput* self) { g_mutex_lock(&self->mutex); }
void video_output_unlock(VideoOutput* self) { g_mutex_unlock(&self->mutex); }

void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context) {
  self->texture_update_callback = texture_update_callback;
  self->texture_update_callback_context = texture_update_callback_context;
  // Notify initial dimensions as (1, 1) if |width| & |height| are 0 i.e.
  // texture & video frame size is based on playing file's resolution. This
  // will make sure that `Texture` widget on Flutter's widget tree is actually
  // mounted & |fl_texture_registrar_mark_texture_frame_available| actually
  // invokes the |TextureGL| or |TextureSW| callbacks. Otherwise it will be a
  // never ending deadlock where no video frames are ever rendered.
  gint64 texture_id = video_output_get_texture_id(self);
  if (self->width == 0 || self->height == 0) {
    self->texture_update_callback(texture_id, 1, 1,
                                  self->texture_update_callback_context);
  } else {
    self->texture_update_callback(texture_id, self->width, self->height,
                                  self->texture_update_callback_context);
  }
}

void video_output_set_size(VideoOutput* self, gint64 width, gint64 height) {
  g_mutex_lock(&self->mutex);
  self->width = width;
  self->height = height;
  g_mutex_unlock(&self->mutex);
}

mpv_render_context* video_output_get_render_context(VideoOutput* self) {
  return self->render_context;
}

EGLDisplay video_output_get_egl_display(VideoOutput* self) {
  return self->egl_display;
}

EGLContext video_output_get_egl_context(VideoOutput* self) {
  return self->egl_context;
}

EGLSurface video_output_get_egl_surface(VideoOutput* self) {
  return self->egl_surface;
}

bool video_output_get_hardware_rendering(VideoOutput* self) {
  return g_atomic_int_get(&self->hardware_rendering) != 0;
}

const char* video_output_get_rendering_mode(VideoOutput* self) {
  if (self->texture_gl != nullptr) {
    return g_atomic_int_get(&self->hardware_rendering) ? "gpu" : "initializing";
  }
  return self->texture_sw != nullptr && self->render_context != nullptr
             ? "software" : "unavailable";
}

guint8* video_output_get_pixel_buffer(VideoOutput* self) {
  return self->pixel_buffer;
}

static void video_output_dimensions(VideoOutput* self, gint64* width,
                                    gint64* height) {
  *width = self->width;
  *height = self->height;
  // The raster callback must not query ordinary libmpv properties while it
  // owns the render context. Dart's videoParams stream sends SetSize instead.
  if (self->texture_gl != nullptr) return;
  if (*width <= 0 || *height <= 0) {
    mpv_node params{};
    if (mpv_get_property(self->handle, "video-out-params", MPV_FORMAT_NODE,
                         &params) < 0) {
      *width = *height = 0;
      return;
    }
    gint64 dw = 0, dh = 0, rotate = 0;
    if (params.format == MPV_FORMAT_NODE_MAP && params.u.list != nullptr) {
      for (int i = 0; i < params.u.list->num; ++i) {
        const char* key = params.u.list->keys[i];
        const mpv_node& value = params.u.list->values[i];
        if (value.format != MPV_FORMAT_INT64) continue;
        if (strcmp(key, "dw") == 0) dw = value.u.int64;
        if (strcmp(key, "dh") == 0) dh = value.u.int64;
        if (strcmp(key, "rotate") == 0) rotate = value.u.int64;
      }
    }
    mpv_free_node_contents(&params);
    *width = rotate == 0 || rotate == 180 ? dw : dh;
    *height = rotate == 0 || rotate == 180 ? dh : dw;
  }
  if (*width <= 0 || *height <= 0 || self->texture_sw == nullptr) return;
  // Scale as a pair: integer division before multiplication can make a
  // portrait video's width zero and leave the software buffer unusable.
  if (*width > SW_RENDERING_MAX_WIDTH) {
    *height = MAX(1, *height * SW_RENDERING_MAX_WIDTH / *width);
    *width = SW_RENDERING_MAX_WIDTH;
  }
  if (*height > SW_RENDERING_MAX_HEIGHT) {
    *width = MAX(1, *width * SW_RENDERING_MAX_HEIGHT / *height);
    *height = SW_RENDERING_MAX_HEIGHT;
  }
}

gint64 video_output_get_width(VideoOutput* self) {
  gint64 width = 0, height = 0;
  video_output_dimensions(self, &width, &height);
  return width;
}

gint64 video_output_get_height(VideoOutput* self) {
  gint64 width = 0, height = 0;
  video_output_dimensions(self, &width, &height);
  return height;
}

gint64 video_output_get_texture_id(VideoOutput* self) {
  // H/W
  if (self->texture_gl) {
    return (gint64)self->texture_gl;
  }
  // S/W
  if (self->texture_sw) {
    return (gint64)self->texture_sw;
  }
  return -1;
}

void video_output_notify_texture_update(VideoOutput* self) {
  gint64 id = video_output_get_texture_id(self);
  gint64 width = video_output_get_width(self);
  gint64 height = video_output_get_height(self);
  gpointer context = self->texture_update_callback_context;
  if (self->texture_update_callback != NULL) {
    self->texture_update_callback(id, width, height, context);
  }
}

void video_output_request_frame(VideoOutput* self) {
  if (!g_atomic_int_get(&self->destroyed) && self->texture_gl != nullptr) {
    fl_texture_registrar_mark_texture_frame_available(
        self->texture_registrar, FL_TEXTURE(self->texture_gl));
  }
}

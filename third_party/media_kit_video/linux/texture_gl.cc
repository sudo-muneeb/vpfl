// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <epoxy/egl.h>
#include <epoxy/gl.h>

struct _TextureGL {
  FlTextureGL parent_instance;
  GLuint name;
  GLuint fbo;
  guint32 current_width;
  guint32 current_height;
  VideoOutput* video_output;  // Owned by VideoOutput; unregister before freeing.
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

namespace {

struct OutputLock {
  explicit OutputLock(VideoOutput* output) : output(output) {
    video_output_lock(output);
  }
  ~OutputLock() { video_output_unlock(output); }
  VideoOutput* output;
};

struct FlutterContext {
  FlutterContext()
      : display(eglGetCurrentDisplay()),
        context(eglGetCurrentContext()),
        draw(eglGetCurrentSurface(EGL_DRAW)),
        read(eglGetCurrentSurface(EGL_READ)) {}

  bool valid() const {
    return display != EGL_NO_DISPLAY && context != EGL_NO_CONTEXT;
  }

  bool restore() const {
    if (eglMakeCurrent(display, draw, read, context)) return true;
    g_printerr("media_kit: Could not restore Flutter EGL context: 0x%x\n",
               eglGetError());
    return false;
  }

  EGLDisplay display;
  EGLContext context;
  EGLSurface draw;
  EGLSurface read;
};

bool make_video_context_current(VideoOutput* output) {
  if (eglMakeCurrent(video_output_get_egl_display(output),
                     video_output_get_egl_surface(output),
                     video_output_get_egl_surface(output),
                     video_output_get_egl_context(output))) {
    return true;
  }
  g_printerr("media_kit: Could not activate video EGL context: 0x%x\n",
             eglGetError());
  return false;
}

gboolean return_placeholder(TextureGL* self, guint32* target, guint32* name,
                            guint32* width, guint32* height) {
  // Flutter's texture callback may dereference the returned texture even when
  // the GPU setup is being replaced. Keep one valid pixel until unregister.
  if (eglGetCurrentContext() == EGL_NO_CONTEXT) return FALSE;
  if (self->name == 0 || !glIsTexture(self->name)) {
    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);
  }
  self->current_width = 1;
  self->current_height = 1;
  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = 1;
  *height = 1;
  return TRUE;
}

}  // namespace

static void texture_gl_init(TextureGL* self) {
  self->name = 0;
  self->fbo = 0;
  self->current_width = 0;
  self->current_height = 0;
  self->video_output = nullptr;
}

static void texture_gl_dispose(GObject* object) {
  // GL objects are released by VideoOutput while its own context is current.
  TextureGL* self = TEXTURE_GL(object);
  self->video_output = nullptr;
  G_OBJECT_CLASS(texture_gl_parent_class)->dispose(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->dispose = texture_gl_dispose;
}

TextureGL* texture_gl_new(VideoOutput* video_output) {
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), nullptr));
  self->video_output = video_output;
  return self;
}

void texture_gl_release(TextureGL* self) {
  if (self->fbo) glDeleteFramebuffers(1, &self->fbo);
  if (self->name) glDeleteTextures(1, &self->name);
  self->fbo = 0;
  self->name = 0;
  self->video_output = nullptr;
}

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* output = self->video_output;
  if (output == nullptr) return FALSE;
  OutputLock lock(output);
  FlutterContext flutter;
  if (!flutter.valid()) {
    video_output_fail_gpu(output, "Flutter raster EGL context unavailable");
    return return_placeholder(self, target, name, width, height);
  }
  if (!video_output_prepare_gpu(output, flutter.display, flutter.context)) {
    return return_placeholder(self, target, name, width, height);
  }
  if (!make_video_context_current(output)) {
    video_output_fail_gpu(output, "Could not activate shared video context");
    return return_placeholder(self, target, name, width, height);
  }

  bool success = true;
  bool resized = false;
  gint64 video_width = video_output_get_width(output);
  gint64 video_height = video_output_get_height(output);
  const bool real_frame = video_width > 0 && video_height > 0;
  if (!real_frame) video_width = video_height = 1;
  GLint max_size = 0;
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_size);
  if (video_width > max_size || video_height > max_size || max_size <= 0) {
    g_printerr("media_kit: Video dimensions exceed GL texture limit: %ld x %ld (max %d)\n",
               static_cast<long>(video_width), static_cast<long>(video_height), max_size);
    success = false;
  }

  if (success && (self->name == 0 || self->fbo == 0 ||
                  self->current_width != video_width ||
                  self->current_height != video_height)) {
    if (self->fbo) glDeleteFramebuffers(1, &self->fbo);
    if (self->name) glDeleteTextures(1, &self->name);
    self->fbo = 0;
    self->name = 0;
    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, static_cast<GLsizei>(video_width),
                 static_cast<GLsizei>(video_height), 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, nullptr);
    glGenFramebuffers(1, &self->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, self->name, 0);
    const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    const GLenum gl_error = glGetError();
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (self->name == 0 || self->fbo == 0 ||
        status != GL_FRAMEBUFFER_COMPLETE || gl_error != GL_NO_ERROR) {
      g_printerr("media_kit: Video framebuffer failed: status=0x%x GL=0x%x\n",
                 status, gl_error);
      success = false;
    } else {
      self->current_width = static_cast<guint32>(video_width);
      self->current_height = static_cast<guint32>(video_height);
      resized = real_frame;
    }
  }

  if (success && real_frame) {
    glBindFramebuffer(GL_FRAMEBUFFER, self->fbo);
    mpv_opengl_fbo fbo{static_cast<gint32>(self->fbo),
                       static_cast<gint32>(video_width),
                       static_cast<gint32>(video_height), 0};
    int flip_y = 0;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
        {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
        {MPV_RENDER_PARAM_INVALID, nullptr},
    };
    const int result = mpv_render_context_render(
        video_output_get_render_context(output), params);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (result < 0 || glGetError() != GL_NO_ERROR) {
      g_printerr("media_kit: mpv video render failed: %d\n", result);
      success = false;
    }
  }
  glFlush();
  if (!flutter.restore()) success = false;
  if (!success) {
    video_output_fail_gpu(output, "Shared GPU frame failed");
    return return_placeholder(self, target, name, width, height);
  }
  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = self->current_width;
  *height = self->current_height;
  if (resized) video_output_notify_texture_update(output);
  return TRUE;
}

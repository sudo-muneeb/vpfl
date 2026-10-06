#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
  GtkWindow* window;
  gboolean allow_close;
  gboolean close_requested;
  guint close_timeout;
  GtkWidget* resize_handles[8];
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

struct ResizeHandleData {
  GtkWindow* window;
  GdkWindowEdge edge;
  const gchar* cursor_name;
  GdkCursorType fallback_cursor;
};

// Keep the hit area and cursor in GTK, outside Flutter's pointer hit testing.
// This also gives the resize drag the original GDK button event and timestamp.
static void resize_handle_realize_cb(GtkWidget* widget, gpointer user_data) {
  const auto* data = static_cast<ResizeHandleData*>(user_data);
  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  GdkDisplay* display = gdk_window_get_display(gdk_window);
  GdkCursor* cursor = gdk_cursor_new_from_name(display, data->cursor_name);
  if (cursor == nullptr) {
    cursor = gdk_cursor_new_for_display(display, data->fallback_cursor);
  }
  if (cursor != nullptr) {
    gdk_window_set_cursor(gdk_window, cursor);
    g_object_unref(cursor);
  }
}

static gboolean resize_handle_press_cb(GtkWidget*,
                                       GdkEventButton* event,
                                       gpointer user_data) {
  const auto* data = static_cast<ResizeHandleData*>(user_data);
  if (event->button != GDK_BUTTON_PRIMARY ||
      gtk_window_is_maximized(data->window)) {
    return FALSE;
  }
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(data->window));
  if (gdk_window == nullptr ||
      (gdk_window_get_state(gdk_window) & GDK_WINDOW_STATE_FULLSCREEN)) {
    return FALSE;
  }
  gtk_window_begin_resize_drag(data->window, data->edge, event->button,
                               static_cast<gint>(event->x_root),
                               static_cast<gint>(event->y_root), event->time);
  return TRUE;
}

static gboolean window_state_cb(GtkWidget*,
                                GdkEventWindowState* event,
                                gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gboolean resizable =
      !(event->new_window_state &
        (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN));
  for (GtkWidget* handle : self->resize_handles) {
    if (handle == nullptr) continue;
    if (resizable) {
      gtk_widget_show(handle);
    } else {
      gtk_widget_hide(handle);
    }
  }
  return FALSE;
}

static void add_resize_handle(MyApplication* self, GtkOverlay* overlay,
                              guint index, GdkWindowEdge edge,
                              const gchar* cursor_name,
                              GdkCursorType fallback_cursor, GtkAlign halign,
                              GtkAlign valign, gint width, gint height) {
  GtkWidget* handle = gtk_event_box_new();
  gtk_event_box_set_visible_window(GTK_EVENT_BOX(handle), FALSE);
  gtk_widget_set_halign(handle, halign);
  gtk_widget_set_valign(handle, valign);
  gtk_widget_set_size_request(handle, width, height);
  gtk_widget_add_events(handle, GDK_BUTTON_PRESS_MASK);
  auto* data = g_new0(ResizeHandleData, 1);
  data->window = self->window;
  data->edge = edge;
  data->cursor_name = cursor_name;
  data->fallback_cursor = fallback_cursor;
  g_object_set_data_full(G_OBJECT(handle), "vpfl-resize-handle", data, g_free);
  g_signal_connect(handle, "realize", G_CALLBACK(resize_handle_realize_cb),
                   data);
  g_signal_connect(handle, "button-press-event",
                   G_CALLBACK(resize_handle_press_cb), data);
  gtk_overlay_add_overlay(overlay, handle);
  gtk_overlay_set_overlay_pass_through(overlay, handle, FALSE);
  gtk_widget_show(handle);
  self->resize_handles[index] = handle;
}

static void lifecycle_log(const gchar* event) {
  if (g_strcmp0(g_getenv("VPFL_LIFECYCLE_TRACE"), "1") == 0) {
    g_message("vpfl.lifecycle ts_us=%" G_GINT64_FORMAT " thread=%p event=%s",
              g_get_real_time(), g_thread_self(), event);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Both the window-manager close and our Flutter button use the same awaited
// Dart shutdown. A timeout still lets GTK close if Dart cannot respond.
static gboolean window_delete_cb(GtkWidget* widget, GdkEvent* event,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  lifecycle_log("window.close.requested.native");
  if (self->allow_close) return FALSE;
  if (self->close_requested) return TRUE;
  self->close_requested = TRUE;
  if (self->window_channel != nullptr) {
    fl_method_channel_invoke_method(self->window_channel, "requestClose",
                                    nullptr, nullptr, nullptr, nullptr);
  }
  self->close_timeout = g_timeout_add_seconds(10, [](gpointer data) -> gboolean {
    MyApplication* app = MY_APPLICATION(data);
    app->close_timeout = 0;
    if (app->window != nullptr) {
      g_warning("VPFL shutdown timed out; closing the window");
      app->allow_close = TRUE;
      gtk_window_close(app->window);
    }
    return G_SOURCE_REMOVE;
  }, self);
  return TRUE;
}

static void window_destroy_cb(GtkWidget* widget, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->window = nullptr;
  for (GtkWidget*& handle : self->resize_handles) {
    handle = nullptr;
  }
  if (self->close_timeout != 0) {
    g_source_remove(self->close_timeout);
    self->close_timeout = 0;
  }
}

// Native window actions used by VPFL's Flutter-drawn title bar.
static void window_method_call(FlMethodChannel* channel,
                               FlMethodCall* call,
                               gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  GtkWindow* window = self->window;
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
  } else if (g_strcmp0(method, "close") == 0) {
    lifecycle_log("window.close.native");
    self->allow_close = TRUE;
    g_idle_add([](gpointer data) -> gboolean {
      gtk_window_close(GTK_WINDOW(data));
      g_object_unref(data);
      return G_SOURCE_REMOVE;
    }, g_object_ref(window));
  } else if (g_strcmp0(method, "startDrag") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* x = fl_value_lookup_string(args, "x");
    FlValue* y = fl_value_lookup_string(args, "y");
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    if (x != nullptr && y != nullptr && gdk_window != nullptr) {
      gint origin_x = 0;
      gint origin_y = 0;
      gdk_window_get_origin(gdk_window, &origin_x, &origin_y);
      const gint root_x = origin_x + fl_value_get_int(x);
      const gint root_y = origin_y + fl_value_get_int(y);
      gtk_window_begin_move_drag(window, 1, root_x, root_y,
                                 GDK_CURRENT_TIME);
    }
  } else if (g_strcmp0(method, "isMaximized") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  if (response == nullptr) {
    const gboolean return_state =
        g_strcmp0(method, "isMaximized") == 0 ||
        g_strcmp0(method, "toggleMaximize") == 0;
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(return_state
        ? fl_value_new_bool(gtk_window_is_maximized(window))
        : fl_value_new_null()));
  }
  fl_method_call_respond(call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  self->allow_close = FALSE;
  self->close_requested = FALSE;
  g_signal_connect(window, "delete-event", G_CALLBACK(window_delete_cb), self);
  g_signal_connect(window, "destroy", G_CALLBACK(window_destroy_cb), self);
  g_signal_connect(window, "window-state-event", G_CALLBACK(window_state_cb),
                   self);
  gtk_window_set_icon_name(window, "com.app.vpfl");
  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path != nullptr) {
    g_autofree gchar* executable_dir = g_path_get_dirname(executable_path);
    g_autofree gchar* icon_path = g_build_filename(
        executable_dir, "data", "flutter_assets", "vpfl-logo.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_IS_REGULAR)) {
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
    }
  }

  gtk_window_set_title(window, "VPFL");
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_default_size(window, 1280, 720);
  GdkGeometry geometry = {};
  geometry.min_width = 760;
  geometry.min_height = 480;
  gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  GtkWidget* overlay = gtk_overlay_new();
  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), overlay);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_widget_show(overlay);

  // Native, input-only GTK edge windows sit over the Flutter surface. The
  // corners are added last so their diagonal cursors win at intersections.
  GtkOverlay* resize_overlay = GTK_OVERLAY(overlay);
  add_resize_handle(self, resize_overlay, 0, GDK_WINDOW_EDGE_NORTH,
                    "n-resize", GDK_TOP_SIDE, GTK_ALIGN_FILL, GTK_ALIGN_START,
                    -1, 7);
  add_resize_handle(self, resize_overlay, 1, GDK_WINDOW_EDGE_SOUTH,
                    "s-resize", GDK_BOTTOM_SIDE, GTK_ALIGN_FILL, GTK_ALIGN_END,
                    -1, 7);
  add_resize_handle(self, resize_overlay, 2, GDK_WINDOW_EDGE_WEST,
                    "w-resize", GDK_LEFT_SIDE, GTK_ALIGN_START, GTK_ALIGN_FILL,
                    7, -1);
  add_resize_handle(self, resize_overlay, 3, GDK_WINDOW_EDGE_EAST,
                    "e-resize", GDK_RIGHT_SIDE, GTK_ALIGN_END, GTK_ALIGN_FILL,
                    7, -1);
  add_resize_handle(self, resize_overlay, 4, GDK_WINDOW_EDGE_NORTH_WEST,
                    "nw-resize", GDK_TOP_LEFT_CORNER, GTK_ALIGN_START,
                    GTK_ALIGN_START, 12, 12);
  add_resize_handle(self, resize_overlay, 5, GDK_WINDOW_EDGE_NORTH_EAST,
                    "ne-resize", GDK_TOP_RIGHT_CORNER, GTK_ALIGN_END,
                    GTK_ALIGN_START, 12, 12);
  add_resize_handle(self, resize_overlay, 6, GDK_WINDOW_EDGE_SOUTH_WEST,
                    "sw-resize", GDK_BOTTOM_LEFT_CORNER, GTK_ALIGN_START,
                    GTK_ALIGN_END, 12, 12);
  add_resize_handle(self, resize_overlay, 7, GDK_WINDOW_EDGE_SOUTH_EAST,
                    "se-resize", GDK_BOTTOM_RIGHT_CORNER, GTK_ALIGN_END,
                    GTK_ALIGN_END, 12, 12);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlMethodCodec) codec =
      FL_METHOD_CODEC(fl_standard_method_codec_new());
  g_clear_object(&self->window_channel);
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.app.vpfl/window", codec);
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call, g_object_ref(self),
      g_object_unref);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  lifecycle_log("app.shutdown.native");

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}

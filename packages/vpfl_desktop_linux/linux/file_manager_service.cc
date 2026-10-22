// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

#include "desktop_services.h"

#include <gio/gio.h>

#include <cstring>

namespace {

struct ShowFolderRequest {
  FlMethodCall* call;
  gchar* uri;
  GCancellable* cancellable;
  guint timeout_id;
  gboolean responded;
};

void respond_show_folder(ShowFolderRequest* request, gboolean opened) {
  if (request->responded) return;
  request->responded = TRUE;
  g_autoptr(FlValue) value = fl_value_new_bool(opened);
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  fl_method_call_respond(request->call, response, nullptr);
}

void finish_show_folder(ShowFolderRequest* request, gboolean opened) {
  if (request->timeout_id != 0) g_source_remove(request->timeout_id);
  respond_show_folder(request, opened);
  g_object_unref(request->cancellable);
  g_object_unref(request->call);
  g_free(request->uri);
  g_free(request);
}

gboolean show_folder_timed_out(gpointer user_data) {
  auto* request = static_cast<ShowFolderRequest*>(user_data);
  request->timeout_id = 0;
  respond_show_folder(request, FALSE);
  g_cancellable_cancel(request->cancellable);
  return G_SOURCE_REMOVE;
}

void show_folders_done(GObject* source, GAsyncResult* result,
                       gpointer user_data) {
  auto* request = static_cast<ShowFolderRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply =
      g_dbus_connection_call_finish(G_DBUS_CONNECTION(source), result, &error);
  finish_show_folder(request, reply != nullptr);
}

void session_bus_ready(GObject* source, GAsyncResult* result,
                       gpointer user_data) {
  auto* request = static_cast<ShowFolderRequest*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) bus = g_bus_get_finish(result, &error);
  if (bus == nullptr) {
    finish_show_folder(request, FALSE);
    return;
  }
  const gchar* uris[] = {request->uri, nullptr};
  const gchar* startup_id = g_getenv("DESKTOP_STARTUP_ID");
  g_dbus_connection_call(
      bus, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
      "org.freedesktop.FileManager1", "ShowFolders",
      g_variant_new("(^ass)", uris, startup_id == nullptr ? "" : startup_id),
      nullptr, G_DBUS_CALL_FLAGS_NONE, 3000, request->cancellable,
      show_folders_done, request);
}

}  // namespace

bool vpfl_handle_file_manager_method(FlMethodCall* call) {
  if (strcmp(fl_method_call_get_name(call), "showFolder") != 0) return false;
  FlValue* args = fl_method_call_get_args(call);
  const gchar* uri = args != nullptr &&
                             fl_value_get_type(args) == FL_VALUE_TYPE_STRING
                         ? fl_value_get_string(args)
                         : nullptr;
  if (uri == nullptr || !g_str_has_prefix(uri, "file://")) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("invalid-arguments",
                                     "Expected a local folder URI.", nullptr));
    fl_method_call_respond(call, response, nullptr);
    return true;
  }
  auto* request = g_new0(ShowFolderRequest, 1);
  request->call = FL_METHOD_CALL(g_object_ref(call));
  request->uri = g_strdup(uri);
  request->cancellable = g_cancellable_new();
  request->timeout_id = g_timeout_add_seconds(4, show_folder_timed_out,
                                              request);
  g_bus_get(G_BUS_TYPE_SESSION, request->cancellable, session_bus_ready,
            request);
  return true;
}

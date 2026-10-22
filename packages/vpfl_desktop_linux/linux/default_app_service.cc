// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

#include "desktop_services.h"

#include <gio/gdesktopappinfo.h>
#include <gio/gio.h>

#include <cstring>

namespace {

FlMethodResponse* error_response(const char* code, const char* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

const gchar* string_argument(FlValue* value) {
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(value)
             : nullptr;
}

FlMethodResponse* success(FlValue* value) {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
}

}  // namespace

FlMethodResponse* vpfl_handle_default_app_method(FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (strcmp(method, "isAvailable") == 0) {
    const gchar* id = string_argument(args);
    if (id == nullptr || *id == '\0') {
      return error_response("invalid-arguments", "Expected a desktop-file ID.");
    }
    g_autoptr(GDesktopAppInfo) app = g_desktop_app_info_new(id);
    g_autoptr(FlValue) value = fl_value_new_bool(app != nullptr);
    return success(value);
  }

  if (strcmp(method, "getDefaultApplication") == 0) {
    const gchar* mime = string_argument(args);
    if (mime == nullptr || *mime == '\0') {
      return error_response("invalid-arguments", "Expected a MIME type.");
    }
    g_autoptr(GAppInfo) app = g_app_info_get_default_for_type(mime, FALSE);
    const gchar* id = app == nullptr ? nullptr : g_app_info_get_id(app);
    g_autoptr(FlValue) value = id == nullptr ? fl_value_new_null()
                                               : fl_value_new_string(id);
    return success(value);
  }

  if (strcmp(method, "setDefaultForMimeTypes") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      return error_response("invalid-arguments", "Expected a desktop ID and MIME list.");
    }
    const gchar* id = string_argument(fl_value_lookup_string(args, "desktopId"));
    FlValue* mime_types = fl_value_lookup_string(args, "mimeTypes");
    if (id == nullptr || *id == '\0' || mime_types == nullptr ||
        fl_value_get_type(mime_types) != FL_VALUE_TYPE_LIST) {
      return error_response("invalid-arguments", "Expected a desktop ID and MIME list.");
    }
    g_autoptr(GDesktopAppInfo) app = g_desktop_app_info_new(id);
    if (app == nullptr) {
      return error_response("desktop-entry-missing", "The desktop entry is not installed.");
    }
    g_autoptr(FlValue) results = fl_value_new_map();
    g_autoptr(FlValue) errors = fl_value_new_map();
    for (size_t i = 0; i < fl_value_get_length(mime_types); ++i) {
      const gchar* mime = string_argument(fl_value_get_list_value(mime_types, i));
      if (mime == nullptr || *mime == '\0') {
        return error_response("invalid-arguments", "MIME list contains an invalid value.");
      }
      g_autoptr(GError) gio_error = nullptr;
      gboolean set = g_app_info_set_as_default_for_type(G_APP_INFO(app), mime,
                                                         &gio_error);
      g_autoptr(GAppInfo) current = g_app_info_get_default_for_type(mime, FALSE);
      const gchar* current_id = current == nullptr ? nullptr : g_app_info_get_id(current);
      gboolean verified = set && g_strcmp0(current_id, id) == 0;
      fl_value_set_string_take(results, mime, fl_value_new_bool(verified));
      if (!verified) {
        const gchar* message = gio_error == nullptr
                                   ? "Desktop did not confirm the requested default."
                                   : gio_error->message;
        fl_value_set_string_take(errors, mime, fl_value_new_string(message));
      }
    }
    g_autoptr(FlValue) response = fl_value_new_map();
    fl_value_set_string_take(response, "results", fl_value_ref(results));
    fl_value_set_string_take(response, "errors", fl_value_ref(errors));
    return success(response);
  }

  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

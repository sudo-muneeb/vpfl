// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

#include "include/vpfl_desktop_linux/vpfl_desktop_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>

#include "desktop_services.h"

struct _VpflDesktopLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(VpflDesktopLinuxPlugin, vpfl_desktop_linux_plugin,
              g_object_get_type())

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  if (vpfl_handle_file_manager_method(call)) return;
  g_autoptr(FlMethodResponse) response = vpfl_handle_default_app_method(call);
  fl_method_call_respond(call, response, nullptr);
}

static void vpfl_desktop_linux_plugin_class_init(
    VpflDesktopLinuxPluginClass* klass) {}

static void vpfl_desktop_linux_plugin_init(VpflDesktopLinuxPlugin* self) {}

void vpfl_desktop_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "vpfl_desktop_linux",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, nullptr,
                                            nullptr);
}

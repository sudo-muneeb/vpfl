// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

#ifndef VPFL_DESKTOP_SERVICES_H_
#define VPFL_DESKTOP_SERVICES_H_

#include <flutter_linux/flutter_linux.h>

// The caller owns the returned response.
FlMethodResponse* vpfl_handle_default_app_method(FlMethodCall* call);

// Returns true if the asynchronous folder request was accepted for handling.
bool vpfl_handle_file_manager_method(FlMethodCall* call);

#endif  // VPFL_DESKTOP_SERVICES_H_

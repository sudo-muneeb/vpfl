cmake_minimum_required(VERSION 3.10)
project(default_manager_linux LANGUAGES CXX)

set(PLUGIN_NAME default_manager_linux_plugin)
add_library(${PLUGIN_NAME} SHARED default_manager_linux_plugin.cc)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO_UNIX REQUIRED IMPORTED_TARGET gio-unix-2.0)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK PkgConfig::GIO_UNIX)

set(default_manager_linux_bundled_libraries "" PARENT_SCOPE)

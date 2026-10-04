#include "my_application.h"

#include <glib.h>

int main(int argc, char** argv) {
  // The window is frameless. Native Wayland ignores that request on KDE and
  // draws a second title bar above VPFL's own controls, so use XWayland
  // whenever it is available.
  if (g_getenv("GDK_BACKEND") == nullptr && g_getenv("DISPLAY") != nullptr) {
    g_setenv("GDK_BACKEND", "x11", TRUE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

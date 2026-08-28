#include "my_application.h"

int main(int argc, char** argv) {
  // GTK cannot enforce keep-above for native Wayland surfaces. When XWayland
  // is available, use the same X11 path as the Electron desktop build so
  // always-on-top remains enforceable.
  if (g_getenv("GDK_BACKEND") == nullptr &&
      g_getenv("WAYLAND_DISPLAY") != nullptr &&
      g_getenv("DISPLAY") != nullptr) {
    g_setenv("GDK_BACKEND", "x11", FALSE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

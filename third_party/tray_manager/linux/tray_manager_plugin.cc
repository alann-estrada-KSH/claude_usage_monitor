#include "include/tray_manager/tray_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#ifdef HAVE_AYATANA
#include <libayatana-appindicator/app-indicator.h>
#else
#include <libappindicator/app-indicator.h>
#endif
#include <algorithm>
#include <cstring>
#include <map>

#define TRAY_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), tray_manager_plugin_get_type(), \
                              TrayManagerPlugin))

TrayManagerPlugin* plugin_instance;

AppIndicator* indicator = nullptr;
GtkWidget* menu = nullptr;

struct _TrayManagerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(TrayManagerPlugin, tray_manager_plugin, g_object_get_type())

// Gets the window being controlled.
GtkWindow* get_window(TrayManagerPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

void _on_activate(GtkMenuItem* item, gpointer user_data) {
  gint id = GPOINTER_TO_INT(user_data);

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "id", fl_value_new_int(id));
  fl_method_channel_invoke_method(plugin_instance->channel,
                                  "onTrayMenuItemClick", result_data, nullptr,
                                  nullptr, nullptr);
}

GtkWidget* _create_menu(FlValue* args) {
  FlValue* items_value = fl_value_lookup_string(args, "items");

  GtkWidget* menu = gtk_menu_new();
  for (gint i = 0; i < fl_value_get_length(items_value); i++) {
    FlValue* item_value = fl_value_get_list_value(items_value, i);
    const int id = fl_value_get_int(fl_value_lookup_string(item_value, "id"));
    const char* type =
        fl_value_get_string(fl_value_lookup_string(item_value, "type"));
    const char* label =
        fl_value_get_string(fl_value_lookup_string(item_value, "label"));
    const bool disabled =
        fl_value_get_bool(fl_value_lookup_string(item_value, "disabled"));

    gint item_id = id;

    if (strcmp(type, "separator") == 0) {
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),
                            gtk_separator_menu_item_new());
    } else {
      GtkWidget* item = gtk_menu_item_new_with_label(label);

      if (disabled) {
        gtk_widget_set_sensitive(item, FALSE);
      }

      if (strcmp(type, "checkbox") == 0) {
        item = gtk_check_menu_item_new_with_label(label);
        const auto checked_value =
            fl_value_lookup_string(item_value, "checked");
        if (checked_value != nullptr) {
          const auto checked = fl_value_get_bool(checked_value);
          gtk_check_menu_item_set_active((GtkCheckMenuItem*)item, checked);
        }
      } else if (strcmp(type, "submenu") == 0) {
        GtkWidget* sub_menu =
            _create_menu(fl_value_lookup_string(item_value, "submenu"));
        gtk_menu_item_set_submenu(GTK_MENU_ITEM(item), sub_menu);
      }

      g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_on_activate),
                       GINT_TO_POINTER(item_id));

      gtk_menu_shell_append(GTK_MENU_SHELL(menu), item);
    }
  }
  return menu;
}

static FlMethodResponse* destroy(TrayManagerPlugin* self, FlValue* args) {
  if (!(!indicator)) {
    app_indicator_set_status(indicator, APP_INDICATOR_STATUS_PASSIVE);
  }
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_icon(TrayManagerPlugin* self, FlValue* args) {
  const char* id = fl_value_get_string(fl_value_lookup_string(args, "id"));
  const char* icon_path =
      fl_value_get_string(fl_value_lookup_string(args, "iconPath"));

  if (!menu)
    menu = gtk_menu_new();

  if (!indicator) {
    indicator = app_indicator_new(id, icon_path,
                                  APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

    app_indicator_set_menu(indicator, GTK_MENU(menu));
    gtk_widget_show_all(menu);
  }

  app_indicator_set_status(indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_icon_full(indicator, icon_path, "");

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* set_title(TrayManagerPlugin* self, FlValue* args) {
  const char* title =
      fl_value_get_string(fl_value_lookup_string(args, "title"));

  app_indicator_set_label(indicator, title, NULL);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// AppIndicator has no real hover-tooltip concept -- the closest equivalent
// is the accessible title used by some shells. Upstream tray_manager never
// implemented this method for Linux at all, so calling setToolTip() (which
// AppTrayController does right after setIcon) threw MissingPluginException
// and aborted init() before setContextMenu() ever ran, leaving the
// indicator's menu permanently empty. Handling it here (even as a no-op)
// is what lets the rest of init() reach setContextMenu().
static FlMethodResponse* set_tool_tip(TrayManagerPlugin* self, FlValue* args) {
  const char* tool_tip =
      fl_value_get_string(fl_value_lookup_string(args, "toolTip"));
  if (indicator) {
    app_indicator_set_title(indicator, tool_tip);
  }
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Updates one non-separator GtkMenuItem's label/sensitivity/click-id in
// place, without touching the widget identity.
static void _update_item_widget(GtkWidget* item, FlValue* item_value) {
  const char* label = fl_value_get_string(fl_value_lookup_string(item_value, "label"));
  const bool disabled = fl_value_get_bool(fl_value_lookup_string(item_value, "disabled"));
  const int id = fl_value_get_int(fl_value_lookup_string(item_value, "id"));

  gtk_menu_item_set_label(GTK_MENU_ITEM(item), label);
  gtk_widget_set_sensitive(item, !disabled);

  g_signal_handlers_disconnect_matched(G_OBJECT(item), G_SIGNAL_MATCH_FUNC, 0, 0,
                                        nullptr, (gpointer)G_CALLBACK(_on_activate),
                                        nullptr);
  g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_on_activate),
                    GINT_TO_POINTER(id));
}

// Rebuilding the whole GtkMenu on every refresh (see set_context_menu)
// replaces every child widget, and libdbusmenu-gtk's exported item ids are
// tied to widget identity -- so a tray host that already has the menu open
// (or just cached its layout) silently loses track of "Show/Hide" the
// instant any menu content changes, e.g. the usage-percent lines ticking
// on a routine refresh. Clicking it after that is a no-op with no visible
// error. When the new item list has the same shape (same count, same
// separator/normal sequence) as what's already on screen, update each
// widget in place instead of replacing it, so ids the host has cached stay
// valid. Only falls back to a full rebuild when the shape actually changed
// (e.g. an account was added/removed).
static bool _try_update_menu_in_place(GtkWidget* existing_menu, FlValue* items_value) {
  if (existing_menu == nullptr)
    return false;

  GList* children = gtk_container_get_children(GTK_CONTAINER(existing_menu));
  const gint new_count = fl_value_get_length(items_value);
  if ((gint)g_list_length(children) != new_count) {
    g_list_free(children);
    return false;
  }

  GList* child_iter = children;
  for (gint i = 0; i < new_count; i++) {
    FlValue* item_value = fl_value_get_list_value(items_value, i);
    const char* type = fl_value_get_string(fl_value_lookup_string(item_value, "type"));
    GtkWidget* child = GTK_WIDGET(child_iter->data);
    const bool child_is_separator = GTK_IS_SEPARATOR_MENU_ITEM(child);
    const bool new_is_separator = strcmp(type, "separator") == 0;

    // Submenu/checkbox items aren't used by this app's tray menu -- keep
    // the in-place fast path scoped to what it's actually verified for
    // (plain labels + separators) and let anything else fall back.
    if (child_is_separator != new_is_separator ||
        (!new_is_separator && strcmp(type, "normal") != 0)) {
      g_list_free(children);
      return false;
    }

    if (!new_is_separator) {
      _update_item_widget(child, item_value);
    }
    child_iter = child_iter->next;
  }
  g_list_free(children);
  return true;
}

static FlMethodResponse* set_context_menu(TrayManagerPlugin* self,
                                          FlValue* args) {
  FlValue* menu_value = fl_value_lookup_string(args, "menu");
  FlValue* items_value = fl_value_lookup_string(menu_value, "items");

  if (!_try_update_menu_in_place(menu, items_value)) {
    // app_indicator_set_menu() takes ownership of the previous menu widget
    // when replacing it -- explicitly destroying the old pointer here too
    // is a use-after-free (GTK already frees it), which is exactly what
    // the original code never did either.
    menu = _create_menu(menu_value);
    app_indicator_set_menu(indicator, GTK_MENU(menu));
  }
  gtk_widget_show_all(menu);

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

// Called when a method call is received from Flutter.
static void tray_manager_plugin_handle_method_call(TrayManagerPlugin* self,
                                                   FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "destroy") == 0) {
    response = destroy(self, args);
  } else if (strcmp(method, "setIcon") == 0) {
    response = set_icon(self, args);
  } else if (strcmp(method, "setTitle") == 0) {
    response = set_title(self, args);
  } else if (strcmp(method, "setToolTip") == 0) {
    response = set_tool_tip(self, args);
  } else if (strcmp(method, "setContextMenu") == 0) {
    response = set_context_menu(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void tray_manager_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(tray_manager_plugin_parent_class)->dispose(object);
}

static void tray_manager_plugin_class_init(TrayManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = tray_manager_plugin_dispose;
}

static void tray_manager_plugin_init(TrayManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(user_data);
  tray_manager_plugin_handle_method_call(plugin, method_call);
}

void tray_manager_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  TrayManagerPlugin* plugin = TRAY_MANAGER_PLUGIN(
      g_object_new(tray_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "tray_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  plugin_instance = plugin;

  g_object_unref(plugin);
}

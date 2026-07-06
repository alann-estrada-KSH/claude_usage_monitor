#include "include/desktop_webview_window/desktop_webview_window_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

#include <cstring>
#include <map>
#include <memory>

#include "message_channel_plugin.h"
#include "webview_window.h"

namespace {

int64_t next_window_id_ = 0;

}

#define WEBVIEW_WINDOW_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), webview_window_plugin_get_type(), \
                              WebviewWindowPlugin))

struct _WebviewWindowPlugin {
  GObject parent_instance;
  FlMethodChannel *method_channel;
  std::map<int64_t, std::unique_ptr<WebviewWindow>> *windows;
};

G_DEFINE_TYPE(WebviewWindowPlugin, webview_window_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void webview_window_plugin_handle_method_call(
    WebviewWindowPlugin *self, FlMethodCall *method_call) {
  const gchar *method = fl_method_call_get_name(method_call);

  if (strcmp(method, "create") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "create args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto width = fl_value_get_int(fl_value_lookup_string(args, "windowWidth"));
    auto height =
        fl_value_get_int(fl_value_lookup_string(args, "windowHeight"));
    auto title = fl_value_get_string(fl_value_lookup_string(args, "title"));
    auto title_bar_height =
        fl_value_get_int(fl_value_lookup_string(args, "titleBarHeight"));
    auto *profile_value = fl_value_lookup_string(args, "profile");
    std::string profile =
        profile_value != nullptr && fl_value_get_type(profile_value) == FL_VALUE_TYPE_STRING
            ? fl_value_get_string(profile_value)
            : "";

    auto window_id = next_window_id_;
    g_object_ref(self);
    auto webview = std::make_unique<WebviewWindow>(
        self->method_channel, window_id,
        [self, window_id]() {
          self->windows->erase(window_id);
          g_object_unref(self);
        },
        title, width, height, title_bar_height, profile);
    self->windows->insert({window_id, std::move(webview)});
    next_window_id_++;
    fl_method_call_respond_success(method_call, fl_value_new_int(window_id),
                                   nullptr);
  } else if (strcmp(method, "launch") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "create args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    auto url = fl_value_get_string(fl_value_lookup_string(args, "url"));

    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }

    self->windows->at(window_id)->Navigate(url);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "addScriptToExecuteOnDocumentCreated") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "args is not map", nullptr,
                                   nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    auto java_script =
        fl_value_get_string(fl_value_lookup_string(args, "javaScript"));

    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->RunJavaScriptWhenContentReady(java_script);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "clearAll") == 0) {
    for (const auto &item : *self->windows) {
      item.second->Close();
    }
    // If application didn't create a webview, but we called
    // webkit_website_data_manager_clear, there will be a segment fault. To
    // avoid crash, we create a fake webview first and then clear all data.
    auto *web_view = webkit_web_view_new();
    auto *context = webkit_web_view_get_context(WEBKIT_WEB_VIEW(web_view));
    auto *website_data_manager =
        webkit_web_context_get_website_data_manager(context);
    webkit_website_data_manager_clear(website_data_manager,
                                      WEBKIT_WEBSITE_DATA_ALL, 0, nullptr,
                                      nullptr, nullptr);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "setApplicationNameForUserAgent") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(
          method_call, "0", "setApplicationNameForUserAgent args is not map",
          nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    auto application_name =
        fl_value_get_string(fl_value_lookup_string(args, "applicationName"));

    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->SetApplicationNameForUserAgent(
        application_name);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "back") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "back args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->GoBack();
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "forward") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "forward args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->GoForward();
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "reload") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "reload args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->Reload();
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "stop") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "stop args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->StopLoading();
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "getAllCookies") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(
          method_call, "0", "getAllCookies args is not map", nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }

    FlValue *data = nullptr;

    data = self->windows->at(window_id)->GetAllCookies();

    if (data == nullptr) {
      fl_method_call_respond_error(method_call, "0", "get all cookies failed",
                                   nullptr, nullptr);
      return;
    }


    fl_method_call_respond_success(method_call, data, nullptr);
    fl_value_unref(data);
  } else if (strcmp(method, "close") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "close args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    self->windows->at(window_id)->Close();
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "setWebviewWindowVisibility") == 0) {
    // Upstream never implemented this on Linux at all (Windows/macOS only),
    // so every call threw MissingPluginException regardless of timing.
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0",
                                   "setWebviewWindowVisibility args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    auto *visible_value = fl_value_lookup_string(args, "visible");
    bool visible = visible_value != nullptr &&
                   fl_value_get_type(visible_value) == FL_VALUE_TYPE_BOOL &&
                   fl_value_get_bool(visible_value);
    self->windows->at(window_id)->SetVisibility(visible);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "evaluateJavaScript") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0",
                                   "evaluateJavaScript args is not map",
                                   nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0",
                                   "can not found webview for viewId", nullptr,
                                   nullptr);
      return;
    }
    auto *js =
        fl_value_get_string(fl_value_lookup_string(args, "javaScriptString"));
    self->windows->at(window_id)->EvaluateJavaScript(js, method_call);
  } else if (strcmp(method, "registerJavaScriptInterface") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "args is not map", nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    const gchar *channel_name = fl_value_get_string(fl_value_lookup_string(args, "name"));

    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0", "cannot find webview for viewId",
                                   nullptr, nullptr);
      return;
    }
    self->windows->at(window_id)->RegisterJavaScriptChannel(channel_name);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "unregisterJavaScriptInterface") == 0) {
    auto *args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      fl_method_call_respond_error(method_call, "0", "args is not map", nullptr, nullptr);
      return;
    }
    auto window_id = fl_value_get_int(fl_value_lookup_string(args, "viewId"));
    const gchar *channel_name = fl_value_get_string(fl_value_lookup_string(args, "name"));

    if (!self->windows->count(window_id)) {
      fl_method_call_respond_error(method_call, "0", "cannot find webview for viewId",
                                   nullptr, nullptr);
      return;
    }
    self->windows->at(window_id)->UnregisterJavaScriptChannel(channel_name);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void webview_window_plugin_dispose(GObject *object) {
  delete WEBVIEW_WINDOW_PLUGIN(object)->windows;
  g_object_unref(WEBVIEW_WINDOW_PLUGIN(object)->method_channel);
  G_OBJECT_CLASS(webview_window_plugin_parent_class)->dispose(object);
}

static void webview_window_plugin_class_init(WebviewWindowPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = webview_window_plugin_dispose;
}

static void webview_window_plugin_init(WebviewWindowPlugin *self) {
  self->windows = new std::map<int64_t, std::unique_ptr<WebviewWindow>>();

  // WebKitGTK's default WebKitWebContext keeps cookies in memory only
  // unless a persistent backing store is set explicitly -- every view in
  // this process shares that context (webkit_web_view_new() with no
  // explicit context always uses webkit_web_context_get_default()), so a
  // claude.ai login done in one WebviewWindow (e.g. the visible login
  // flow) is visible to another (e.g. the headless background scraper)
  // *as long as the app process stays alive*. The moment the process
  // restarts, that in-memory cookie jar is gone and every account looks
  // logged out again -- which is exactly what was happening here. Point
  // the cookie manager at a real SQLite file under the app's own data
  // directory so login survives app restarts.
  auto *context = webkit_web_context_get_default();
  auto *cookie_manager = webkit_web_context_get_cookie_manager(context);
  g_autofree char *cookie_dir =
      g_build_filename(g_get_user_data_dir(), "claude_usage_monitor", nullptr);
  g_mkdir_with_parents(cookie_dir, 0700);
  g_autofree char *cookie_path =
      g_build_filename(cookie_dir, "cookies.sqlite", nullptr);
  webkit_cookie_manager_set_persistent_storage(
      cookie_manager, cookie_path, WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data) {
  WebviewWindowPlugin *plugin = WEBVIEW_WINDOW_PLUGIN(user_data);
  webview_window_plugin_handle_method_call(plugin, method_call);
}

void desktop_webview_window_plugin_register_with_registrar(
    FlPluginRegistrar *registrar) {
  client_message_channel_plugin_register_with_registrar(registrar);

  WebviewWindowPlugin *plugin = WEBVIEW_WINDOW_PLUGIN(
      g_object_new(webview_window_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "webview_window", FL_METHOD_CODEC(codec));
  g_object_ref(channel);
  plugin->method_channel = channel;
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}

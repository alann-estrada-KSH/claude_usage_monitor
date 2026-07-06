//
// Created by boyan on 10/21/21.
//

#include "webview_window.h"
#include <utility>
#include "message_channel_plugin.h"
#include <map>
#include <unordered_map>
#include <string>

#if WEBKIT_MAJOR_VERSION < 2 || \
    (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
#define WEBKIT_OLD_USED
#endif

void get_cookies_callback(WebKitCookieManager *manager, GAsyncResult *res,
                          gpointer user_data) {
  CookieData *data = (CookieData *)user_data;
  GError *error = NULL;

  GList *cookies =
      webkit_cookie_manager_get_cookies_finish(manager, res, &error);
  if (error != NULL) {
    g_print("Error getting cookies: %s\n", error->message);
    g_error_free(error);
    data->cookies = NULL;
  } else {
    data->cookies = cookies;
  }

  g_main_loop_quit(data->loop);
}

GList *get_cookies_sync(WebKitWebView *web_view) {
  WebKitCookieManager *cookie_manager;
  GMainLoop *loop;
  CookieData data = {0};

  cookie_manager = webkit_web_context_get_cookie_manager(
      webkit_web_view_get_context(web_view));
  loop = g_main_loop_new(NULL, FALSE);
  data.loop = loop;

  const gchar *uri = webkit_web_view_get_uri(web_view);

  // Start the asynchronous operation
  webkit_cookie_manager_get_cookies(cookie_manager, uri, NULL,
                                    (GAsyncReadyCallback)get_cookies_callback,
                                    &data);

  // Run the main loop until the callback is called
  g_main_loop_run(loop);

  g_main_loop_unref(loop);

  return data.cookies;
}

namespace {

// One WebKitWebContext per profile, reused across windows for the same
// profile and cached for the lifetime of the process (contexts are cheap to
// keep around, expensive-ish to recreate, and must stay alive as long as
// any webview using them exists). Empty profile ("") means "use the
// process-wide default context" -- the original, pre-multi-account
// behavior, still relied on for the login window's own use of
// getAllCookies() before any profile concept existed elsewhere.
std::map<std::string, WebKitWebContext *> *g_profile_contexts = nullptr;

WebKitWebContext *GetOrCreateContext(const std::string &profile) {
  if (profile.empty()) {
    return webkit_web_context_get_default();
  }
  if (g_profile_contexts == nullptr) {
    g_profile_contexts = new std::map<std::string, WebKitWebContext *>();
  }
  auto it = g_profile_contexts->find(profile);
  if (it != g_profile_contexts->end()) {
    return it->second;
  }

  g_autofree gchar *profile_dir = g_build_filename(
      g_get_user_data_dir(), "claude_usage_monitor", "profiles", profile.c_str(), nullptr);
  g_autofree gchar *cache_dir = g_build_filename(profile_dir, "cache", nullptr);
  g_mkdir_with_parents(profile_dir, 0700);
  g_mkdir_with_parents(cache_dir, 0700);

  WebKitWebsiteDataManager *data_manager = webkit_website_data_manager_new(
      "base-data-directory", profile_dir, "base-cache-directory", cache_dir, nullptr);
  WebKitWebContext *context = webkit_web_context_new_with_website_data_manager(data_manager);
  g_object_unref(data_manager);

  // Same reasoning as the default context's setup in
  // desktop_webview_window_plugin.cc's plugin_init: cookies are in-memory
  // only until a persistent backing store is set explicitly.
  g_autofree gchar *cookie_path = g_build_filename(profile_dir, "cookies.sqlite", nullptr);
  webkit_cookie_manager_set_persistent_storage(
      webkit_web_context_get_cookie_manager(context), cookie_path,
      WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);

  (*g_profile_contexts)[profile] = context;
  return context;
}

gboolean on_load_failed_with_tls_errors(WebKitWebView *web_view,
                                        char *failing_uri,
                                        GTlsCertificate *certificate,
                                        GTlsCertificateFlags errors,
                                        gpointer user_data) {
  auto *webview = static_cast<WebviewWindow *>(user_data);
  g_critical("on_load_failed_with_tls_errors: %s %p error= %d", failing_uri,
             webview, errors);
  // TODO allow certificate for some certificate ?
  // maybe we can use the pem from
  // https://source.chromium.org/chromium/chromium/src/+/master:net/data/ssl/ev_roots/
  //  webkit_web_context_allow_tls_certificate_for_host(webkit_web_view_get_context(web_view),
  //  certificate, uri->host); webkit_web_view_load_uri(web_view, failing_uri);
  return false;
}

GtkWidget *on_create(WebKitWebView *web_view,
                     WebKitNavigationAction *navigation_action,
                     gpointer user_data) {
  // Returning the same, already-realized `web_view` here (the original
  // upstream behavior) tells WebKit "here is a brand new view", but it's
  // actually the existing one -- WebKit then tries to populate a fresh
  // WindowFeatures for it and crashes with
  // `optional<WindowFeatures>::operator*(): Assertion '_M_is_engaged()' failed`
  // the moment any popup (Google's OAuth "Sign in with Google", any
  // target="_blank" link, or window.open()) is triggered.
  //
  // An earlier fix here returned nullptr and just navigated the *existing*
  // view to the popup's target URL instead of opening a real popup. That
  // avoided the crash but broke Google's OAuth handshake: Google's
  // redirect-back step relies on window.opener/postMessage between the
  // popup and the page that opened it, and collapsing both into one view
  // destroys the opener the instant the popup navigates -- login would get
  // stuck showing Google's page with nothing left to signal completion
  // back to Anthropic.
  //
  // The actual fix: create a genuinely new, *related* WebKitWebView (this
  // is what "create" is documented for). webkit_web_view_new_with_related_view
  // shares the opener's WebKitWebContext (so cookies/session carry over)
  // and preserves window.opener, in its own small GTK window -- mirrors the
  // pattern from WebKitGTK's own reference browser.
  auto *popup_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(popup_window), 500, 700);
  gtk_window_set_position(GTK_WINDOW(popup_window), GTK_WIN_POS_CENTER);

  auto *popup_view = webkit_web_view_new_with_related_view(web_view);
  gtk_container_add(GTK_CONTAINER(popup_window), GTK_WIDGET(popup_view));

  // WebKit fires "ready-to-show" once the popup's WindowFeatures (size,
  // toolbar, etc.) are settled -- the documented point at which to actually
  // display it, rather than showing immediately in on_create.
  g_signal_connect(popup_view, "ready-to-show",
                   G_CALLBACK(+[](WebKitWebView *, gpointer data) {
                     gtk_widget_show_all(GTK_WIDGET(data));
                   }),
                   popup_window);

  // Fired when the page calls JS window.close() (Google's flow does this
  // once the OAuth handshake with the opener completes).
  g_signal_connect(popup_view, "close",
                   G_CALLBACK(+[](WebKitWebView *, gpointer data) {
                     gtk_widget_destroy(GTK_WIDGET(data));
                   }),
                   popup_window);

  return GTK_WIDGET(popup_view);
}

void on_load_changed(WebKitWebView *web_view, WebKitLoadEvent load_event,
                     gpointer user_data) {
  auto *window = static_cast<WebviewWindow *>(user_data);
  window->OnLoadChanged(load_event);
}

gboolean decide_policy_cb(WebKitWebView *web_view,
                          WebKitPolicyDecision *decision,
                          WebKitPolicyDecisionType type, gpointer user_data) {
  auto *window = static_cast<WebviewWindow *>(user_data);
  return window->DecidePolicy(decision, type);
}

}  // namespace

WebviewWindow::WebviewWindow(FlMethodChannel *method_channel, int64_t window_id,
                             std::function<void()> on_close_callback,
                             const std::string &title, int width, int height,
                             int title_bar_height, const std::string &profile)
    : method_channel_(method_channel),
      window_id_(window_id),
      on_close_callback_(std::move(on_close_callback)),
      default_user_agent_() {
  g_object_ref(method_channel_);

  window_ = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  g_signal_connect(G_OBJECT(window_), "destroy",
                   G_CALLBACK(+[](GtkWidget *, gpointer arg) {
                     auto *window = static_cast<WebviewWindow *>(arg);
                     // `on_close_callback_` erases this WebviewWindow from
                     // its owning `std::map<int64_t, unique_ptr<...>>`,
                     // freeing `window` (`this`) synchronously. The
                     // upstream code called it *before* reading
                     // `window->window_id_`/`window->method_channel_`
                     // below, which is a use-after-free -- the exact crash
                     // this app hit on every webview close (login window
                     // "Done", and our own headless background-scraper
                     // windows). Capture what we need from `window` first,
                     // notify Dart, and only then run the callback that
                     // destroys the object.
                     auto *method_channel = window->method_channel_;
                     auto window_id = window->window_id_;
                     auto on_close_callback = window->on_close_callback_;

                     auto *args = fl_value_new_map();
                     fl_value_set(args, fl_value_new_string("id"),
                                  fl_value_new_int(window_id));
                     fl_method_channel_invoke_method(
                         FL_METHOD_CHANNEL(method_channel),
                         "onWindowClose", args, nullptr, nullptr, nullptr);

                     if (on_close_callback) {
                       on_close_callback();
                     }
                   }),
                   this);
  gtk_window_set_title(GTK_WINDOW(window_), title.c_str());
  gtk_window_set_default_size(GTK_WINDOW(window_), width, height);

  // title_bar_height <= 0 is our existing signal for "this is a background
  // fetch window, not a login window a human is meant to see" (see
  // DesktopUsageFetcher). This used to also need to stay mapped (never
  // gtk_widget_hide()'d) because JS execution/rendering throttles for
  // unmapped WebKitGTK windows, and the old approach needed JS to actually
  // hydrate the page. That's no longer true: this window now only needs
  // its cookies, not to render or run JS, so it can just stay properly
  // hidden -- see the skipped gtk_widget_show_all() below.
  if (title_bar_height <= 0) {
    gtk_window_set_decorated(GTK_WINDOW(window_), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(window_), TRUE);
    gtk_window_set_skip_pager_hint(GTK_WINDOW(window_), TRUE);
    gtk_window_set_type_hint(GTK_WINDOW(window_), GDK_WINDOW_TYPE_HINT_UTILITY);
  } else {
    gtk_window_set_position(GTK_WINDOW(window_), GTK_WIN_POS_CENTER);
  }

  box_ = GTK_BOX(gtk_box_new(GTK_ORIENTATION_VERTICAL, 0));
  gtk_container_add(GTK_CONTAINER(window_), GTK_WIDGET(box_));

  // Upstream created a *second*, secondary Flutter engine/view here
  // (fl_view_new) purely to render a small back/forward/reload/close title
  // bar using Flutter widgets (see lib/src/title_bar.dart). We don't need
  // that chrome for a login/scrape webview, and tearing down that secondary
  // view on window close crashes inside libflutter_linux_gtk.so itself
  // (FlutterEngineRemoveView on the wrong/implicit view -- an engine bug in
  // Flutter 3.44.4's Linux multi-view embedder, not something patchable
  // from this project since the engine ships as a precompiled binary).
  // Skipping the secondary view entirely sidesteps that crash altogether.
  //
  // That leaves closing the window up to the window manager's own title bar
  // decoration, which isn't guaranteed visible/reachable in every WM
  // configuration. Add a plain native GTK close button instead -- no
  // Flutter engine involved, so it can't hit the bug above.
  if (title_bar_height > 0) {
    auto *close_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    auto *close_button = gtk_button_new_with_label("\xC3\x97");  // "×"
    gtk_widget_set_tooltip_text(close_button, "Close");
    gtk_box_pack_end(GTK_BOX(close_bar), close_button, FALSE, FALSE, 4);
    gtk_widget_set_size_request(close_bar, -1, title_bar_height);
    g_signal_connect_swapped(close_button, "clicked",
                             G_CALLBACK(gtk_window_close), window_);
    gtk_box_pack_start(box_, close_bar, FALSE, FALSE, 0);
  }

  // initial web_view -- a non-empty profile gets its own WebKitWebContext
  // (own cookie jar/storage directory) instead of the process-wide default,
  // so different accounts stop overwriting each other's session cookies.
  webview_ = webkit_web_view_new_with_context(GetOrCreateContext(profile));
  g_signal_connect(G_OBJECT(webview_), "load-failed-with-tls-errors",
                   G_CALLBACK(on_load_failed_with_tls_errors), this);
  g_signal_connect(G_OBJECT(webview_), "create", G_CALLBACK(on_create), this);
  g_signal_connect(G_OBJECT(webview_), "load-changed",
                   G_CALLBACK(on_load_changed), this);
  g_signal_connect(G_OBJECT(webview_), "decide-policy",
                   G_CALLBACK(decide_policy_cb), this);

  auto settings = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(webview_));
  webkit_settings_set_javascript_can_open_windows_automatically(settings, true);
  // Tried spoofing a mainstream Chrome UA here to work around a suspected
  // claude.ai browser check -- made things strictly worse: Cloudflare's bot
  // check cross-references the UA against the actual JS engine, and a
  // Chrome UA on a real WebKitGTK engine is itself a mismatch signal. That
  // escalated to a visible, never-resolving "Performing security
  // verification" interstitial on login that did not happen before. Reverted
  // to WebKitGTK's genuine stock UA.
  default_user_agent_ = webkit_settings_get_user_agent(settings);
  gtk_box_pack_end(box_, webview_, true, true, 0);

  gtk_widget_show_all(GTK_WIDGET(window_));
  gtk_widget_grab_focus(GTK_WIDGET(webview_));

  // Immediately hide again for headless windows, still within this same
  // call (before control returns to the GTK main loop, so nothing ever
  // actually gets mapped to the X server/compositor -- no visible flash).
  // Still calling show_all first, rather than never showing at all, keeps
  // the widget realized/allocated, which navigation may depend on; hiding
  // synchronously like this is the standard GTK way to realize a widget
  // without it ever appearing on screen.
  if (title_bar_height <= 0) {
    gtk_widget_hide(GTK_WIDGET(window_));
  }

  // The delete-event-handler-disconnect workaround that used to live here
  // was only needed because of the secondary FlView (see above) installing
  // its own delete-event handler on this toplevel; with no FlView, there's
  // nothing to disconnect.
}

WebviewWindow::~WebviewWindow() {
  if (webview_ != nullptr) {
    WebKitUserContentManager *manager = webkit_web_view_get_user_content_manager(WEBKIT_WEB_VIEW(webview_));
    for (auto &entry : js_channel_handler_ids_) {
      g_signal_handler_disconnect(manager, entry.second);
    }
    js_channel_handler_ids_.clear();
  }
  g_object_unref(method_channel_);
  printf("~WebviewWindow\n");
}

void WebviewWindow::Navigate(const char *url) {
  webkit_web_view_load_uri(WEBKIT_WEB_VIEW(webview_), url);
}

void WebviewWindow::RunJavaScriptWhenContentReady(const char *java_script) {
  auto *manager =
      webkit_web_view_get_user_content_manager(WEBKIT_WEB_VIEW(webview_));
  webkit_user_content_manager_add_script(
      manager,
      webkit_user_script_new(java_script, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                             WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,
                             nullptr, nullptr));
}

void WebviewWindow::SetApplicationNameForUserAgent(
    const std::string &app_name) {
  auto *setting = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(webview_));
  webkit_settings_set_user_agent(setting,
                                 (default_user_agent_ + app_name).c_str());
}

void WebviewWindow::Close() { gtk_window_close(GTK_WINDOW(window_)); }

void WebviewWindow::SetVisibility(bool visible) {
  if (visible) {
    gtk_widget_show(GTK_WIDGET(window_));
  } else {
    gtk_widget_hide(GTK_WIDGET(window_));
  }
}

void WebviewWindow::OnLoadChanged(WebKitLoadEvent load_event) {
  // notify history changed event.
  {
    auto can_go_back = webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(webview_));
    auto can_go_forward =
        webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(webview_));
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("id"), fl_value_new_int(window_id_));
    fl_value_set(args, fl_value_new_string("canGoBack"),
                 fl_value_new_bool(can_go_back));
    fl_value_set(args, fl_value_new_string("canGoForward"),
                 fl_value_new_bool(can_go_forward));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel_),
                                    "onHistoryChanged", args, nullptr, nullptr,
                                    nullptr);
  }

  // notify load start/finished event.
  switch (load_event) {
    case WEBKIT_LOAD_STARTED: {
      auto *args = fl_value_new_map();
      fl_value_set(args, fl_value_new_string("id"),
                   fl_value_new_int(window_id_));
      fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel_),
                                      "onNavigationStarted", args, nullptr,
                                      nullptr, nullptr);
      break;
    }
    case WEBKIT_LOAD_FINISHED: {
      auto *args = fl_value_new_map();
      fl_value_set(args, fl_value_new_string("id"),
                   fl_value_new_int(window_id_));
      fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel_),
                                      "onNavigationCompleted", args, nullptr,
                                      nullptr, nullptr);
      break;
    }
    default:
      break;
  }
}

void WebviewWindow::GoForward() {
  webkit_web_view_go_forward(WEBKIT_WEB_VIEW(webview_));
}

void WebviewWindow::GoBack() {
  webkit_web_view_go_back(WEBKIT_WEB_VIEW(webview_));
}

void WebviewWindow::Reload() {
  webkit_web_view_reload(WEBKIT_WEB_VIEW(webview_));
}

void WebviewWindow::StopLoading() {
  webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(webview_));
}

FlValue *WebviewWindow::GetAllCookies() {
  GList *cookies = get_cookies_sync(WEBKIT_WEB_VIEW(webview_));

  g_autoptr(FlValue) fl_cookie_list = fl_value_new_list();

  FlValue* cookie_list = fl_value_ref(fl_cookie_list);

  for (GList *l = cookies; l; l = l->next) {
    SoupCookie *cookie = (SoupCookie *)l->data;
    g_autoptr(FlValue) cookie_map = fl_value_new_map();

    fl_value_set_string_take(cookie_map, "name",
                             fl_value_new_string(soup_cookie_get_name(cookie)));
    fl_value_set_string_take(
        cookie_map, "value",
        fl_value_new_string(soup_cookie_get_value(cookie)));
    fl_value_set_string_take(
        cookie_map, "domain",
        fl_value_new_string(soup_cookie_get_domain(cookie)));
    fl_value_set_string_take(cookie_map, "path",
                             fl_value_new_string(soup_cookie_get_path(cookie)));

    // soup_cookie_get_expires() returns NULL for session-only cookies (no
    // explicit expiry) -- calling g_date_time_get_seconds() on that NULL
    // is what raised the "assertion 'datetime != NULL' failed" GLib-CRITICAL
    // on every cookie fetch. Also: g_date_time_get_seconds() returns the
    // seconds-*of-the-minute* component (0-59), not a timestamp -- the
    // upstream code here almost certainly meant g_date_time_to_unix(), an
    // actual epoch value, which is what the Dart side expects to multiply
    // by 1000 into milliseconds.
    GDateTime *expires_dt = soup_cookie_get_expires(cookie);
    if (expires_dt != nullptr) {
      fl_value_set_string_take(
          cookie_map, "expires",
          fl_value_new_float((gdouble)g_date_time_to_unix(expires_dt)));
    } else {
      fl_value_set_string_take(cookie_map, "expires", fl_value_new_null());
    }

    fl_value_set_string_take(
        cookie_map, "httpOnly",
        fl_value_new_bool(soup_cookie_get_http_only(cookie)));
    fl_value_set_string_take(cookie_map, "secure",
                             fl_value_new_bool(soup_cookie_get_secure(cookie)));
    fl_value_set_string_take(cookie_map, "sessionOnly",
                             fl_value_new_bool(false));

    fl_value_append(cookie_list, cookie_map);
    soup_cookie_free(cookie);
  }

  g_free(cookies);

  return cookie_list;
}

gboolean WebviewWindow::DecidePolicy(WebKitPolicyDecision *decision,
                                     WebKitPolicyDecisionType type) {
  if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) {
    auto *navigation_decision = WEBKIT_NAVIGATION_POLICY_DECISION(decision);
    auto *navigation_action =
        webkit_navigation_policy_decision_get_navigation_action(
            navigation_decision);
    auto *request = webkit_navigation_action_get_request(navigation_action);
    auto *uri = webkit_uri_request_get_uri(request);
    auto *args = fl_value_new_map();
    fl_value_set(args, fl_value_new_string("id"), fl_value_new_int(window_id_));
    fl_value_set(args, fl_value_new_string("url"), fl_value_new_string(uri));
    fl_method_channel_invoke_method(FL_METHOD_CHANNEL(method_channel_),
                                    "onUrlRequested", args, nullptr, nullptr,
                                    nullptr);
  }
  return false;
}

void WebviewWindow::EvaluateJavaScript(const char *java_script,
                                       FlMethodCall *call) {
#ifdef WEBKIT_OLD_USED
  webkit_web_view_run_javascript(
#else
  webkit_web_view_evaluate_javascript(
#endif
      WEBKIT_WEB_VIEW(webview_), java_script,
#ifndef WEBKIT_OLD_USED
      -1, nullptr, nullptr,
#endif
      nullptr,
      [](GObject *object, GAsyncResult *result, gpointer user_data) {
        auto *call = static_cast<FlMethodCall *>(user_data);
        GError *error = nullptr;
        auto *js_result =
#ifdef WEBKIT_OLD_USED
            webkit_web_view_run_javascript_finish(
#else
            webkit_web_view_evaluate_javascript_finish(
#endif
                WEBKIT_WEB_VIEW(object), result, &error);
        if (!js_result) {
          fl_method_call_respond_error(call, "failed to evaluate javascript.",
                                       error->message, nullptr, nullptr);
          g_error_free(error);
        } else {
          auto *js_value = jsc_value_to_json(
#ifdef WEBKIT_OLD_USED
              webkit_javascript_result_get_js_value
#endif
              (js_result),
              0);
          fl_method_call_respond_success(
              call, js_value ? fl_value_new_string(js_value) : nullptr,
              nullptr);
        }
        g_object_unref(call);
      },
      g_object_ref(call));
}

void WebviewWindow::RegisterJavaScriptChannel(const std::string &name) {
    WebKitUserContentManager *manager =
            webkit_web_view_get_user_content_manager(WEBKIT_WEB_VIEW(webview_));

    webkit_user_content_manager_register_script_message_handler(
            manager, name.c_str());

    struct HandlerData {
        WebviewWindow *self;
        std::string name;
    };

    HandlerData *data = new HandlerData{this, name};
    auto it = js_channel_handler_ids_.find(name);
    if (it != js_channel_handler_ids_.end()) {
        g_signal_handler_disconnect(manager, it->second);
        js_channel_handler_ids_.erase(it);
    }

    gulong handler_id = g_signal_connect_data(
            manager,
            ("script-message-received::" + name).c_str(),
            G_CALLBACK(+[](WebKitUserContentManager *manager,
                           WebKitJavascriptResult *result,
                           gpointer user_data) {
                HandlerData *data = static_cast<HandlerData *>(user_data);
                WebviewWindow *self = data->self;
                const std::string &handler_name = data->name;

                JSCValue *value = webkit_javascript_result_get_js_value(result);

                if (jsc_value_is_string(value)) {
                    gchar *str_value = jsc_value_to_string(value);
                    if (str_value != nullptr) {
                        FlValue *args = fl_value_new_map();
                        fl_value_set_string(args, "name",
                                            fl_value_new_string(handler_name.c_str()));
                        fl_value_set_string(args, "body",
                                            fl_value_new_string(str_value));
                        fl_value_set_string(args, "id",
                                            fl_value_new_int(self->window_id_));

                        fl_method_channel_invoke_method(
                                self->method_channel_,
                                "onJavaScriptMessage",
                                args,
                                nullptr,
                                nullptr,
                                nullptr);

                        g_free(str_value);
                    }
                }
            }),
            data,
            +[](gpointer user_data, GClosure *) {
                delete static_cast<HandlerData *>(user_data);
            },
            static_cast<GConnectFlags>(0));

    js_channel_handler_ids_[name] = handler_id;
}


void WebviewWindow::UnregisterJavaScriptChannel(const std::string &name) {
    WebKitUserContentManager *manager =
            webkit_web_view_get_user_content_manager(WEBKIT_WEB_VIEW(webview_));

    auto it = js_channel_handler_ids_.find(name);
    if (it != js_channel_handler_ids_.end()) {
        g_signal_handler_disconnect(manager, it->second);
        js_channel_handler_ids_.erase(it);
    }

    webkit_user_content_manager_unregister_script_message_handler(
            manager, name.c_str());
}


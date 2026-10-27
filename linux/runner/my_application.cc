#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gint xerno_map_int(FlValue* args, const gchar* key, gint fallback) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return fallback;
  }
  return fl_value_get_int(value);
}

static void xerno_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* name = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  g_autoptr(GError) error = nullptr;
  (void)channel;

  if (g_strcmp0(name, "setAlwaysOnTop") == 0) {
    gboolean on = FALSE;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_BOOL) {
      on = fl_value_get_bool(args);
    }
    if (self->window != nullptr) {
      gtk_window_set_keep_above(self->window, on);
    }
    if (!fl_method_call_respond_success(method_call, nullptr, &error)) {
      g_warning("Failed to respond: %s", error->message);
    }
    return;
  }

  if (g_strcmp0(name, "resize") == 0) {
    const gint width = xerno_map_int(args, "width", 1280);
    const gint height = xerno_map_int(args, "height", 840);
    if (self->window != nullptr) {
      gtk_window_resize(self->window, width, height);
    }
    if (!fl_method_call_respond_success(method_call, nullptr, &error)) {
      g_warning("Failed to respond: %s", error->message);
    }
    return;
  }

  if (g_strcmp0(name, "present") == 0) {
    if (self->window != nullptr) {
      gtk_window_present(self->window);
    }
    if (!fl_method_call_respond_success(method_call, nullptr, &error)) {
      g_warning("Failed to respond: %s", error->message);
    }
    return;
  }

  if (!fl_method_call_respond_not_implemented(method_call, &error)) {
    g_warning("Failed to respond: %s", error->message);
  }
}

static void xerno_apply_icon(GtkWindow* window) {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) {
    return;
  }
  g_autofree gchar* dir = g_path_get_dirname(exe);
  g_autofree gchar* icon_path = g_build_filename(
      dir, "data", "flutter_assets", "assets", "icons", "xerno.png", nullptr);
  g_autoptr(GError) error = nullptr;
  if (!gtk_window_set_icon_from_file(GTK_WINDOW(window), icon_path, &error)) {
    g_debug("Window icon was not applied: %s",
            error != nullptr ? error->message : "unknown");
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Xerno Music");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Xerno Music");
  }
  gtk_window_set_title(window, "Xerno Music");
  gtk_window_set_default_size(window, 1280, 840);
  gtk_widget_set_size_request(GTK_WIDGET(window), 360, 148);
  self->window = window;

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // Linux defaults Impeller on in the embedder, and its OpenGL ES backend can
  // fail to present a frame on Wayland (Hyprland, KWin, Sway) until the
  // toplevel is already mapped. Skia is the engine default on Linux.
  // FLUTTER_ENGINE_SWITCHES is stripped from release builds, so this flag is
  // the switch that actually applies. XERNO_ENABLE_IMPELLER=1 turns Impeller
  // back on.
  const gchar* impeller = g_getenv("XERNO_ENABLE_IMPELLER");
  const gboolean use_impeller =
      impeller != nullptr &&
      (g_strcmp0(impeller, "1") == 0 || g_strcmp0(impeller, "true") == 0);
  fl_dart_project_set_enable_impeller(project, use_impeller);
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#0A0D0B");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Map immediately. On Wayland, waiting for first-frame leaves the toplevel
  // unmapped, and a compositor will not deliver that frame until it is mapped.
  // If Dart dies before runApp (for example while loading libmpv), the process
  // would otherwise sit with no window. first_frame_cb shows it again.
  gtk_widget_show(GTK_WIDGET(window));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "online.mucsarocsoge.xerno/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, xerno_method_call_cb,
                                            self, nullptr);
  xerno_apply_icon(window);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, nullptr);
  }
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->channel);
  self->window = nullptr;
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}

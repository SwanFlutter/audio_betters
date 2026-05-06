#include "include/audio_betters/audio_betters_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <gst/gst.h>

#include <cstring>

#include "audio_betters_plugin_private.h"

#define AUDIO_BETTERS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), audio_betters_plugin_get_type(), \
                              AudioBettersPlugin))

struct _AudioBettersPlugin {
  GObject parent_instance;
  GstElement* playbin;
};

G_DEFINE_TYPE(AudioBettersPlugin, audio_betters_plugin, g_object_get_type())

static void audio_betters_plugin_handle_method_call(
    AudioBettersPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    struct utsname uname_data = {};
    uname(&uname_data);
    g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
    g_autoptr(FlValue) result = fl_value_new_string(version);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "play") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* url = fl_value_get_string(fl_value_lookup_string(args, "url"));

    gst_element_set_state(self->playbin, GST_STATE_READY);
    g_object_set(self->playbin, "uri", url, NULL);
    gst_element_set_state(self->playbin, GST_STATE_PLAYING);

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "pause") == 0) {
    gst_element_set_state(self->playbin, GST_STATE_PAUSED);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "resume") == 0) {
    gst_element_set_state(self->playbin, GST_STATE_PLAYING);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "stop") == 0) {
    gst_element_set_state(self->playbin, GST_STATE_READY);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "setVolume") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    double volume = fl_value_get_float(fl_value_lookup_string(args, "volume"));
    g_object_set(self->playbin, "volume", volume, NULL);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void audio_betters_plugin_dispose(GObject* object) {
  AudioBettersPlugin* self = AUDIO_BETTERS_PLUGIN(object);
  if (self->playbin) {
    gst_element_set_state(self->playbin, GST_STATE_NULL);
    gst_object_unref(self->playbin);
    self->playbin = nullptr;
  }
  G_OBJECT_CLASS(audio_betters_plugin_parent_class)->dispose(object);
}

static void audio_betters_plugin_class_init(AudioBettersPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = audio_betters_plugin_dispose;
}

static void audio_betters_plugin_init(AudioBettersPlugin* self) {
  gst_init(NULL, NULL);
  self->playbin = gst_element_factory_make("playbin", "playbin");
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  AudioBettersPlugin* plugin = AUDIO_BETTERS_PLUGIN(user_data);
  audio_betters_plugin_handle_method_call(plugin, method_call);
}

void audio_betters_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  AudioBettersPlugin* plugin = AUDIO_BETTERS_PLUGIN(
      g_object_new(audio_betters_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "audio_betters",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}

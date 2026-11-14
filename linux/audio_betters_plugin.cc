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
  GstElement* recorder;
  GstBus* recorder_bus;
  gboolean recorder_has_level;
  gdouble recorder_level_db;
  gchar* recorder_path;
};

G_DEFINE_TYPE(AudioBettersPlugin, audio_betters_plugin, g_object_get_type())

// Pull pending "level" messages off the recorder bus into recorder_level_db.
// gst_bus_pop_filtered is non-blocking and only touches ELEMENT messages, so
// the EOS/ERROR wait in stopRecorder keeps working.
static void audio_betters_drain_levels(AudioBettersPlugin* self) {
  if (!self->recorder_bus) return;
  GstMessage* msg;
  while ((msg = gst_bus_pop_filtered(self->recorder_bus, GST_MESSAGE_ELEMENT)) != nullptr) {
    const GstStructure* structure = gst_message_get_structure(msg);
    if (structure != nullptr && gst_structure_has_name(structure, "level")) {
      const GValue* rms = gst_structure_get_value(structure, "rms");
      if (rms != nullptr && GST_VALUE_HOLDS_ARRAY(rms)) {
        GArray* arr = static_cast<GArray*>(g_value_get_boxed(rms));
        if (arr != nullptr && arr->len >= 1) {
          const gdouble* rms_values = static_cast<const gdouble*>(arr->data);
          self->recorder_level_db = rms_values[0];
          self->recorder_has_level = TRUE;
        }
      }
    }
    gst_message_unref(msg);
  }
}

static void audio_betters_reset_meter(AudioBettersPlugin* self) {
  if (self->recorder_bus) {
    gst_object_unref(self->recorder_bus);
    self->recorder_bus = nullptr;
  }
  self->recorder_has_level = FALSE;
  self->recorder_level_db = -99.0;
  if (self->recorder_path) {
    g_free(self->recorder_path);
    self->recorder_path = nullptr;
  }
}

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

    if (g_str_has_prefix(url, "http://") || g_str_has_prefix(url, "https://") || g_str_has_prefix(url, "file://")) {
        g_object_set(self->playbin, "uri", url, NULL);
    } else {
        g_autofree gchar* file_uri = g_filename_to_uri(url, nullptr, nullptr);
        if (file_uri) {
            g_object_set(self->playbin, "uri", file_uri, NULL);
        } else {
            g_object_set(self->playbin, "uri", url, NULL);
        }
    }

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
  } else if (strcmp(method, "startRecorder") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* path = fl_value_get_string(fl_value_lookup_string(args, "path"));
    const gchar* format = fl_value_get_string(fl_value_lookup_string(args, "format"));

    if (self->recorder) {
      gst_element_set_state(self->recorder, GST_STATE_NULL);
      gst_object_unref(self->recorder);
      self->recorder = nullptr;
    }
    audio_betters_reset_meter(self);

    // Choose encoder based on format.
    // For AAC: prefer avenc_aac (gstreamer-libav) with fallback to voaacenc.
    // For WAV: use wavenc (always available with gstreamer-plugins-good).
    const gchar* encoder;
    if (strcmp(format, "wav") == 0) {
        encoder = "wavenc";
    } else {
        // Try avenc_aac first (gstreamer-libav), fall back to voaacenc
        GstElementFactory* aac_factory = gst_element_factory_find("avenc_aac");
        if (aac_factory) {
            gst_object_unref(aac_factory);
            encoder = "avenc_aac ! mp4mux";
        } else {
            encoder = "voaacenc ! mp4mux";
        }
    }

    // The "level" element (gst-plugins-good) posts rms/peak metering messages
    // on the pipeline bus every 50 ms; getRecorderAmplitude drains them.
    GError* pipeline_error = nullptr;
    gchar* pipeline_str = g_strdup_printf(
        "autoaudiosrc ! audioconvert ! audioresample ! "
        "level name=ab_level interval=50000000 ! %s ! filesink location=\"%s\"",
        encoder, path);
    self->recorder = gst_parse_launch(pipeline_str, &pipeline_error);
    g_free(pipeline_str);

    if (pipeline_error != nullptr || self->recorder == nullptr) {
      if (pipeline_error) g_error_free(pipeline_error);
      if (self->recorder) {
        gst_element_set_state(self->recorder, GST_STATE_NULL);
        gst_object_unref(self->recorder);
        self->recorder = nullptr;
      }
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "RECORDER_ERROR", "Failed to create GStreamer recording pipeline", nullptr));
      fl_method_call_respond(method_call, response, nullptr);
      return;
    }

    self->recorder_bus = gst_element_get_bus(self->recorder);
    self->recorder_path = g_strdup(path);
    gst_element_set_state(self->recorder, GST_STATE_PLAYING);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "stopRecorder") == 0) {
    g_autoptr(FlValue) path_value = self->recorder_path
        ? fl_value_new_string(self->recorder_path)
        : fl_value_new_null();
    if (self->recorder) {
      // Send EOS to flush and finalize the file properly
      gst_element_send_event(self->recorder, gst_event_new_eos());
      // Wait briefly for EOS to propagate before setting NULL state
      GstBus* bus = gst_element_get_bus(self->recorder);
      if (bus) {
        gst_bus_timed_pop_filtered(bus, 2 * GST_SECOND,
            static_cast<GstMessageType>(GST_MESSAGE_EOS | GST_MESSAGE_ERROR));
        gst_object_unref(bus);
      }
      gst_element_set_state(self->recorder, GST_STATE_NULL);
      gst_object_unref(self->recorder);
      self->recorder = nullptr;
    }
    audio_betters_reset_meter(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(path_value));
  } else if (strcmp(method, "getRecorderAmplitude") == 0) {
    double level = -1.0;
    if (self->recorder) {
      audio_betters_drain_levels(self);
      if (self->recorder_has_level) {
        // rms arrives in dBFS; map the -50 dB floor -> 0.0, full scale -> 1.0.
        level = (self->recorder_level_db + 50.0) / 50.0;
        if (level < 0.0) level = 0.0;
        if (level > 1.0) level = 1.0;
      }
    }
    g_autoptr(FlValue) result_val = fl_value_new_double(level);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_val));
  } else if (strcmp(method, "seekTo") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* position = fl_value_lookup_string(args, "position");
    if (position == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "ARGUMENT_ERROR", "Position is missing", nullptr));
    } else {
      gint64 position_ns = fl_value_get_int(position) * GST_MSECOND;
      GstState state = GST_STATE_VOID_PENDING;
      gst_element_get_state(self->playbin, &state, nullptr, 0);
      GstSeekFlags flags = static_cast<GstSeekFlags>(
          GST_SEEK_FLAG_FLUSH |
          (state == GST_STATE_PAUSED ? GST_SEEK_FLAG_PAUSED : 0));
      gboolean ok = gst_element_seek(self->playbin, 1.0, GST_FORMAT_TIME, flags,
                                     GST_SEEK_TYPE_SET, position_ns,
                                     GST_SEEK_TYPE_NONE, 0);
      if (ok) {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new(
            "SEEK_ERROR", "GStreamer seek failed", nullptr));
      }
    }
  } else if (strcmp(method, "getDuration") == 0) {
    gint64 duration = 0;
    // Query duration; playbin must be in PAUSED or PLAYING state for this to work
    if (self->playbin &&
        gst_element_query_duration(self->playbin, GST_FORMAT_TIME, &duration) &&
        duration > 0) {
      // Convert nanoseconds → milliseconds
      gint64 duration_ms = duration / GST_MSECOND;
      g_autoptr(FlValue) result_val = fl_value_new_int(duration_ms);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_val));
    } else {
      g_autoptr(FlValue) result_val = fl_value_new_int(0);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_val));
    }
  } else if (strcmp(method, "getCurrentPosition") == 0) {
    gint64 position = 0;
    // Query current playback position
    if (self->playbin &&
        gst_element_query_position(self->playbin, GST_FORMAT_TIME, &position) &&
        position > 0) {
      // Convert nanoseconds → milliseconds
      gint64 position_ms = position / GST_MSECOND;
      g_autoptr(FlValue) result_val = fl_value_new_int(position_ms);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_val));
    } else {
      g_autoptr(FlValue) result_val = fl_value_new_int(0);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_val));
    }
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
  if (self->recorder) {
    gst_element_set_state(self->recorder, GST_STATE_NULL);
    gst_object_unref(self->recorder);
    self->recorder = nullptr;
  }
  audio_betters_reset_meter(self);
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

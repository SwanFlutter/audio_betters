#ifndef FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace audio_betters {

class AudioBettersPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AudioBettersPlugin();

  virtual ~AudioBettersPlugin();

  // Disallow copy and assign.
  AudioBettersPlugin(const AudioBettersPlugin&) = delete;
  AudioBettersPlugin& operator=(const AudioBettersPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace audio_betters

#endif  // FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_

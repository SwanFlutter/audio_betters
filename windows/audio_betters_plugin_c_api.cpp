#include "include/audio_betters/audio_betters_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "audio_betters_plugin.h"

void AudioBettersPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  audio_betters::AudioBettersPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

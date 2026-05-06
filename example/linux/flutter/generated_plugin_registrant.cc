//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audio_betters/audio_betters_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) audio_betters_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AudioBettersPlugin");
  audio_betters_plugin_register_with_registrar(audio_betters_registrar);
}

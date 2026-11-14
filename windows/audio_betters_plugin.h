#ifndef FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <atomic>
#include <memory>
#include <string>

// winmm types (HWAVEIN, WAVEHDR, WAVEFORMATEX).
#include <mmsystem.h>

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

 private:
  // --- Microphone level metering -------------------------------------------
  // MCI (used for recording) exposes no mic level API, so a small waveIn
  // capture loop runs alongside the MCI recorder — both attach to the default
  // capture device through WASAPI shared mode. It only samples RMS levels;
  // audio data never leaves the thread.

  // Opens the parallel waveIn capture and the worker thread. Failures are
  // silent: getRecorderAmplitude then keeps returning -1.0.
  void StartLevelMetering();
  // Stops and releases the waveIn capture and worker thread.
  void StopLevelMetering();
  static DWORD CALLBACK LevelThreadEntry(LPVOID param);
  DWORD LevelThreadLoop();

  static constexpr int kLevelBuffers = 4;
  static constexpr int kLevelSamples = 1024;  // 64 ms at 16 kHz mono 16-bit

  HWAVEIN level_wave_in_ = nullptr;
  HANDLE level_event_ = nullptr;   // auto-reset event signalled by waveIn
  HANDLE level_thread_ = nullptr;
  std::atomic<bool> level_running_{false};
  std::atomic<double> level_{-1.0};
  LPWAVEHDR level_headers_ = nullptr;
  BYTE* level_buffers_ = nullptr;

  // --------------------------------------------------------------------------

  std::wstring last_record_path;
  std::string last_record_path_utf8;
};

}  // namespace audio_betters

#endif  // FLUTTER_PLUGIN_AUDIO_BETTERS_PLUGIN_H_

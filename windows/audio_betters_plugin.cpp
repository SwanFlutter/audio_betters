#include "audio_betters_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>
#include <mmsystem.h>

// Ensure MMSYSERR_NOERROR and MMSYSERR_NO_ERROR are defined
#ifndef MMSYSERR_NOERROR
#define MMSYSERR_NOERROR 0
#endif
#ifndef MMSYSERR_NO_ERROR
#define MMSYSERR_NO_ERROR MMSYSERR_NOERROR
#endif

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cmath>
#include <memory>
#include <sstream>
#include <string>
#include <algorithm>

#pragma comment(lib, "winmm.lib")

namespace audio_betters {

void AudioBettersPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "audio_betters",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioBettersPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AudioBettersPlugin::AudioBettersPlugin() {}

AudioBettersPlugin::~AudioBettersPlugin() {
  StopLevelMetering();
  mciSendStringW(L"close MyAudio", NULL, 0, NULL);
  mciSendStringW(L"close MyRecorder", NULL, 0, NULL);
}

void AudioBettersPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("play") == 0) {
    if (arguments) {
      auto url_it = arguments->find(flutter::EncodableValue("url"));
      if (url_it != arguments->end() && std::holds_alternative<std::string>(url_it->second)) {
        std::string url = std::get<std::string>(url_it->second);

        // Convert forward slashes to backslashes for MCI compatibility
        std::replace(url.begin(), url.end(), '/', '\\');

        std::wstring wurl(url.begin(), url.end());

        mciSendStringW(L"close MyAudio", NULL, 0, NULL);

        std::wstring type = L"mpegvideo";
        if (wurl.find(L".wav") != std::wstring::npos) {
            type = L"waveaudio";
        }

        std::wstring openCommand = L"open \"" + wurl + L"\" type " + type + L" alias MyAudio";
        MCIERROR open_err = mciSendStringW(openCommand.c_str(), NULL, 0, NULL);
        if (open_err != 0 && type == L"mpegvideo") {
          // Some machines lack a registered mpegvideo device; let the file
          // extension pick the device instead.
          openCommand = L"open \"" + wurl + L"\" alias MyAudio";
          open_err = mciSendStringW(openCommand.c_str(), NULL, 0, NULL);
        }
        if (open_err != 0) {
          result->Error("MCI_OPEN_ERROR",
                        "MCI could not open \"" + url + "\"");
          return;
        }
        mciSendStringW(L"set MyAudio time format milliseconds", NULL, 0, NULL);
        MCIERROR play_err = mciSendStringW(L"play MyAudio", NULL, 0, NULL);
        if (play_err != 0) {
          result->Error("MCI_PLAY_ERROR", "MCI could not start playback");
          return;
        }
        result->Success(flutter::EncodableValue());
      } else {
        result->Error("ARGUMENT_ERROR", "URL is missing or invalid");
      }
    } else {
      result->Error("ARGUMENT_ERROR", "Arguments are missing");
    }
  } else if (method_call.method_name().compare("pause") == 0) {
    mciSendStringW(L"pause MyAudio", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("resume") == 0) {
    // After a seek in a paused state the device is "stopped", where MCI's
    // resume is rejected; play from the parked position instead.
    wchar_t mode[64] = L"";
    mciSendStringW(L"status MyAudio mode", mode, 64, NULL);
    const std::wstring mode_str(mode);
    if (mode_str == L"paused") {
      mciSendStringW(L"resume MyAudio", NULL, 0, NULL);
    } else if (mode_str != L"playing") {
      mciSendStringW(L"play MyAudio", NULL, 0, NULL);
    }
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("stop") == 0) {
    mciSendStringW(L"stop MyAudio", NULL, 0, NULL);
    mciSendStringW(L"close MyAudio", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("seekTo") == 0) {
    if (arguments) {
      auto pos_it = arguments->find(flutter::EncodableValue("position"));
      if (pos_it != arguments->end()) {
        int64_t pos = 0;
        if (std::holds_alternative<int32_t>(pos_it->second)) {
          pos = std::get<int32_t>(pos_it->second);
        } else if (std::holds_alternative<int64_t>(pos_it->second)) {
          pos = std::get<int64_t>(pos_it->second);
        }

        wchar_t mode[64] = L"";
        mciSendStringW(L"status MyAudio mode", mode, 64, NULL);
        if (std::wstring(mode) == L"playing") {
          // One step: keep playing from the new position.
          std::wstring cmd = L"play MyAudio from " + std::to_wstring(pos);
          mciSendStringW(cmd.c_str(), NULL, 0, NULL);
        } else {
          // waveaudio cannot seek while paused; stop parks the device, then
          // seek sets the position resume will play from.
          mciSendStringW(L"stop MyAudio", NULL, 0, NULL);
          std::wstring cmd = L"seek MyAudio to " + std::to_wstring(pos);
          mciSendStringW(cmd.c_str(), NULL, 0, NULL);
        }
        result->Success(flutter::EncodableValue());
      } else {
        result->Error("ARGUMENT_ERROR", "Position is missing");
      }
    } else {
      result->Error("ARGUMENT_ERROR", "Arguments are missing");
    }
  } else if (method_call.method_name().compare("setVolume") == 0) {
    if (arguments) {
        auto vol_it = arguments->find(flutter::EncodableValue("volume"));
        if (vol_it != arguments->end()) {
            double volume = 0.0;
            if (std::holds_alternative<double>(vol_it->second)) {
                volume = std::get<double>(vol_it->second);
            } else if (std::holds_alternative<int32_t>(vol_it->second)) {
                volume = static_cast<double>(std::get<int32_t>(vol_it->second));
            }
            int vol = static_cast<int>(volume * 1000);
            std::wstring volCommand = L"setaudio MyAudio volume to " + std::to_wstring(vol);
            mciSendStringW(volCommand.c_str(), NULL, 0, NULL);
            result->Success(flutter::EncodableValue());
        } else {
            result->Error("ARGUMENT_ERROR", "Volume is missing or invalid");
        }
    } else {
        result->Error("ARGUMENT_ERROR", "Arguments are missing");
    }
  } else if (method_call.method_name().compare("startRecorder") == 0) {
    if (arguments) {
        auto path_it = arguments->find(flutter::EncodableValue("path"));
        if (path_it != arguments->end() && std::holds_alternative<std::string>(path_it->second)) {
            std::string path = std::get<std::string>(path_it->second);

            // Convert forward slashes to backslashes for MCI compatibility
            std::replace(path.begin(), path.end(), '/', '\\');

            last_record_path = std::wstring(path.begin(), path.end());
            last_record_path_utf8 = path;

            // Note: maxDuration and format are not implemented via MCI in this
            // simple version; callers needing a cap should time it themselves
            // (startConversation does).
            mciSendStringW(L"close MyRecorder", NULL, 0, NULL);
            MCIERROR open_err =
                mciSendStringW(L"open new type waveaudio alias MyRecorder", NULL, 0, NULL);
            if (open_err != 0) {
                last_record_path.clear();
                last_record_path_utf8.clear();
                result->Error("RECORDER_ERROR",
                              "MCI could not open the recorder (no capture device?)");
                return;
            }
            MCIERROR rec_err = mciSendStringW(L"record MyRecorder", NULL, 0, NULL);
            if (rec_err != 0) {
                mciSendStringW(L"close MyRecorder", NULL, 0, NULL);
                last_record_path.clear();
                last_record_path_utf8.clear();
                result->Error("RECORDER_ERROR", "MCI could not start recording");
                return;
            }
            // Metering is best effort: failure leaves getRecorderAmplitude
            // at -1.0 while recording itself continues to work.
            StartLevelMetering();
            result->Success(flutter::EncodableValue());
        } else {
            result->Error("ARGUMENT_ERROR", "Path is missing or invalid");
        }
    } else {
        result->Error("ARGUMENT_ERROR", "Arguments are missing");
    }
  } else if (method_call.method_name().compare("stopRecorder") == 0) {
    StopLevelMetering();
    // The `wait` flag is REQUIRED: without it stop/save return immediately
    // and the WAV file ends up truncated/headerless (undecodable).
    mciSendStringW(L"stop MyRecorder wait", NULL, 0, NULL);
    std::wstring saveCommand = L"save MyRecorder \"" + last_record_path + L"\" wait";
    mciSendStringW(saveCommand.c_str(), NULL, 0, NULL);
    mciSendStringW(L"close MyRecorder wait", NULL, 0, NULL);
    if (last_record_path_utf8.empty()) {
      result->Success(flutter::EncodableValue());
    } else {
      result->Success(flutter::EncodableValue(last_record_path_utf8));
    }
  } else if (method_call.method_name().compare("getRecorderAmplitude") == 0) {
    result->Success(flutter::EncodableValue(level_.load()));
  } else if (method_call.method_name().compare("getDuration") == 0) {
    wchar_t duration[128];
    mciSendStringW(L"status MyAudio length", duration, 128, NULL);
    try {
        int64_t dur = std::stoll(duration);
        result->Success(flutter::EncodableValue(dur));
    } catch (...) {
        result->Success(flutter::EncodableValue(0));
    }
  } else if (method_call.method_name().compare("getCurrentPosition") == 0) {
    wchar_t position[128];
    mciSendStringW(L"status MyAudio position", position, 128, NULL);
    try {
        int64_t pos = std::stoll(position);
        result->Success(flutter::EncodableValue(pos));
    } catch (...) {
        result->Success(flutter::EncodableValue(0));
    }
  } else {
    result->NotImplemented();
  }
}

// ---------------------------------------------------------------------------
// Microphone level metering.
//
// A parallel waveIn capture reads the default microphone (allowed concurrently
// with the MCI recorder through WASAPI shared mode) and the worker thread
// reduces each 64 ms buffer to a normalized RMS level. No audio data is kept
// or forwarded anywhere.
// ---------------------------------------------------------------------------

namespace {
// winmm reports success as 0 (MMSYSERR_NOERROR); the constant is not defined
// by all SDK headers, so compare against the numeric success code directly.
constexpr MMRESULT kMmeSuccess = 0;
}  // namespace

DWORD CALLBACK AudioBettersPlugin::LevelThreadEntry(LPVOID param) {
  auto* self = static_cast<AudioBettersPlugin*>(param);
  return self->LevelThreadLoop();
}

DWORD AudioBettersPlugin::LevelThreadLoop() {
  while (level_running_.load()) {
    WaitForSingleObject(level_event_, 100);
    const HWAVEIN hwi = level_wave_in_;
    if (hwi == nullptr || level_headers_ == nullptr) break;
    for (int i = 0; i < kLevelBuffers; ++i) {
      LPWAVEHDR hdr = &level_headers_[i];
      if ((hdr->dwFlags & WHDR_DONE) == 0) continue;
      const int sample_count = static_cast<int>(hdr->dwBytesRecorded / sizeof(int16_t));
      if (sample_count > 0) {
        const int16_t* samples = reinterpret_cast<const int16_t*>(hdr->lpData);
        double sum_squares = 0.0;
        for (int s = 0; s < sample_count; ++s) {
          const double norm = samples[s] / 32768.0;
          sum_squares += norm * norm;
        }
        const double rms = std::sqrt(sum_squares / sample_count);
        double level = 0.0;
        if (rms > 0.0) {
          const double db = 20.0 * std::log10(rms);  // dBFS
          level = (db + 50.0) / 50.0;
          if (level < 0.0) level = 0.0;
          if (level > 1.0) level = 1.0;
        }
        level_.store(level);
      }
      if (!level_running_.load()) break;
      waveInAddBuffer(hwi, hdr, sizeof(WAVEHDR));
    }
  }
  return 0;
}

void AudioBettersPlugin::StartLevelMetering() {
  StopLevelMetering();

  level_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (level_event_ == nullptr) return;

  WAVEFORMATEX fmt{};
  fmt.wFormatTag = WAVE_FORMAT_PCM;
  fmt.nChannels = 1;
  fmt.nSamplesPerSec = 16000;
  fmt.wBitsPerSample = 16;
  fmt.nBlockAlign = fmt.nChannels * fmt.wBitsPerSample / 8;
  fmt.nAvgBytesPerSec = fmt.nSamplesPerSec * fmt.nBlockAlign;
  fmt.cbSize = 0;

  const MMRESULT rc = waveInOpen(
      &level_wave_in_, WAVE_MAPPER, &fmt,
      reinterpret_cast<DWORD_PTR>(level_event_), 0, CALLBACK_EVENT);
  if (rc != kMmeSuccess) {
    level_wave_in_ = nullptr;
    CloseHandle(level_event_);
    level_event_ = nullptr;
    return;
  }

  constexpr DWORD kBytes = static_cast<DWORD>(kLevelSamples * sizeof(int16_t));
  level_headers_ = new WAVEHDR[kLevelBuffers]();
  level_buffers_ = new BYTE[static_cast<size_t>(kLevelBuffers) * kBytes]();
  for (int i = 0; i < kLevelBuffers; ++i) {
    LPWAVEHDR hdr = &level_headers_[i];
    hdr->lpData = reinterpret_cast<LPSTR>(level_buffers_ + static_cast<size_t>(i) * kBytes);
    hdr->dwBufferLength = kBytes;
    hdr->dwFlags = 0;
    hdr->dwUser = static_cast<DWORD_PTR>(i);
    if (waveInPrepareHeader(level_wave_in_, hdr, sizeof(WAVEHDR)) != kMmeSuccess) {
      break;
    }
    if (waveInAddBuffer(level_wave_in_, hdr, sizeof(WAVEHDR)) != kMmeSuccess) {
      break;
    }
  }

  if (waveInStart(level_wave_in_) != kMmeSuccess) {
    StopLevelMetering();
    return;
  }

  level_.store(-1.0);
  level_running_.store(true);
  level_thread_ = CreateThread(nullptr, 0, &LevelThreadEntry, this, 0, nullptr);
  if (level_thread_ == nullptr) {
    level_running_.store(false);
    StopLevelMetering();
  }
}

void AudioBettersPlugin::StopLevelMetering() {
  const bool was_running = level_running_.exchange(false);
  if (level_wave_in_ != nullptr) {
    waveInStop(level_wave_in_);
    waveInReset(level_wave_in_);
  }
  if (level_event_ != nullptr) SetEvent(level_event_);
  if (level_thread_ != nullptr) {
    if (was_running) WaitForSingleObject(level_thread_, 2000);
    CloseHandle(level_thread_);
    level_thread_ = nullptr;
  }
  if (level_wave_in_ != nullptr) {
    if (level_headers_ != nullptr) {
      for (int i = 0; i < kLevelBuffers; ++i) {
        if ((level_headers_[i].dwFlags & WHDR_PREPARED) != 0) {
          waveInUnprepareHeader(level_wave_in_, &level_headers_[i], sizeof(WAVEHDR));
        }
      }
    }
    waveInClose(level_wave_in_);
    level_wave_in_ = nullptr;
  }
  delete[] level_headers_;
  level_headers_ = nullptr;
  delete[] level_buffers_;
  level_buffers_ = nullptr;
  if (level_event_ != nullptr) {
    CloseHandle(level_event_);
    level_event_ = nullptr;
  }
  level_.store(-1.0);
}

}  // namespace audio_betters

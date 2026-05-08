#include "audio_betters_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>
#include <mmsystem.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>

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
  mciSendString(L"close MyAudio", NULL, 0, NULL);
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
        std::wstring wurl(url.begin(), url.end());

        mciSendString(L"close MyAudio", NULL, 0, NULL);

        std::wstring type = L"mpegvideo";
        if (wurl.find(L".wav") != std::wstring::npos) {
            type = L"waveaudio";
        }

        std::wstring openCommand = L"open \"" + wurl + L"\" type " + type + L" alias MyAudio";
        mciSendString(openCommand.c_str(), NULL, 0, NULL);
        mciSendString(L"set MyAudio time format milliseconds", NULL, 0, NULL);
        mciSendString(L"play MyAudio", NULL, 0, NULL);
        result->Success(flutter::EncodableValue());
      } else {
        result->Error("ARGUMENT_ERROR", "URL is missing or invalid");
      }
    } else {
      result->Error("ARGUMENT_ERROR", "Arguments are missing");
    }
  } else if (method_call.method_name().compare("pause") == 0) {
    mciSendString(L"pause MyAudio", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("resume") == 0) {
    mciSendString(L"resume MyAudio", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("stop") == 0) {
    mciSendString(L"stop MyAudio", NULL, 0, NULL);
    mciSendString(L"close MyAudio", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
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
            mciSendString(volCommand.c_str(), NULL, 0, NULL);
            result->Success(flutter::EncodableValue());
        }
    }
  } else if (method_call.method_name().compare("startRecorder") == 0) {
    if (arguments) {
        auto path_it = arguments->find(flutter::EncodableValue("path"));
        if (path_it != arguments->end() && std::holds_alternative<std::string>(path_it->second)) {
            std::string path = std::get<std::string>(path_it->second);
            last_record_path = std::wstring(path.begin(), path.end());

            // Note: maxDuration and format are not fully implemented via MCI in this simple version
            mciSendString(L"close MyRecorder", NULL, 0, NULL);
            mciSendString(L"open new type waveaudio alias MyRecorder", NULL, 0, NULL);
            mciSendString(L"record MyRecorder", NULL, 0, NULL);
            result->Success(flutter::EncodableValue());
        }
    }
  } else if (method_call.method_name().compare("stopRecorder") == 0) {
    mciSendString(L"stop MyRecorder", NULL, 0, NULL);
    std::wstring saveCommand = L"save MyRecorder \"" + last_record_path + L"\"";
    mciSendString(saveCommand.c_str(), NULL, 0, NULL);
    mciSendString(L"close MyRecorder", NULL, 0, NULL);
    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("getDuration") == 0) {
    wchar_t duration[128];
    mciSendString(L"status MyAudio length", duration, 128, NULL);
    try {
        int64_t dur = std::stoll(duration);
        result->Success(flutter::EncodableValue(dur));
    } catch (...) {
        result->Success(flutter::EncodableValue(0));
    }
  } else if (method_call.method_name().compare("getCurrentPosition") == 0) {
    wchar_t position[128];
    mciSendString(L"status MyAudio position", position, 128, NULL);
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

}  // namespace audio_betters

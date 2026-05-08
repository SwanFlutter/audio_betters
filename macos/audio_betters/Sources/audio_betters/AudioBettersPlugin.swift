import Cocoa
import FlutterMacOS
import AVFoundation

public class AudioBettersPlugin: NSObject, FlutterPlugin {
  private var player: AVPlayer?
  private var recorder: AVAudioRecorder?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_betters", binaryMessenger: registrar.messenger)
    let instance = AudioBettersPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "play":
      guard let args = call.arguments as? [String: Any],
            let urlString = args["url"] as? String else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid URL", details: nil))
        return
      }

      let url: URL
      if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
          guard let webUrl = URL(string: urlString) else {
              result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid Web URL", details: nil))
              return
          }
          url = webUrl
      } else {
          url = URL(fileURLWithPath: urlString)
      }

      play(url: url, result: result)
    case "pause":
      player?.pause()
      result(nil)
    case "resume":
      player?.play()
      result(nil)
    case "stop":
      player?.pause()
      player = nil
      result(nil)
    case "setVolume":
      guard let args = call.arguments as? [String: Any],
            let volume = args["volume"] as? Float else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid volume", details: nil))
        return
      }
      player?.volume = volume
      result(nil)
    case "startRecorder":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid path", details: nil))
        return
      }
      let format = args["format"] as? String ?? "aac"
      let maxDuration = args["maxDuration"] as? Double
      startRecorder(path: path, format: format, maxDuration: maxDuration, result: result)
    case "stopRecorder":
      stopRecorder(result: result)
    case "getDuration":
      if let item = player?.currentItem {
          let duration = CMTimeGetSeconds(item.asset.duration)
          result(Int(duration * 1000))
      } else {
          result(0)
      }
    case "getCurrentPosition":
      if let player = player {
          let position = CMTimeGetSeconds(player.currentTime())
          result(Int(position * 1000))
      } else {
          result(0)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startRecorder(path: String, format: String, maxDuration: Double?, result: @escaping FlutterResult) {
    var settings: [String: Any] = [
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 2,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    if format == "wav" {
        settings[AVFormatIDKey] = Int(kAudioFormatLinearPCM)
        settings[AVLinearPCMBitDepthKey] = 16
        settings[AVLinearPCMIsFloatKey] = false
        settings[AVLinearPCMIsBigEndianKey] = false
    } else {
        settings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
    }

    let url = URL(fileURLWithPath: path)

    do {
      recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder?.prepareToRecord()

      if let duration = maxDuration, duration > 0 {
          recorder?.record(forDuration: duration / 1000.0)
      } else {
          recorder?.record()
      }
      result(nil)
    } catch {
      result(FlutterError(code: "RECORDER_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func stopRecorder(result: @escaping FlutterResult) {
    recorder?.stop()
    recorder = nil
    result(nil)
  }

  private func play(url: URL, result: @escaping FlutterResult) {
    let playerItem = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: playerItem)
    player?.play()
    result(nil)
  }
}

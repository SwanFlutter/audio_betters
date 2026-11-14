import Cocoa
import FlutterMacOS
import AVFoundation

public class AudioBettersPlugin: NSObject, FlutterPlugin {
  private var player: AVPlayer?
  private var recorder: AVAudioRecorder?
  private var recordingPath: String?

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
    case "getRecorderAmplitude":
      guard let rec = recorder, rec.isRecording else {
        result(-1.0)
        return
      }
      // averagePower is dBFS (-160...0); map the -50 dBFS floor -> 0.0 and
      // full scale -> 1.0 so thresholds behave like on every other platform.
      // Apple requires updateMeters() before the power readings refresh.
      rec.updateMeters()
      let db = rec.averagePower
      let level = max(0.0, min(1.0, (db + 50.0) / 50.0))
      result(Double(level))
    case "seekTo":
      guard let args = call.arguments as? [String: Any],
            let position = args["position"] as? Int else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid position", details: nil))
        return
      }
      let time = CMTime(seconds: Double(position) / 1000.0, preferredTimescale: 600)
      player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
      result(nil)
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
      recorder?.meteringEnabled = true
      recorder?.prepareToRecord()

      if let duration = maxDuration, duration > 0 {
          recorder?.record(forDuration: duration / 1000.0)
      } else {
          recorder?.record()
      }
      recordingPath = path
      result(nil)
    } catch {
      recorder = nil
      recordingPath = nil
      result(FlutterError(code: "RECORDER_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func stopRecorder(result: @escaping FlutterResult) {
    let path = recordingPath
    recordingPath = nil
    recorder?.stop()
    recorder = nil
    result(path)
  }

  private func play(url: URL, result: @escaping FlutterResult) {
    let playerItem = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: playerItem)
    player?.play()
    result(nil)
  }
}

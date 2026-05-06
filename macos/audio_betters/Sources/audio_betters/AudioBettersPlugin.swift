import Cocoa
import FlutterMacOS
import AVFoundation

public class AudioBettersPlugin: NSObject, FlutterPlugin {
  private var player: AVPlayer?

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
            let urlString = args["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "ARGUMENT_ERROR", message: "Invalid URL", details: nil))
        return
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
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func play(url: URL, result: @escaping FlutterResult) {
    let playerItem = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: playerItem)
    player?.play()
    result(nil)
  }
}

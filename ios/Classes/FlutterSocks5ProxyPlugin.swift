import Flutter
import UIKit

public class FlutterSocks5ProxyPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_socks5_proxy", binaryMessenger: registrar.messenger())
    let instance = FlutterSocks5ProxyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterError(code: "PLATFORM_NOT_SUPPORTED",
                         message: "SOCKS5 proxy is not yet supported on iOS",
                         details: nil))
    }
  }
}
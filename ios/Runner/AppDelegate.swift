import Flutter
import UIKit
import GoogleCast

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let factory = AirPlayRoutePickerViewFactory()
    self.registrar(forPlugin: "AirPlayRoutePickerView")?.register(factory, withId: "AirPlayRoutePickerView")
    let criteria = GCKDiscoveryCriteria(applicationID: "CC1AD845")
    let options = GCKCastOptions(discoveryCriteria: criteria)
    GCKCastContext.setSharedInstanceWith(options)
    self.registrar(forPlugin: "ChromecastButtonView")?.register(ChromecastButtonViewFactory(), withId: "ChromecastButtonView")
    if let registrar = self.registrar(forPlugin: "ChromecastChannel") {
      _ = ChromecastChannel.register(with: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class ChromecastButtonViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ChromecastButtonPlatformView(frame: frame)
  }
}

class ChromecastButtonPlatformView: NSObject, FlutterPlatformView {
  private let button: GCKUICastButton
  init(frame: CGRect) {
    self.button = GCKUICastButton(frame: frame)
    super.init()
    self.button.tintColor = .label
    self.button.contentMode = .scaleAspectFit
  }
  func view() -> UIView { button }
}

class ChromecastChannel: NSObject {
  private let channel: FlutterMethodChannel
  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "com.smartiptv.pro/chromecast", binaryMessenger: messenger)
    super.init()
    self.channel.setMethodCallHandler(self.handle(_:result:))
  }
  static func register(with messenger: FlutterBinaryMessenger) -> ChromecastChannel {
    ChromecastChannel(messenger: messenger)
  }
  private func remoteClient() -> GCKRemoteMediaClient? {
    GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "load":
      guard let args = call.arguments as? [String: Any],
            let urlStr = args["url"] as? String,
            let contentType = args["contentType"] as? String,
            let title = args["title"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing required args", details: nil))
        return
      }
      let subtitle = args["subtitle"] as? String
      let imageUrl = args["imageUrl"] as? String
      let startSeconds = (args["startSeconds"] as? Double) ?? 0.0
      let streamTypeStr = (args["streamType"] as? String) ?? "buffered"
      guard let client = remoteClient() else {
        result(FlutterError(code: "no_session", message: "No active Cast session", details: nil))
        return
      }
      let metadata = GCKMediaMetadata(metadataType: .movie)
      metadata.setString(title, forKey: kGCKMetadataKeyTitle)
      if let subtitle = subtitle { metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle) }
      if let imageUrl = imageUrl, let u = URL(string: imageUrl) {
        metadata.addImage(GCKImage(url: u, width: 480, height: 720))
      }
      let streamType: GCKMediaStreamType = (streamTypeStr == "live") ? .live : .buffered
      guard let contentURL = URL(string: urlStr) else {
        result(FlutterError(code: "bad_url", message: "Invalid URL", details: nil))
        return
      }
      let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: contentURL)
      mediaInfoBuilder.contentType = contentType
      mediaInfoBuilder.streamType = streamType
      mediaInfoBuilder.metadata = metadata
      let mediaInfo = mediaInfoBuilder.build()
      let options = GCKMediaLoadOptions()
      options.autoplay = true
      options.playPosition = startSeconds
      client.loadMedia(mediaInfo, with: options)
      result(true)
    case "play":
      guard let client = remoteClient() else { result(FlutterError(code: "no_session", message: "No active Cast session", details: nil)); return }
      client.play()
      result(true)
    case "pause":
      guard let client = remoteClient() else { result(FlutterError(code: "no_session", message: "No active Cast session", details: nil)); return }
      client.pause()
      result(true)
    case "seek":
      guard let args = call.arguments as? [String: Any], let pos = args["positionSeconds"] as? Double else {
        result(FlutterError(code: "bad_args", message: "Missing positionSeconds", details: nil))
        return
      }
      guard let client = remoteClient() else { result(FlutterError(code: "no_session", message: "No active Cast session", details: nil)); return }
      client.seek(toTimeInterval: pos)
      result(true)
    case "stop":
      guard let client = remoteClient() else { result(FlutterError(code: "no_session", message: "No active Cast session", details: nil)); return }
      client.stop()
      result(true)
    case "getStatus":
      guard let client = remoteClient(), let status = client.mediaStatus else {
        result(nil)
        return
      }
      let dict: [String: Any] = [
        "duration": status.mediaInformation?.streamDuration ?? 0,
        "position": status.streamPosition,
        "playerState": status.playerState.rawValue
      ]
      result(dict)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}


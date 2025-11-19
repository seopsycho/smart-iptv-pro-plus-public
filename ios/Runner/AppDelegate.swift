import Flutter
import UIKit
import GoogleCast
import AVFoundation
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  // MARK: - Orientation Management
  
  private var shouldAllowLandscape = false
  
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
    if let registrar = self.registrar(forPlugin: "AirPlayChannel") {
      _ = AirPlayChannel.register(with: registrar.messenger())
    }
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
    try? session.setActive(true)
    
    // Setup orientation control channel
    setupOrientationChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupOrientationChannel() {
    guard let registrar = self.registrar(forPlugin: "OrientationChannel") else { return }
    let channel = FlutterMethodChannel(name: "com.smartiptv.pro/orientation", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleOrientationCall(call, result: result)
    }
  }
  
  private func handleOrientationCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enableLandscape":
      shouldAllowLandscape = true
      DispatchQueue.main.async {
        self.attemptRotationToDeviceOrientation()
      }
      result(true)
    case "disableLandscape":
      shouldAllowLandscape = false
      DispatchQueue.main.async {
        self.attemptRotationToDeviceOrientation()
      }
      result(true)
    case "forcePortrait":
      shouldAllowLandscape = false
      DispatchQueue.main.async {
        // Ensure iOS updates the orientation mask before setting the device value
        self.attemptRotationToDeviceOrientation()
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        // Nudge the root VC to re-query supported orientations
        if #available(iOS 16.0, *) {
          UIApplication.shared.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
      }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    if shouldAllowLandscape {
      return .allButUpsideDown
    } else {
      return .portrait
    }
  }

  // Allow Flutter to query per-window supported orientations dynamically
  override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return shouldAllowLandscape ? .allButUpsideDown : .portrait
  }
  
  var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    if shouldAllowLandscape {
      return UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
    } else {
      return .portrait
    }
  }
  
  private func attemptRotationToDeviceOrientation() {
    if #available(iOS 16.0, *) {
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
      let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: supportedInterfaceOrientations)
      windowScene?.requestGeometryUpdate(geometryPreferences) { error in
        print("Orientation update error: \(error)")
      }
    } else {
      UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
      UINavigationController.attemptRotationToDeviceOrientation()
    }
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

class AirPlayManager {
  static let shared = AirPlayManager()
  private init() {}
  var player: AVPlayer?
  var playerVC: AVPlayerViewController?

  func isAirPlayConnected() -> Bool {
    let route = AVAudioSession.sharedInstance().currentRoute
    for output in route.outputs {
      if output.portType == .airPlay { return true }
    }
    return false
  }

  func presentPlayer(on root: UIViewController, url: URL, headers: [String: String]?, startSeconds: Double) {
    let asset: AVURLAsset
    if let headers = headers, !headers.isEmpty {
      asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    } else {
      asset = AVURLAsset(url: url)
    }
    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    if startSeconds > 0 {
      let t = CMTime(seconds: startSeconds, preferredTimescale: 600)
      player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    player.usesExternalPlaybackWhileExternalScreenIsActive = true

    let vc = AVPlayerViewController()
    vc.player = player
    vc.modalPresentationStyle = .fullScreen
    vc.entersFullScreenWhenPlaybackBegins = true
    vc.exitsFullScreenWhenPlaybackEnds = true

    self.player = player
    self.playerVC = vc

    root.present(vc, animated: true) {
      player.play()
    }
  }

  func dismissPlayer(completion: (() -> Void)? = nil) {
    guard let vc = playerVC else { completion?(); return }
    vc.dismiss(animated: true) {
      self.player?.pause()
      self.player = nil
      self.playerVC = nil
      completion?()
    }
  }
}

class AirPlayChannel: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "com.smartiptv.pro/airplay", binaryMessenger: messenger)
    super.init()
    self.channel.setMethodCallHandler(self.handle(_:result:))
  }

  static func register(with messenger: FlutterBinaryMessenger) -> AirPlayChannel {
    AirPlayChannel(messenger: messenger)
  }

  private func topViewController() -> UIViewController? {
    func top(from root: UIViewController?) -> UIViewController? {
      if let nav = root as? UINavigationController { return top(from: nav.visibleViewController) }
      if let tab = root as? UITabBarController { return top(from: tab.selectedViewController) }
      if let presented = root?.presentedViewController { return top(from: presented) }
      return root
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes.first?.windows.first(where: { $0.isKeyWindow })
    return top(from: keyWindow?.rootViewController)
  }

  private func ensureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
    try? session.setActive(true)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isConnected":
      result(AirPlayManager.shared.isAirPlayConnected())
    case "play":
      guard let args = call.arguments as? [String: Any],
            let urlStr = args["url"] as? String,
            let url = URL(string: urlStr) else {
        result(FlutterError(code: "bad_args", message: "Missing or invalid url", details: nil))
        return
      }
      let startSeconds = (args["startSeconds"] as? Double) ?? 0.0
      let headers = args["headers"] as? [String: String]
      if !AirPlayManager.shared.isAirPlayConnected() {
        result(FlutterError(code: "no_route", message: "No AirPlay route selected", details: nil))
        return
      }
      guard let root = topViewController() else {
        result(FlutterError(code: "no_ui", message: "Unable to find root view controller", details: nil))
        return
      }
      ensureAudioSession()
      DispatchQueue.main.async {
        AirPlayManager.shared.presentPlayer(on: root, url: url, headers: headers, startSeconds: startSeconds)
        result(true)
      }
    case "pause":
      AirPlayManager.shared.player?.pause()
      result(true)
    case "resume":
      AirPlayManager.shared.player?.play()
      result(true)
    case "seek":
      guard let args = call.arguments as? [String: Any], let pos = args["positionSeconds"] as? Double else {
        result(FlutterError(code: "bad_args", message: "Missing positionSeconds", details: nil))
        return
      }
      let t = CMTime(seconds: pos, preferredTimescale: 600)
      AirPlayManager.shared.player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
      result(true)
    case "stop":
      DispatchQueue.main.async {
        AirPlayManager.shared.dismissPlayer() {
          result(true)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

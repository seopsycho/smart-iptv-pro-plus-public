import Foundation
import UIKit
import Flutter
import GoogleCast

class ChromecastButtonViewFactory: NSObject, FlutterPlatformViewFactory {
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return ChromecastButtonPlatformView(frame: frame)
    }
}

class ChromecastButtonPlatformView: NSObject, FlutterPlatformView {
    private let button: GCKUICastButton

    override init() {
        self.button = GCKUICastButton(frame: .zero)
        super.init()
        self.button.tintColor = .label
        self.button.contentMode = .scaleAspectFit
    }

    init(frame: CGRect) {
        self.button = GCKUICastButton(frame: frame)
        super.init()
        self.button.tintColor = .label
        self.button.contentMode = .scaleAspectFit
    }

    func view() -> UIView {
        return button
    }
}

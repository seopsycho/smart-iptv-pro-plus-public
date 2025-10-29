import Foundation
import UIKit
import AVKit
import Flutter

class AirPlayRoutePickerViewFactory: NSObject, FlutterPlatformViewFactory {
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return AirPlayRoutePickerPlatformView(frame: frame, arguments: args)
    }
}

class AirPlayRoutePickerPlatformView: NSObject, FlutterPlatformView {
    private let routePickerView: AVRoutePickerView

    init(frame: CGRect, arguments args: Any?) {
        self.routePickerView = AVRoutePickerView(frame: frame)
        super.init()
        if #available(iOS 13.0, *) {
            self.routePickerView.prioritizesVideoDevices = true
            self.routePickerView.activeTintColor = .systemBlue
        }
        self.routePickerView.tintColor = .label
    }

    func view() -> UIView {
        return routePickerView
    }
}

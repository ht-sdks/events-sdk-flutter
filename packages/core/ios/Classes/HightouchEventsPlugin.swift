import Flutter
import UIKit
import Foundation

public class HightouchEventsPlugin: NSObject, FlutterPlugin, NativeContextApi, FlutterStreamHandler, FlutterApplicationLifeCycleDelegate {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }

    var _eventSink:FlutterEventSink?;
    public func application(_ application: UIApplication, open url: URL, sourceApplication: String, annotation: Any) -> Bool {
        if (_eventSink != nil) {
            _eventSink?(["url": url.absoluteString, "referringApplication": sourceApplication])
        }
        return true
    }
    public func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        if (_eventSink != nil) {
            _eventSink?([url: url.absoluteString])
        }
        return true
    }

    internal static var device = VendorSystem.current

    func getContext(collectDeviceId: Bool, completion: @escaping (Result<NativeContext, Error>) -> Void) {
        let info = Bundle.main.infoDictionary
        let localizedInfo = Bundle.main.localizedInfoDictionary
        var app = [String: Any]()
        if let info = info {
            app.merge(info) { (_, new) in new }
        }
        if let localizedInfo = localizedInfo {
            app.merge(localizedInfo) { (_, new) in new }
        }
        let device = Self.device
        let screen = device.screenSize
        let userAgent = device.userAgent
        let status = device.connection

        var cellular = false
        var wifi = false
        var bluetooth = false

        switch status {
        case .online(.cellular):
            cellular = true
        case .online(.wifi):
            wifi = true
        case .online(.bluetooth):
            bluetooth = true
        default:
            break
        }

        completion(.success(NativeContext(
            app: app.count != 0 ? NativeContextApp(
                build: app["CFBundleVersion"] as! String? ?? "",
                name: app["CFBundleDisplayName"] as! String? ?? "",
                namespace: Bundle.main.bundleIdentifier ?? "",
                version: app["CFBundleShortVersionString"] as! String? ?? "") : nil,
            device: NativeContextDevice(
                id: collectDeviceId ? (device.identifierForVendor ?? "") : nil,
                manufacturer: device.manufacturer,
                model: device.model,
                name: device.name,
                type: device.type),
            locale: Locale.preferredLanguages.count > 0 ? Locale.preferredLanguages[0] : nil,
            network: NativeContextNetwork(
                cellular: cellular,
                wifi: wifi,
                bluetooth: bluetooth),
            os: NativeContextOS(
                name: device.systemName,
                version: device.systemVersion),
            screen: NativeContextScreen(
                height: Int32(screen.height),
                width: Int32(screen.width)),
            timezone: TimeZone.current.identifier,
            userAgent: userAgent)))
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger : FlutterBinaryMessenger = registrar.messenger()
        let api : NativeContextApi & NSObjectProtocol & HightouchEventsPlugin = HightouchEventsPlugin.init()
        NativeContextApiSetup.setUp(binaryMessenger: messenger, api: api)

        let channel:FlutterEventChannel = FlutterEventChannel(name: "hightouch_events/deep_link_events", binaryMessenger: registrar.messenger())
        channel.setStreamHandler(api)
    }
}

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var audioCacheCapacityChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let capacityChannel = FlutterMethodChannel(
      name: "com.hemusic/audio_cache_capacity",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    audioCacheCapacityChannel = capacityChannel
    capacityChannel.setMethodCallHandler { call, result in
      guard call.method == "availableBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["cachePath"] as? String, !path.isEmpty else {
        result(FlutterError(code: "invalid_path", message: "Cache directory is required", details: nil))
        return
      }
      DispatchQueue.global(qos: .utility).async {
        let response: Any
        do {
          let directory = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
          let cache = try FileManager.default.url(for: .cachesDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .standardizedFileURL.resolvingSymlinksInPath()
          var isDirectory: ObjCBool = false
          guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                isDirectory.boolValue,
                directory.path == cache.path || directory.path.hasPrefix(cache.path + "/") else {
            DispatchQueue.main.async {
              result(FlutterError(code: "invalid_path", message: "Not an application cache directory", details: nil))
            }
            return
          }
          let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey])
          if let bytes = values.volumeAvailableCapacityForOpportunisticUsage, bytes >= 0 {
            response = NSNumber(value: bytes)
          } else {
            response = NSNull()
          }
        } catch {
          response = FlutterError(code: "capacity_unavailable", message: "Cache capacity is unavailable", details: nil)
        }
        DispatchQueue.main.async { result(response) }
      }
    }

    // 限制最小窗口尺寸（桌面断点 840 + 两侧 padding）
    self.minSize = NSSize(width: 880, height: 540)
    self.setFrameAutosaveName("MainWindow")

    super.awakeFromNib()
  }
}

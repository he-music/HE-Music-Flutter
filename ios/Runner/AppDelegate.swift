import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupMediaLibraryChannel(with: engineBridge.applicationRegistrar.messenger())
    #if targetEnvironment(simulator)
    setupCacheSimulatorChannel(with: engineBridge.applicationRegistrar.messenger())
    #endif
  }

  #if targetEnvironment(simulator)
  private func setupCacheSimulatorChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.hemusic/audio_cache_capacity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let bundle = Bundle.main.bundleIdentifier ?? ""
      guard bundle == "com.hemusic.music.flutter.cachesim" else {
        result(FlutterError(code: "isolation_required", message: "Independent simulator bundle required", details: nil))
        return
      }
      if call.method == "simulatorIdentity" {
        result(["simulator": true, "bundle": bundle])
        return
      }
      guard call.method == "availableBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["cachePath"] as? String, path.hasPrefix("/") else {
        result(FlutterError(code: "invalid_path", message: "Cache directory required", details: nil))
        return
      }
      DispatchQueue.global(qos: .utility).async {
        let response: Any
        do {
          let directory = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
          let cache = try FileManager.default.url(for: .cachesDirectory,
            in: .userDomainMask, appropriateFor: nil, create: false)
            .standardizedFileURL.resolvingSymlinksInPath()
          var isDirectory: ObjCBool = false
          guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                isDirectory.boolValue, directory.path.hasPrefix(cache.path + "/") else {
            DispatchQueue.main.async {
              result(FlutterError(code: "invalid_path", message: "Not a cache subtree", details: nil))
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
          response = FlutterError(code: "capacity_unavailable", message: "Cache capacity unavailable", details: nil)
        }
        DispatchQueue.main.async { result(response) }
      }
    }
  }
  #endif

  private func setupMediaLibraryChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.hemusic.music/media_library",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "requestPermission":
        self?.handleRequestPermission(result: result)
      case "scanSongs":
        self?.handleScanSongs(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 请求媒体库访问权限
  private func handleRequestPermission(result: @escaping FlutterResult) {
    MPMediaLibrary.requestAuthorization { status in
      DispatchQueue.main.async {
        result(status == .authorized)
      }
    }
  }

  /// 扫描设备上的歌曲（后台线程执行，避免阻塞主线程触发 watchdog）
  private func handleScanSongs(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let query = MPMediaQuery.songs()
      guard let items = query.items else {
        DispatchQueue.main.async { result([]) }
        return
      }

      var tracks: [[String: Any]] = []
      for item in items {
        guard let assetURL = item.assetURL else { continue }

        let persistentID = String(item.persistentID)
        let title = item.title ?? ""
        let artist = item.artist ?? ""
        let album = item.albumTitle ?? ""
        let duration = Int((item.playbackDuration) * 1000) // 转为毫秒
        let filePath = assetURL.absoluteString
        let size = item.value(forProperty: "fileSize") as? Int ?? 0
        let mimeType = self.guessMimeType(from: filePath)

        // 跳过时长过短的项目（< 10 秒）
        if duration < 10000 { continue }

        let track: [String: Any] = [
          "id": persistentID,
          "title": title,
          "artist": artist,
          "album": album,
          "duration": duration,
          "filePath": filePath,
          "mimeType": mimeType,
          "size": size,
        ]
        tracks.append(track)
      }

      DispatchQueue.main.async { result(tracks) }
    }
  }

  /// 根据文件路径推断 MIME 类型
  private func guessMimeType(from path: String) -> String {
    let lower = path.lowercased()
    if lower.contains(".mp3") { return "audio/mpeg" }
    if lower.contains(".flac") { return "audio/flac" }
    if lower.contains(".m4a") { return "audio/mp4" }
    if lower.contains(".aac") { return "audio/aac" }
    if lower.contains(".wav") { return "audio/wav" }
    if lower.contains(".ogg") || lower.contains(".opus") { return "audio/ogg" }
    if lower.contains(".aiff") || lower.contains(".aif") { return "audio/wav" }
    if lower.contains(".ape") { return "audio/ape" }
    return ""
  }
}

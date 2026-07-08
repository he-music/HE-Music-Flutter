import FlutterMacOS
import Foundation

class SecurityScopedBookmarkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.hemusic.music.flutter/security_scoped_bookmark",
      binaryMessenger: registrar.messenger
    )
    let instance = SecurityScopedBookmarkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createBookmark":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
        return
      }
      createBookmark(for: path, result: result)

    case "resolveBookmark":
      guard let args = call.arguments as? [String: Any],
            let bookmark = args["bookmark"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing bookmark", details: nil))
        return
      }
      resolveBookmark(bookmark, result: result)

    case "stopAccessing":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
        return
      }
      stopAccessing(path: path, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createBookmark(for path: String, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: path)

    do {
      let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      let base64String = bookmarkData.base64EncodedString()
      result(base64String)
    } catch {
      result(FlutterError(code: "BOOKMARK_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func resolveBookmark(_ bookmarkString: String, result: @escaping FlutterResult) {
    guard let bookmarkData = Data(base64Encoded: bookmarkString) else {
      result(FlutterError(code: "INVALID_BOOKMARK", message: "Invalid bookmark data", details: nil))
      return
    }

    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      // 开始访问 security-scoped 资源
      if url.startAccessingSecurityScopedResource() {
        result(url.path)
      } else {
        result(FlutterError(code: "ACCESS_FAILED", message: "Failed to access security-scoped resource", details: nil))
      }
    } catch {
      result(FlutterError(code: "RESOLVE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func stopAccessing(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    url.stopAccessingSecurityScopedResource()
    result(nil)
  }
}

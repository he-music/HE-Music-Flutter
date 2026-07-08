import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 限制最小窗口尺寸（桌面断点 840 + 两侧 padding）
    self.minSize = NSSize(width: 880, height: 540)

    super.awakeFromNib()
  }
}

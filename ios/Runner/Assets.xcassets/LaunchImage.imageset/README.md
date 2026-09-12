# iOS 原生启动图

点击 App 后、Flutter 首帧之前的画面由 `ios/Runner/Base.lproj/LaunchScreen.storyboard` 显示，引用本目录的 `LaunchImage`，不会读取 Flutter 的 assets。

唯一源图是 `assets/icons/logo.png`。每次更换 Logo 后，在 macOS 的仓库根目录执行：

```sh
make ios-launch-logo
```

提交生成的三张 PNG：1x 为 168×168、2x 为 336×336、3x 为 504×504，均按 168pt 居中显示。此命令仅同步启动图；桌面 AppIcon 是单独的资源。

原生资源变更必须重新构建并安装 iOS App，hot reload / hot restart 无法更新系统启动画面。若新构建安装后仍显示旧图，可能是 iOS 保存了启动快照；先重启设备再冷启动验证。必要时在测试设备卸载后重新安装（会清除该 App 的本地数据）。
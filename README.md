# Happy Capy iOS 工程

这是一个不包含任何证书、私钥或密码的 WKWebView iOS 工程，入口地址固定为：

`https://hg.xxrmb.com:9443`

## 环境

- macOS
- Xcode 15 或更新版本
- iOS 15.0+
- 你自己的 Apple Developer 账号、P12 和对应 Mobile Provisioning Profile

## 使用方式

1. 在 Xcode 中打开 `HappyCapy.xcodeproj`。
2. 进入 Target `HappyCapy` → `Signing & Capabilities`。
3. 修改 `Team`。
4. 将 Bundle Identifier 改成你证书对应的 ID；默认是 `com.xxrmb.hg`。
5. 选择你的签名证书和 provisioning profile。
6. 连接 iPhone 或选择 Generic iOS Device。
7. Product → Archive。
8. Organizer → Distribute App → Ad Hoc / Development，导出 IPA。

也可以在 macOS 终端执行：

```bash
./build_unsigned.sh
```

该脚本只生成未签名归档，不能直接安装到 iPhone。正式安装请在 Xcode 里选择你的签名方式导出。

## 功能

- WKWebView 加载 Happy Capy
- HLS/网页全屏播放支持
- 横竖屏支持
- 下拉刷新和网页返回手势
- 加载进度条
- 网络失败重试页
- Safari 网页打开的新窗口回收到当前 WebView
- 网站 Cookie 和播放记录使用 WKWebView 默认持久化存储

## 说明

该工程是网页客户端外壳，不包含媒体内容和后端。网页更新会直接在服务器端生效，不需要重新发布 IPA。

不建议提交 App Store：当前网页包含外部视频来源和成人内容入口，更适合个人设备、Development、Ad Hoc 或侧载安装。

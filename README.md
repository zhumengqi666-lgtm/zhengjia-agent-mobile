# 正价智能体移动端

Capacitor 原生壳，Android 与 iOS 共用线上 AI 小梦业务页面。

- 应用标识：`com.tongai.pricing.agent`
- 原生入口：`http://8.148.64.167/agent?mobileApp=1`
- Android：固定发布签名 APK，系统下载目录接收生成文件
- iOS：GitHub macOS/Xcode 构建，无证书 Ad Hoc 签名，供 TrollStore 安装
- App 模式锁定页面缩放，浏览器访问不受影响

当前线上地址仍使用 HTTP。在域名和 HTTPS 配置完成前，登录信息不具备传输层加密保护。

- Android：Capacitor 原生 WebView，APK 由 `android/app` 构建。
- iOS：Capacitor WKWebView，使用无证书 Xcode 构建后进行 Ad Hoc 签名，供 TrollStore 安装。
- 服务入口：`http://8.148.64.167/agent?mobileApp=1`
- 应用标识：`com.tongai.pricing.agent`

App 专用 User-Agent 为 `TongAiAgentApp/1.0`。服务端据此启用安全区适配、禁止页面缩放并保持移动端布局。

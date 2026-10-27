# 2026-10-27 Android 1.0.6（1150）正式构建

## 授权、基线和边界

- 用户在鸿蒙1150交付后要求“安卓的也打正式版”。本轮仅正式重编APK、核验产物并提交构建记录；不安装手机、不修改业务/后端/服务配置、不上传商店或切换线上下载。
- 已检查status/remote并通过显式tangwu88 HTTPS身份、OpenSSL执行`git fetch origin --prune`；起始工作树干净，当前开发分支本地与远端均`8f35be00dffac336420e4c93d46f000f0c2cfd62`，ahead/behind为0/0，无需合并。不混用其它账号，不推广main。
- `git diff 702fea8..HEAD --name-only -- lib android assets pubspec.yaml pubspec.lock third_party`为空：Android运行源码与上一轮1149完全一致。只通过已有正式构建脚本参数将本次版本设置为1.0.6、构建号1150，不修改Flutter/iOS/鸿蒙业务源码或公共pubspec版本。
- 沿用上一轮同源代码已完成的Analyzer零问题、UTC/Asia-Shanghai各1504项测试、Android Debug及正式1149实测记录。本次不为未变化的源码重复测试，也不将上轮结果冒写为本轮新执行；iOS没有本机Xcode可供构建。

## 构建与验证

- 复用上一轮正式构建/门禁runner，仅在仓库外派生`E:\SayRing-market-artifacts-20261027\android-1150\Build-Formal.ps1`。沿用受保护的原正式P12、DPAPI密码和固定生产配置；不打印密码、不提交密钥或产物、不启用诊断拦截。
- Android双ARM Release构建395.9秒通过。正式证书SHA256仍为`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，apksigner验签通过；实际包名cn.saydian.ring、versionName1.0.6、versionCode1150、无debuggable，生产Manifest/JPush/双ARM ABI及ZIP对齐门禁通过。临时android/key.properties已清除。
- ABI门禁使用上一轮同源代码/相同pubspec.lock及原生配置的releaseRuntimeClasspath报告，复制前后SHA256均`6bfdbA591024b9b3d59b7e77825738db9aa6c21d1bf7578c7b84a90cbe9fdc29`（不区分大小写）。这是复用已有依赖证据，不记作本轮重跑Gradle依赖或原生单测；对本次实际APK重新执行签名/Manifest/ABI/ELF检查。
- 正式APK：`E:\SayRing-market-artifacts-20261027\android-1150\SayRing-1.0.6-1150-release.apk`，72030719字节，SHA256 `e95b6e59c3fe9140fa4bcd9c26fcef43e0308809aa5395bcbd60dacd07e8ceb2`。签名、构建与市场审核是独立结论；未上传商店、切换下载或手机安装。
- 既有32位供应商libDspConfig.so/libEcgAnaly.so的16KB对齐限制仍保留，不能因重打版本声称已修复；支付到账/原始相机行为/厂商同步与热量等旧实物未验收项没有在此次打包中处理。
- 收尾首次重新fetch因GitHub连接重置失败（curl56/expected flush），未执行后续暂存或提交，保留工作区和已冻结APK；改以HTTP/1.1仅重新获取当前开发分支后再核对，不能将网络失败写成同步成功。
- HTTP/1.1直连重试仍443连接失败；已有本机代理路径重试也出现TLS unexpected EOF。停止网络重试，仅本地提交这两份构建记录，暂未推送。Android运行源码仍是本轮开始时已核对远端一致的8f35be0，不因构建记录未推送而改变冻结APK；后续网络恢复再核对远端并推送，不强推。

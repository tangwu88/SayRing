# Say Ring Android QA APK 打包记录

## 范围与基线

- 时间：2026-09-24（UTC+08:00）。
- 分支：`codex/rebuild-from-handoff`；APK 源码提交：`452ab89fe06587a6bc7ce3b1c75a9c7ee768b7b4`。
- 打包前工作树干净，本地分支相对缓存远端领先 7、落后 0。
- `git fetch origin --prune` 因 `Recv failure: Connection was reset` 失败；本次只能按当前已验证的本地提交打包，不能声称包含未获取的远端更新。
- 用户要求打包 App；当前 Windows 环境生成 Android 可安装 QA Release APK，不生成 iOS IPA。

## 打包与验证

- 命令：设置项目固定的 JDK 17、Android SDK、Flutter 与 Pub Cache，设置 `SAIDIAN_ALLOW_QA_RELEASE=true`，执行 `flutter build apk --release --no-pub`。
- 结果：`assembleRelease` 成功；仅出现既有第三方插件 Kotlin 内置迁移预告，无构建错误。
- 交付文件：`build/deliverables/SayRing-Android-QA-v0.1.21+1004-20260924.apk`。
- 文件大小：69,332,256 字节。
- SHA-256：`AFE554836CD237D59FA7DA229508E97062DA7971808A923E11EF99378D105748`。
- 包名：`cn.saydian.ring`；应用名：`Say Ring`；版本：`0.1.21 (1004)`。
- minSdk 26，targetSdk 36；ABI 为 `arm64-v8a`、`armeabi-v7a`。
- `zipalign -c 4`：通过。
- `apksigner verify --verbose --print-certs`：通过 APK Signature Scheme v2；证书 SHA-256 为 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`。

## 发布边界

- 该包由项目 QA Debug 证书签名，只用于测试、安装与验收，不是应用商店生产包。
- 打包当时没有提升版本号、安装到手机、推送 Git、上传文件服务器或部署线上；后续 Git 同步见下方追加记录。
- Windows 无 Xcode、CocoaPods 与 codesign，未构建或验证 iOS IPA。

## 2026-09-27 Git 同步

- 用户要求把当前最新代码同步到线上 Git，并将“后续每次完成改动后同步 GitHub”设为项目交付规则。
- 同步前 `git fetch origin --prune` 成功；`origin/codex/rebuild-from-handoff` 落后本地 8 个提交，`origin/main` 落后本地 17 个提交，两者均无仅远端提交。
- 先以普通快进推送开发分支，再以普通快进更新 `main` 到 `134d519a8944967dbb5b5e5187e2f68c093566e2`；未使用强推，未改写远端历史。
- 本段规则与同步记录将作为后续独立文档提交再次推送，最终远端 SHA 以该提交和推送后验证为准。

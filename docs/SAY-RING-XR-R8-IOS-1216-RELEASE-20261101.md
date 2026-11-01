# XR / R8 真机回归与 iOS 1.0.9（1216）发布

2026-11-01。范围是 Say Ring `cn.saydian.ring`、iPhone XR 上原绑定 R8、当前集成分支 `codex/integrate-latest-20261031`。运行源码基线 `d4702187f35848503142b736ea8a9413630f3be2`；新增的 `ios_qring_r8_device_smoke_test.dart` 只作 QA 入口，不进入正常 `lib/main.dart` 构建。启动时先核对干净分支、远端和原 1209/R8 记录；未更换账号、解绑、清空历史或恢复出厂。真机完整容器在 Git 外私有备份。

## 真机验收

- XR UDID 仅在私有日志中保留；构建用团队 `W7SXQ4A226` 开发签名和原包名原位覆盖。第一次 `flutter build ios --config-only --profile --no-pub` 受本机 Xcode `-list` 进程退出 `-9` 中断，未安装残缺产物；不改源码重试成功。页面巡检 QA 1.0.8（1215）经严格深度验签、IPA 完整性检查后，用 `tool/drive_ios_preserving_data.mjs --profile --no-pub --keep-app-running` 保留数据运行，驱动退出 0、`All tests passed`。
- 原 R8 精确绑定与真实 QRing 握手、能力 ready、电量回包、后台同步结束均有运行回执；账号未变。共进入 27 个当前可用页面/流程；11 项依当前真实能力或发布门禁隐藏，未伪装成通过。
- 新增只读设备专项：相机和手势入口可用；手势设置真实读取非空；相机 `CameraPreview` 实际初始化，戒指遥控 Photo UI 启动取得成功 ACK。查找戒指、监测入口可用。未让用户实物晃动、未触发快门、未保存照片、未更改手势/监测设置；这些物理效果不能由 ACK 代替。
- 同一原绑定 R8 的三轮主动断开/页面重连全部通过新握手、新电量时间和相同账号/绑定检查；这仅证明主动重连，不代替先前自然断连、锁屏或远距离回归，也不证明无新睡眠样本的生理数据。
- 测试后以已独立验签的普通 `lib/main.dart` Profile 1.0.8（1215）原位覆盖并启动，设备安装清单回读正确。私有备份对照：安装前 Documents 52 个文件、完成后 53 个；原文件缺失 0，原文件内容未变 45、发生变化 7。存在真实运行写入，未将文件哈希变化误判为资料丢失，也没有直接声称各条健康记录逐条一致。

## 构建与门禁

- `flutter analyze --no-pub` 零问题；新增专项单文件分析零问题。`TZ=UTC flutter test --no-pub` 与 `TZ=Asia/Shanghai flutter test --no-pub` 各 1738 项通过；旧测试故意产生的异步异常日志不等于测试失败。
- Android Debug 构建通过。普通 `flutter build apk --release --no-pub` 被项目“必须明确 Production/QA 发行模式”门禁挡下；改用 `SAIDIAN_ALLOW_QA_RELEASE=true` 后 QA Release 构建通过，没有安装或发布安卓包。
- iOS Debug 和 Profile 1.0.8（1215）真机 SDK 编译通过。Xcode 旧 DerivedData 仅经 `xcodebuild clean` 清理可重建产物，以免磁盘不足；已签名的普通版、归档、私有备份和失败日志均保留。
- 首次 Release 归档因本机没有 iOS Distribution 私钥失败；使用已有 Apple Development 身份生成供 Organizer 自动分发重签的归档。下一次被校验脚本拒绝缺少唯一空 `JPUSH_APP_KEY` 的 Dart 编译参数；显式加入生产第一方 URL 与空推送 Key 后，1.0.8（1215）正常主入口 Release 归档成功。正式导出 IPA 深度验签通过：`cn.saydian.ring`、1.0.8（1215）、仅 iPhone、团队一致、`get-task-allow=false`、生产 APS，IPA SHA-256 `cd93189badf8272f4d9dffba20c5fd1bebfdda123433bf0bd25ac5560f3e0605`。
- 1215 的苹果上传返回 90186/90062：App Store Connect 已批准 1.0.8，版本通道关闭，必须使用高于 1.0.8 的版本；这次上传失败不算 TestFlight/送审。随即以相同运行源码、普通主入口、相同第一方配置增至 1.0.9（1216），Release 归档成功，核对团队、包名、主入口、无 QA 定义和严格深度签名。归档位于本机 Xcode Archives `2026-11-01/SayRing-1.0.9-1216.xcarchive`；开发签名归档本身仍不等于 App Store 分发 IPA。

## 苹果发布状态

1216 通过 `xcodebuild -exportArchive` 的 App Store Connect 自动签名和直接上传，命令退出 0，原始 ContentDelivery 明确 `UPLOAD SUCCEEDED with no errors`。第三方预编译 SDK 有缺失 dSYM 警告，不是二进制上传错误。苹果后台正确 Say Ring 的 TestFlight 页面已出现 1.0.9（1216），完成处理后状态为“准备提交”。出口合规如实申报为使用苹果系统以外的标准加密，且这次版本不向法国分发；未修改原有地区范围。

在 Say Ring App ID `6816549943` 创建 App Store 版本 1.0.9，选择并保存构建 1216，更新“此版本的新增内容”和审核备注，未改审核员账号资料。2026-11-01 13:29（后台所示时间）点击最终“提交以供审核”后，成功提示“已提交 1 个项目”；复查“iOS 提交”页，`iOS App 1.0.9`、`1.0.9 (1216)` 的状态均为“等待审核”，提交 ID 为 `55bf6dbd-8e93-4373-988a-656ffd55b750`。因此已提交审核，尚非审核通过或上架。原始 Xcode 分发日志存于忽略的 `build/ios-xr-r8-1215-20261101`。无新法律协议接受。缺少长时间自然断连/锁屏、实物手势快门和新睡眠样本的验收，后续必须保留为待验。

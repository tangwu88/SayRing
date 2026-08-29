# 正式发布阻断清单

## 当前结论

截至 2026-08-29，正式发布资源尚未配置，不应发布生产包或生产更新清单，也不得把当前状态写成“正式上线通过”。

客户端和本地门禁当前证据为：Flutter 双时区各 326/326、发布 Python 18/18、Android 原生 5/5；iOS RunnerTests 同日较早批次 18/18，但最终工作区重跑被 XCTest 框架签名阻断，18 项未执行。Android QA Release 覆盖安装后历史健康数据恢复，W9S 的真实 MAC 格式、电量 `100%`、161 款表盘目录和缩略图可见，且未发现崩溃。上述证据只说明客户端与 QA 构建链可用，不能替代生产凭据、服务端接口、正式签名、公开更新源和商店验收。

Android 现场补充证明：MED 可扫描连接 ET488、W9S、W8；ET488 目录 215 款，W9S 目录 161 款且 `dialShape=58`，W8 只读 5 个已安装表盘且无虚假预览，最终代码读取 W8 电量 `85%`。真实成员 HRV、关于页回退和 W8 相机禁用/恢复均完成真机复测。Android JPush SDK 注册和 TCP 连接成功、控制台包名匹配，但控制台集成度仍为 `--`，这只证明传输层，不解除服务端接口和业务通知阻断。

最终 Android APK 已使用本地锁定的 `jpush_flutter 3.5.1` 移除上游 `setup` 参数日志；真机日志未出现 AppKey 精确值或 Registration ID 形态。`onConnected=true` 后设备登记仍进入 `retryScheduled / server_rejected`，因此服务器阻断结论不变。

iPhone 12 较早批次可用：签名 Debug 三次独立启动存活且无新增崩溃日志，Xcode 连接 `SD-Watch-W9` 并读取电量 `98%`。签名 Profile 因当前 Provisioning Profile 缺少 APNs entitlement 被阻断，极光控制台也没有与 Bundle 匹配的 APNs 证书配置；后续开发证书重新信任又阻断 UI 补充取证。UI integration 最终为 `No tests ran`，不计为通过。iPhone 15 Pro Max 收尾时已连接，旧版 `0.1.19 (23)` 启动稳定 30 秒，但最终包因 Xcode `No Accounts` 且 Profile 不包含该设备而安装失败；第二台 JAD Android 仍被物理 PIN 锁定。两台设备均未完成最终代码回归。

本轮早期已通过 GitHub CLI 只读检查确认：

- `saydian88-cmyk/saydianapp` 为 **PRIVATE** 仓库，私有 Release APK 不是公网更新源。
- 仓库当前为 `0 Environments / 0 Actions Variables / 0 Actions Secrets`。
- 因此受保护的 `production` 和 `ios-adhoc` Environment 均未建立，相关工作流当前只能保持阻断。

最终提交前 GitHub CLI 的既有令牌已失效，因此上述远端资源状态未能再次实时复核；解除阻断时必须重新登录后复查，不能把早期快照当作当前生产配置证明。

## 必须由负责人提供

- [ ] 创建受保护的 GitHub `production` Environment 和发布审批人。
- [ ] 创建受保护的 GitHub `ios-adhoc` Environment；P12、密码、Provisioning Profile 和 JPush AppKey 只能配置在该 Environment。
- [ ] 提供同时覆盖 App 标识与 APNs entitlement 的 iOS Provisioning Profile；当前签名 Profile 因该能力缺失无法完成真机验收。
- [ ] 提供长期稳定的 Android 正式 keystore、alias、密码和独立核对的证书 SHA-256。
- [ ] 确认线上已安装版本的证书是否与该正式证书一致；不一致时无法直接覆盖升级。
- [ ] 将包名 `cc.saidian.app` 对应的生产 JPush 配置注入受保护 Environment；现场调试配置不得作为 CI 生产凭据，也不得写入仓库或交接文档。
- [ ] 在极光后台完成 iOS APNs 证书或 Token 配置，以及服务端发送凭据配置；不得把 Master Secret 提交到 App 或 Git。
- [ ] 在极光控制台建立与 `cc.saidian.app` Bundle 匹配的 APNs 配置；当前控制台没有匹配项。
- [ ] 完成极光 HarmonyOS 应用包名、Server Key/JSON 配置；当前 HarmonyOS 页面仍为空，不能计入鸿蒙推送覆盖。
- [ ] 明确量产首发需要的 Android 厂商通道；选中的 Huawei、Xiaomi、Oppo、Vivo、Honor 等通道必须提供完整凭据。
- [ ] 提供可无鉴权 HTTPS 下载 APK 和 JSON 的公网域名。
- [ ] 提供发布目录、最小权限 SSH 账号、私钥和经核对的 known_hosts。
- [ ] 配置 Web/CDN 对 APK 的大文件下载、HTTPS 证书及清单短缓存。
- [ ] 明确首次 `minimum_supported_build`，这是产品强制升级政策，不由 CI 自行猜测。
- [ ] 提供用户可见的版本发布说明。
- [ ] 将 `pubspec.yaml` 的 versionName 和 build 都递增，并创建匹配的 annotated tag。

## Android ABI 受控例外与待确认风险

当前 `jpush_flutter 3.5.1` 引入 JPush Android 6.2.0，并解析到 JCore 5.5.2。
JCore 5.5.2 的 Maven AAR 只包含 `arm64-v8a/libjutils.so`，没有对应的
`armeabi-v7a/libjutils.so`；5.5.0、5.5.1 也具有同样结构。

[极光 Android SDK 版本说明](https://docs.jiguang.cn/jpush/jpush_changelog/updates_Android)
要求 JPush 6.2.0 配合 JCore 5.5.0 及以上使用，不能为了凑齐
ABI 将 JCore 降级到不满足要求的版本。

发布门禁只接受一个精确受控例外：`libjutils.so` 可仅存在于 `arm64-v8a`，
但必须同时从 `pubspec.lock` 和 Gradle Release 依赖报告确认组合严格为
`jpush_flutter 3.5.1 + JPush 6.2.0 + JCore 5.5.2`。版本发生任何变化、
出现其他单架构库或额外 ABI 时仍失败关闭。

- [ ] 向极光确认 `libjutils.so` 为明确、可记录的单架构可选库，并取得 32 位运行保证；或由极光提供包含 `armeabi-v7a` 的兼容 AAR。
- [ ] 在 MED AL00 或同等 32 位进程环境完成推送注册、前后台通知和冷启动点击测试。
- [ ] 厂商依赖升级时重新审计 AAR；不得把例外扩展到其他库，也不得删除 arm64 库伪造对称。

## 服务端推送接口阻断

下列接口和事件链路尚未提供生产可验证结果：

- [ ] `POST /api/v1/member/push-devices`：登记 installation ID、极光 registration ID、平台、版本和构建号。
- [ ] `DELETE /api/v1/member/push-devices/{installation_id}`：退出登录或安装失效时解绑。
- [ ] `GET /api/v1/member/notify/unread-count`：读取服务端未读数。
- [ ] `POST /api/v1/member/notify/{id}/read`：确认消息已读。
- [ ] 关爱邀请创建返回稳定 `invitation_id`，同一事务写通知 Outbox 并触发极光/APNs 推送。

2026-08-29 只读请求确认：推送设备登记/解绑、未读数和已读路由均返回业务 `code:404`，尚未部署。现有 `/api/v1/member/notify` 在未授权访问时返回业务 `code:500` 并暴露 Yii 文件路径/堆栈；服务端需改为统一 401/403 错误并关闭生产堆栈输出。

Android JPush SDK 注册和 TCP 已连通，控制台包名匹配；没有执行或记录任何敏感凭据。该结果不能替代下列业务闭环：登录账号登记 installation、邀请/预警 Outbox、目标账号推送、点击后回源、已读同步和退出解绑。

在接口、极光/APNs 和双账号生产网络验证完成前，“关爱邀请及健康预警 10 秒内到达”不能验收。前台轮询和应用内红点不能替代后台即时推送结论。

客户端已有账号隔离、通知事件去重、未登录续跳和前台轮询兜底，但这些能力不生成服务端 Outbox，也不能替代极光/APNs 实际投递。

## iOS 商店依赖

Android 工作流在生成新清单时会保留线上已有的 iOS 条目。

如果首次发布时还没有 App Store 产品页，清单可先只含 Android。不得填写虚假 App Store ID；实际 iOS 上线前必须补齐并验证 `apps.apple.com` 正式地址。

当前尚无 App Store 产品页、公开生产清单或生产下载地址。2026-08-29 现场请求 `https://app.saidian.cc/app-update.json` 返回 HTTP 404；Apple 公开查询中包名 `cc.saidian.app` 在中国、美国、香港区均无产品结果。因此 iOS App Store 跳转、Android 正式 APK 下载/SHA-256/系统安装器以及旧包覆盖升级均未完成线上认证。

客户端已统一使用应用根级更新 Gate，并限制清单与 APK 为同源 HTTPS 重定向；这些安全修复不解除公开清单、正式签名和 App Store 产品页阻断。

## 解除阻断后的验收

- [ ] 正式证书指纹在 keystore、APK 和已安装量产包三处一致。
- [ ] APK 只含 `armeabi-v7a` 和 `arm64-v8a`；除上述精确锁版本的 `libjutils.so` 外，每个 `.so` 在两个 ABI 下对称。
- [ ] APK Manifest 不含后台定位、读取电话状态或查询全部应用权限。
- [ ] APK Manifest 中包名、JPush AppKey/channel 和已启用厂商占位符与生产配置一致。
- [ ] 使用无登录的普通网络可下载 APK，并与清单 SHA-256 一致。
- [ ] 清单更新前 APK 已可用；发布失败不会留下指向不完整 APK 的新清单。
- [ ] 已安装旧正式版可检测新版、下载、校验并调起系统安装器。
- [ ] iOS 使用真实生产清单打开正式 `apps.apple.com` 产品页，不下载或安装 IPA。
- [ ] 双账号分别在前台、后台和进程终止状态测试关爱邀请，正常网络下系统通知在 10 秒内到达并直达待处理页面。

# Say Ring 1060 / 1061 拒审整改与重新送审

## 范围与基线

- 用户要求按右侧苹果审核意见重新上传新构建、说明并提交审核；仅 Say Ring / 6816549943 / cn.saydian.ring。
- 干净分支 codex/macos-update-20260930，基线 bdfcf5117b16124e80fc50bb252abc6bf118119e；fetch 与 ff-only pull 已最新。
- 最新 Apple 消息：2026-10-04，2.1(a)，审核账号登录报错；设备 iPad Air 11-inch (M3) / iPadOS 27.0。附件显示旧的邮箱验证码表单，密码被输入验证码框。
- 本轮开始时，可供审核版本 1.0 已选择 1059，但审核备注仍写 1016。不能将构建替换当作已重新提交，也不能将旧截图当作新包问题复现。

## 本轮处理

- 使用已完成全量回归的 1060 源码；邮箱默认密码登录、真实本机免登录入口已在此前实现，不为了本轮伪造新的业务修复。
- 增加独立真机审核登录用例：真实生产 API、真实页面、内存账号与健康存储、禁用自动连接；不替换手机原账号、不发送验证码、不创建账号或改健康数据。
- 审核测试凭据仅通过私有构建参数注入测试目标；正式包必须使用 lib/main.dart，不包含凭据或测试入口。
- 核对首次进入、邮箱密码字段、登录和资料读取，正常主程序原位恢复；仅 iPhone 包身份保持不变，不宣称已在 Apple 的 iPadOS 27 硬件复测。
- 串行构建正式 1.0.0 (1060)，重新填写匹配新构建的审核说明并回复准确整改事实，再执行重新提交。

## 实际检查记录

- 初始 App Store Connect 回读：1059 为 VALID，1060 尚未上传；提交 e7a16e4d-18b9-457b-a59c-1d8e4711c702 为问题未解决。
- 生产 say-ring 能力返回正确产品及已发布专属协议；邮箱验证码关闭，不影响邮箱密码接口。API 测试仅使用用户已提供的审核账号，不在 Git 写入凭据。
- 第一次接口探测返回 HTTP 201 / code=200 / 有效会话；脚本错误只接受 200，未执行资料读取和测试会话退出。这次会话未冒充完整测试通过。
- 修正成功状态为所有 2xx 后：登录 HTTP 201 / code=200，members/me HTTP 200 / code=200，测试会话退出 HTTP 201 / code=200。仅输出布尔值及状态，不输出令牌、账号资料或健康数据。
- 设备只读预检：iPhone 15 Pro Max / iOS 26.6，已解锁；现装 1055。安装、实际用例、归档上传和提交结果在执行后追加。
- 本轮静态分析无问题；完整 Flutter 测试 UTC 与 Asia/Shanghai 各 1197 项通过。发布脚本 33 项、保留设备数据驱动及包体测量 Node 测试 5 项通过。
- 新审核登录测试目标的开发签名 Profile 构建通过，严格签名校验通过；启动前已对既有 App 的 Library / Documents 做仅本机私有备份。随后 iPhone 15 Pro Max 变为 unavailable，驱动报告没有匹配设备，测试尚未执行、未安装测试目标；未卸载或替换原有账号。
- 正式包重新生成：归档 105.3 秒、导出 10.6 秒；1.0.0 / 1060 / cn.saydian.ring / UIDeviceFamily=[1]。归档和最终 IPA 解包 App 严格签名校验通过，App Store 分发描述文件 get-task-allow=false / beta-reports-active=true，无设备列表。
- 正式 Generated.xcconfig 为 lib/main.dart、生产 API、既有空 JPUSH_APP_KEY；不含 SAYRING_QA_ 测试凭据。IPA 40,838,584 字节，SHA-256 `4f8727f5ca8d919b9f07a48417ba40bef844a2628674932d6c6cd672e7717a66`，产物仅保存在忽略目录。
- 2026-10-05 11:22:50 本机 CST，苹果 altool 返回 VERIFY SUCCEEDED / 0 errors / 1 warning。90068 是 2027 年 4 月最低 iOS 15 的未来要求，目前 iOS 13 包未因此拒绝。
- 核对 App Store 隐私页发现旧的“未收集数据”和通用政策 URL，与现有账号、云端摘要及头像功能不符。本轮按实际链路修正披露，并请求既有服务端任务更新 Say Ring 专属公开政策页；不修改其他 App 或扩大上传授权。
- 2026-10-05 11:25:44 CST，altool 返回 UPLOAD SUCCEEDED / 0 errors / 1 warning；收据 `54aa6ce3-9db0-4996-abb4-141bdad591ce`，实际传输 40,838,584 字节 / 2.331 秒。随后 API 尚无可用 Build 实体，只表示后台处理尚未完成，未重复上传。
- ASC 审核说明已使用 [1060 英文审核备注](APP-REVIEW-NOTES-1060.txt) 替换 1016 旧说明，既有审核凭据保持不变；回复当前先保存草稿，待新包绑定后才发送。
- 最终完成 13 项数据披露：姓名、邮箱、电话、健康、健身、联系人（关爱关系，不代表读通讯录）、头像照片、客服、用户标识、设备标识、产品交互（连接记录）、必要诊断、其他资料。用途为 App 功能，健康/健身另含个性化建议，关联用户但不用于广告追踪。披露不代表增加采集范围。
- ASC 保存产品交互披露曾出现 Apple 通用保存错误；移除该未完成草稿后按相同真实选项重新添加、发布，最终没有未设置提醒。
- 简体中文描述补齐真实免登录入口、邮箱密码、HRV 和单独授权的睡眠 AI 边界；客服 URL 改为用户已确认的企业微信客服，HTTP 200。未删除或修改旧截屏与既有视频。
- 地图实现会在服务已配置时转发轨迹点至高德；进一步核查实时 sport-map-config 为 configured=false，当前不会进入高德请求，自身实时处理/no-store，未核实有坐标长期留存。按 Apple 的收集定义撤回临时精确位置标签，不能把未开启链路当作当前收集；后续启用前仍需核对第三方和日志留存及更新披露。服务端地图开关未变。
- 最初实时 app-display 为 hideAi=false / sleepAiEnabled=true，普通 AI 咨询文本曾按真实入口补充披露；进一步核对单独授权缺口后，按用户已授权的审核安全简化处理，产品级 hideAi=true / sleepAiEnabled=true。通用 AI 入口对所有 Say Ring 用户持续隐藏，睡眠分析保留独立授权；据此撤回通用自由文本内容标签，不将睡眠汇总授权当作任意咨询授权。
- 隐藏并不等于服务端 AI 接口按产品硬隔离：共享接口没有可信产品标识，本轮不伪称其已拒绝所有 Say Ring 来源的手工请求，不改变其他 App 的服务。恢复通用 AI 须另行完善披露和单独同意，不能仅在审核期间隐藏。
- 隐藏设置在生产 API 独立回读确认；App 显示配置与睡眠报告定向回归 28 项通过，包含睡眠开关独立、授权撤回、迟到响应与账号切换。属于自动化回归，不冒充实体 iPhone 的新一轮测试。
- App Availability API 回读 175 个地区，仅 CHN 为 available=true，availableInNewTerritories=false；没有擅自扩大地区。既有 Google Drive 演示视频页面显示“知道链接的任何人都可以使用，无需登录”，未更改文件或分享权限。
- 苹果 Build 实体已处理为 VALID：`54aa6ce3-9db0-4996-abb4-141bdad591ce` / 1060。按此前用户已确认、与 1059 未改变的加密和中国大陆销售范围补齐 usesNonExemptEncryption=false；未增加算法或法国分发。
- App Store 1.0 的 build 关系已切换至该 1060，API 回读版本、VALID 与加密字段一致。此步骤仅为选包，尚不能表示最终重新提交。
- 专属公开政策页仍是旧本机模式说明，与现有登录和云端功能不符；合作服务端任务已推送 60178a2，验证作业成功，生产部署自 11:37 CST 开始，当前仍在原始 GHCR 镜像拉取阶段。线上 readiness 仍为 a9a884a6b74eaf5a3a60d82f4214ef7452f60f92，因此保留回复草稿，不将代码推送或 CI 验证当作公开页面已更新。
- 追加代码检查发现：既有显示配置有意保留最近成功值，旧 hideAi=false 缓存遇刷新故障仍可能开放通用 AI。为避免把远程隐藏开关当作绝对关闭，本次追加生产构建级 `SAY_RING_GENERAL_AI_ENABLED=false` 上限。旧缓存、远程 false 与刷新故障均不能越过该上限；睡眠 AI 独立授权与开关不变。新增两项回归后定向 30 项通过，最终构建因此递增为 1061；1060 保留为真实上传记录，不冒充新源码的产物。
- 1061 静态分析无问题；完整 Flutter UTC / Asia/Shanghai 各 1199 项通过。生产默认关闭、缓存故障与远程 false 上限、独立睡眠开关均有自动化断言；未将其冒充新一轮实体手机测试。
- 1061 正式归档 61.9 秒、导出 8.3 秒；`cn.saydian.ring` / 1.0.0 / 1061 / UIDeviceFamily=[1]。归档与 IPA 解包 App 严格签名通过；分发描述文件 get-task-allow=false、beta-reports-active=true，无设备列表或企业全设备字段。
- 1061 正式参数为 lib/main.dart、生产 API、通用 AI 编译开关 false、既有空推送 Key；无 SAYRING_QA_ 参数。最终 IPA 40,709,399 字节，SHA-256 `b883625a71580ea16773bb298df4f3d71c32c5abb78dc8ea944849ca60869b2a`，仅存于忽略目录。
- 1061 altool 验证退出码 0，JSON 回执为 “No errors, 1 warnings”；唯一警告 90068 是 2027 年 4 月起最低 iOS 15 的未来要求。本轮没有因该警告拒绝验证。Flutter 的旧 LaunchImage 占位检查仍有告警，实际 LaunchScreen 源码引用 SaydianLaunchLogo；不据源码声称冷启动真机已验收。

## 最终线上与送审回执

- 1061 上传退出码 0，JSON 回执为 “No errors, 1 warnings, uploading archive”；交付 ID `c025db68-e705-4e5a-9147-742cefe6f70f`，实际传输 40,709,399 字节 / 4.887 秒。随后 ASC Build 处理为 VALID，uploadedDate 为 2026-10-05 12:30:22 CST；未将短暂空的 Build 列表当作失败并重复上传。
- 当前 App Store 1.0 已选择 1.0.0 (1061)，Build ID 与交付回执一致，usesNonExemptEncryption=false 沿用用户已确认且未改变的加密范围。审核备注已使用 [1061 英文说明](APP-REVIEW-NOTES-1061.txt)，API 回读备注全文一致、既有审核账号与密码一致，仅输出核对布尔值，不写入凭据。
- 服务端发布 60178a23a5bfa4ae5f685abc90141967c8492e4e 的 verify、resolve、deploy 均最终成功。`/health/ready` 与 `/global/health/ready` 实际回读新 SHA、ready / database=ok，不再是旧 a9a884a 版本。
- 浏览器实际核验 `https://app.saydian.cn/say-ring/privacy`：显示正式 say-ring-cn-2026-10-02-v2、处理者 Xuewu Tang、kf@saydian.com、账号与游客模式、云端记录和独立睡眠分析说明；不再显示旧“本版本没有账号云端”的本机模式政策。未启用未审核的新草稿，其他产品页面和下载清单由服务端 10 项快照确认未变。
- 部署后生产审核账号再次实测：密码登录 HTTP 201 / code=200、members/me HTTP 200 / code=200、仅本次测试会话退出 HTTP 201 / code=200。公开 app-display 仍为 hideAi=true / sleepAiEnabled=true；验证码能力字段仍关闭，不代表密码接口关闭，客户端密码入口与该字段独立，并有对应页面回归。
- 2026-10-05 12:36 CST，英文整改回复实际发送，页面消息数由 4 增至 5，草稿控件消失；随后点击“重新提交至 App 审核”一次。
- 最终 API 与页面均为 **WAITING_FOR_REVIEW / 等待审核**，提交 ID `e7a16e4d-18b9-457b-a59c-1d8e4711c702`，submittedDate `2026-10-05T04:36:21.845Z`（12:36:21.845 CST）。版本 releaseType=AFTER_APPROVAL 保持不变，仅中国大陆销售范围不变；这不是审核已批准或已公开上架。
- 实际截图位于本机忽略目录 `.build/1061-appstore-review-submitted.jpg`、`.build/1060-app-privacy-final.jpg`（同一应用级的已发布 13 项隐私披露回执）、`.build/1061-public-policy.jpg`；不将旧截图或测试画面当作新真机验收证据。
- 验证代码及说明已提交并推送：95ec7ab（隔离审核登录用例与 1060 记录）、5fd0766（1061 通用 AI 构建级上限和 1199 项回归）。最终送审回执另以文档提交保存；不修改原始 SDK、已有交接 ZIP、个人照片或手机数据。

## 后续真机用例复现

仅在指定 iPhone 15 Pro Max 可用时运行；测试会使用用户已授权的审核账号访问生产 API，不注册、不删号、不上传健康数据。正式发包不得使用此测试目标。

```sh
node tool/drive_ios_preserving_data.mjs --profile --no-pub \
  --use-application-binary=.build/review-1060-login-test/Runner.app \
  -d 00008130-001C098C2290001C \
  --driver=test_driver/ios_review_login.dart \
  --target=integration_test/ios_review_login_test.dart \
  --build-name=1.0.0 --build-number=1061 \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define-from-file=.build/review-1060-auth-defines-private.json
```

先备份 App 容器，并核验指定 Profile 测试包的签名、入口和版本。驱动强制保留 App，禁止直接使用会在清理阶段卸载 App 的默认 flutter drive。上方历史路径必须以本次实际核验的测试包为准。

私有参数文件包含 `SAYRING_QA_REVIEW_EMAIL`、`SAYRING_QA_REVIEW_PASSWORD` 及生产 API / 既有空推送配置，权限为 0600，始终处于 Git 忽略目录；不要将文件、测试包、账号资料或设备备份加入交接包。此命令在本轮未完成真机执行，待设备重新可用后才能记为通过。

## 验收边界

- 同源码 1060 的完整 Flutter 双时区、静态分析、Android 原生/构建及 iOS Debug/Profile 门禁见客户端整理记录；本轮未更改运行时代码。
- 新用例是实体 iPhone 的生产账号入口测试，不代表真实戒指三轮距离重连、所有厂商功能或 iPadOS 27 验收。
- 上传、处理有效、重新提交、审核通过和公开上架分别记录，不保证审核一次通过。

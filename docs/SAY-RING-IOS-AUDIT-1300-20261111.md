# iOS 客户端复查与 1300 内部测试

## 范围和基线

- 2026-11-11，Asia/Shanghai。用户要求再次检查苹果客户端、修复问题并交付 TestFlight 内部测试；本轮不替换正式审核或商店版本。
- 仓库 `tangwu88/SayRing`，分支 `codex/u19-ios-sync-20261111`。修改前 `bff4c48be051e7fd43cce0f1ade844c5d478cd5d`。开始时已 fetch，当前分支与远端一致、工作树干净。没有合并另一条 Android 工作分支或覆盖其他产品的 XR 调试会话。
- 已只读核对 App Store Connect：Say Ring / App ID `6816549943` / 团队 `W7SXQ4A226`，现有 1.0.13（1296）可分发，手动发布选项仍保留。此次使用新的 1.0.14（1300）内部测试构建。
- 本轮运行修改仅在 `lib/services/urion_wearable_bridge.dart`；回归在 `test/urion_wearable_bridge_session_test.dart`。没有调整原戒指路由、健康值、存储结构、账号或设备设置，没有校时、清空或恢复出厂操作。

## 已复现并修复

| 问题 | 复现和旧行为 | 修复及边界 | 等级 |
|---|---|---|---|
| 旧时段/未来时段被当作新测量 | 开始 U19 心率或血氧后，日索引中的历史或未来时段恰有一项变化，旧实现直接把它记成当前手动测量完成 | 记录查询所属的本地日期，限定时段与本次测量窗口相交；未来、已结束及倒序区间排除，继续要求唯一变化、启动确认和当前连接 | P1 |
| 跨午夜漏掉相同数值 | 午夜前取得基线，午夜后新一天同索引、同数值被昨天的基线当作重复；基线请求本身跨午夜也有同类风险 | 基线保存发起查询时的日期；只有同一天才比较基线。新一天的有效时段不与昨日混比 | P2 |
| 脉搏指数可打断另一项测量 | 血压、心率或血氧还在测量时，从独立脉搏入口启动，旧代码只检查另一轮脉搏，仍会发出读取和启动命令 | 脉搏启动复用现有三类传感器的互斥条件，冲突时不发送读取或启动；未确认手表结束时的防重复充气保护保留 | P1 |

修复没有把日索引升级为精确设备时间：现有手动结果仍是有界观察到的日索引变化，真实固件的完成通知、读数来源和测量精度仍需实体核对。一次启动应答不等于新结果。

## 其他重点复查

- iOS 原生 U19 连接：当前精确外设/连接代次、旧回调隔离、物理取消确认、通知和握手顺序及能力许可有效期。没有为消除等待而释放未完成的连接/测量屏障。
- 原戒指：R8/R8 Pro、R21/R22、R7/R7y/R7 Pro/R7 Ultra/HR05 路由保留；事件和详情异步返回必须匹配原目标。原生恢复的模拟/生产方法回放与实物稳定性分开记录。
- 云同步和账号：在途同步共用同一任务，换号后拒绝迟到页面，许可变化仅有界重读，上传确认不由本地完成状态代替。
- 网络及隐私：第一方请求限既有 HTTPS `/global` 范围，禁止跟随重定向携带凭据；令牌刷新使用原会话比较写回。网络审计不写令牌、查询、正文、原始健康值或会员标识。未引入关闭证书校验的代码。
- 测量超时：控制器有界结束页面等待；桥接仍可能保留“手表未确认结束”的再次启动屏障。这两者用途不同，不能把后者简单清空以允许重复充气。
- 本轮没有新复现账号越权或凭据泄漏；这是对上述路径的源码与自动回归检查，不是渗透测试或“全部无漏洞”保证。

## 验证记录

- 首批新增 9 个场景在旧运行代码上 37 通过、9 失败，原始日志 `red-session.log` 保留；修复后定向会话与协议 59 项通过。追加“基线请求跨午夜”后共 60 项通过。
- 修正两个旧正向用例的固定索引，按夹具本地时间选择真实当前采样时段；不能依赖错误时段来证明新结果可用。
- 初轮全量格式检查通过；静态分析因新增 `if` 缺少花括号报告一项风格问题并停止。已补齐，失败日志保留为 `attempt1-*`，没有删除或覆盖。
- `dart format --output=none --set-exit-if-changed lib test integration_test` 和 `flutter analyze --no-pub` 最终通过；`TZ=Asia/Shanghai` 及 `TZ=America/Los_Angeles flutter test --no-pub --reporter expanded` 各 2,347 项通过。
- Node 官方独立 22.14.0 执行 `node --test tool/measure_ios_bundle.test.mjs tool/drive_ios_preserving_data.test.mjs tool/test_urion_native_lifecycle.mjs tool/coolwear_ios_recovery_session.test.mjs tool/test_native_log_privacy.mjs`：33 项通过，含原生连接回放与日志隐私检查。宿主执行不是实体无线验收。
- 正常 `lib/main.dart` 的 iOS Debug/Profile 串行 `BUILD SUCCEEDED`；均验证 `cn.saydian.ring` / 1.0.14（1300）/ `W7SXQ4A226` 和深度签名。Profile 没有 Debug 内核或调试回包标记；原 Flutter 生成配置按字节恢复。
- iOS 命令采用 `flutter build ios --no-pub --debug/--profile --config-only --target=lib/main.dart --build-name=1.0.14 --build-number=1300` 和原生产参数；随后 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug/Profile -sdk iphoneos -destination generic/platform=iOS -jobs 4 build`。本机 SDK 27.2 使用显式部署目标 15.0，没有改仓库默认最低版本；不宣称默认旧系统目标已验收。配置阶段仅停止超时的本进程可选属性清理子进程，不能宣称全部属性未改。
- 共享代码 Android Debug/Release 构建均通过：`flutter build apk --debug/--release --no-pub --target=lib/main.dart --build-name=1.0.14 --build-number=1300 --target-platform=android-arm,android-arm64`，沿用原生产参数。`./gradlew --offline :app:testDebugUnitTest --no-daemon --max-workers=2`：134项，0失败/错误/跳过。
- Android Release 原发行签名、包名/版本、双ARM、清单与ZIP 16KB对齐检查通过，SHA-256 `dd7a1906a71983f08a9d79b37156378b7eb0db86a845c68c29e0eadabc3b722e`。既有供应商32位ELF对齐限制没有变化，ZIP门禁不代表市场验收。临时签名配置已移除，未安装或发布安卓包。
- 两端构建期间运行源码内容均保持一致。Release 归档、实际上传和内部组结果见下方独立记录；真机新测量与无线稳定性仍列为待验收。
- 忽略目录 `build/ios-audit-1300-20261111/` 保存日志、构建和私有辅助脚本；公开 Git 不包含签名私钥、密码、设备地址、会员信息或真实健康值。

## 归档与上传

- 修复源码提交 `d34913ee2f63e903cfb320eea883791c615c2edb` 已推送并 fetch 核对；本节之后仅追加交付记录，不修改运行代码。
- 正常 Release 的 1.0.14（1300）归档成功；包名 `cn.saydian.ring`、团队 `W7SXQ4A226`、arm64、AOT 和深度签名均已核对。Xcode Organizer 明确选中今天 14:45 的正确归档，经原团队账号完成发行签名和上传。
- Xcode 返回 `Uploaded to Apple`。15 个既有供应商框架缺少 dSYM 的警告未阻止上传，对应框架的崩溃符号化受限；没有凭此宣称供应商 SDK 已无缺陷。
- 实际上传 IPA 为 39,420,418 字节，SHA-256 `6f7a789547ecbcf383932f5ed8a21d75943a79b383fe86b76de3eb1a9f262b8b`。原 Apple Distribution 签名、商店描述文件、生产推送、禁止调试、无 Debug 内核核验通过；Runner 与 App.framework 的 UUID 分别与归档一致。
- Apple 上传列表在北京时间 14:51 显示 1.0.14（1300）正在处理，之后完成处理；最终内部组结果见下节。上传成功、内部可测试和实际手机更新分别记录。
- 上传后只读核对：正式分发仍是 1.0.13（1296）「可分发」，手动发布选项仍选中；174 个地区可供应，法国未供应。没有修改正式版本、地区或发布方式。
- 归档、实际 IPA、验证 JSON 和截图只保存在忽略的本机目录。浏览器两次控件等待早于页面加载/名称匹配而超时，随后读取实际页面继续；没有因此重复上传或改动其他应用。

## 内部测试交付

- 2026-11-11 北京时间 15:03，App Store Connect 的既有「Say Ring 真机验证」内部组明确显示 1.0.14（1300）「正在测试」，90 天后过期；组内仍为原有 4 名测试员，构建数由 20 增至 21，没有增加成员或分配到外部组。
- 本构建 ID：`96d5ee48-9a89-42d3-867a-c2b67b13089c`；[内部组构建列表](https://appstoreconnect.apple.com/teams/69a6de89-863e-47e3-e053-5b8c7c11a4d1/apps/6816549943/testflight/groups/d46bbf49-2fc9-44f6-a313-b018f88b37dc/builds)。已有权限且已接受邀请的成员可在 TestFlight 更新，本轮未代为安装到成员手机。
- 根据当前依赖和已核对地区，完成本构建出口合规：与操作系统加密同时使用的标准算法，法国不分发。没有修改现有销售地区或将 SQLCipher 误填为仅操作系统加密；也没有接受新法律协议。
- 简体中文和美国英文测试说明均已保存并在刷新后读回：说明三项修复、继承的血压历史补读，以及新结果/云端读回/持续连接的实物待验边界。Apple 去掉文末换行，正文一致。没有改动全局审核账号或资料。
- 合规选择后页面重新生成控件，旧保存索引出现一次 detached 错误；已重新读取实际表单后保存，没有重复操作其他版本。
- 截图保存在 `build/ios-audit-1300-20261111/testflight-internal-1300.png`；正式分发仍保留前述 1.0.13（1296）及手动发布状态，本轮未提交正式审核或改动商店版本。
- 源码提交仍为 `d34913ee2f63e903cfb320eea883791c615c2edb`；此次交付补录只改文档，没有重新编译或变更已上传二进制。

## 仍需真机验收

- 问题 iPhone 上 U19 新血压、心率、血氧：手表完成、App 取得唯一新值、本机保存、上传确认、独立云端读回分别确认。继承的血压历史漏读修复已包含，但此前实体 `0x14` 为空的问题不能用模拟非空回包判为已解决。
- 午夜、手动并发、通知迟到、掉线后恢复以及前台/锁屏持续连接仍需实际型号验证。本轮没有安装/清空手机或发起实际测量；XR 上正在运行其他产品的会话不作为 Say Ring 验收。
- 用户已授权内部测试交付，不等于要求正式上架。本轮只进入既有内部测试组，不修改正式分发版本、地区、协议或审核资料。

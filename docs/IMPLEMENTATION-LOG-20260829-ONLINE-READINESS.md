# 2026-08-29 通知、表盘、电量与在线升级上线整改记录

## 02:00 开工基线与影响范围

- 原因：补齐健康预警通知、关爱即时通知、双端表盘商城、iOS 电量读取和双端在线升级，并处理 UTC 关爱日期参数偏移。
- Git 基线：个人资料表单协议修复已独立提交为 `637358514247d682040a153fd2c70c33dac57182`；本地分支、远程同名分支与 `origin/main` 一致，工作树干净。
- 修改范围：通知收件箱与已读状态、关爱邀请刷新/路由/推送登记、Veepoo 表盘严格 profile、表盘目录与缩略图、电量桥接、更新清单与 Android 安装链路、相关测试和发布配置。
- 能力边界：Yucheng/W8 没有正式授权目录时不开放在线商城；iOS 生产更新只允许 App Store；没有极光、APNs、正式签名、公开清单或商店资源时只标记客户端就绪和外部阻断。
- 数据与隐私：锁屏预警不携带健康值；推送载荷不携带手机号、Token 或健康数据；不伪造通知投递、表盘安装或线上升级成功。
- 预期：客户端入口、状态、失败兜底和接口契约完整；自动化与双端构建通过；真机仅对实际完成的步骤标记通过。
- 结果：客户端实施与可用资源范围内的验证已完成；生产推送、正式签名和线上更新仍按本文阻断项停线，不得标记“正式上线通过”。

## 验证流水

### 发布脚本与工作流

- `python3 -m unittest discover -s scripts/release -p 'test_*.py' -v`：18/18 通过。
- `actionlint .github/workflows/*.yml`、`shellcheck scripts/release/*.sh`、`bash -n scripts/release/*.sh`：通过。
- Android 与 iOS 的普通 Release 默认拒绝构建；本地无签名验证必须显式设置 `SAIDIAN_ALLOW_QA_RELEASE=true`。
- 正式工作流必须显式设置 `SAIDIAN_PRODUCTION_RELEASE=true` 且 `SAIDIAN_ALLOW_QA_RELEASE=false`，并继续执行全部生产凭据、签名、域名和更新配置校验。
- GitHub Actions 已使用固定 commit SHA；Android 发布加入线上版本防回滚、旧清单 SHA-256 CAS、远端锁、HTTPS 重定向限制及失败恢复复核。
- Android Gradle Wrapper 已跟踪，Gradle 9.1.0 分发包 SHA-256 已锁定；干净 CI 不再依赖本机被忽略的 `gradlew`。
- 更新入口统一由应用根级 Gate 管理，启动检查和“关于我们”手动检查不能绕过最低构建限制；清单持久化失败时仍保持必要更新阻断。
- 更新清单与 APK 下载只接受同源 HTTPS 重定向；有效目标地址按最终响应地址复核，禁止借重定向绕过域名白名单。
- 只读资源审计：`saydian88-cmyk/saydianapp` 为私有仓库，GitHub 当前为 `0 Environments / 0 Variables / 0 Secrets`。

### 自动化与构建

- `flutter analyze`：零问题。
- `TZ=UTC flutter test` 与 `TZ=Asia/Shanghai flutter test`：各 326/326 通过。
- Android `:app:testDebugUnitTest --rerun-tasks`：5/5 通过；Debug、显式 QA Release APK 与 AAB 构建通过。
- iOS 无签名 Debug/Profile，以及设置 `SAIDIAN_ALLOW_QA_RELEASE=true` 后的 Release 构建通过。
- Android Release Manifest 已确认不含后台定位、读取电话状态和查询全部应用权限；安装 APK 所需权限按更新能力受控保留。
- Android 双 ABI 门禁通过；仅允许锁定的 `jpush_flutter 3.5.1 + JPush 6.2.0 + JCore 5.5.2` 组合下 `arm64-v8a/libjutils.so` 单架构例外，其他原生库仍必须双架构对称。
- 本地 Android QA Release 使用调试证书和禁用推送占位配置，只证明构建链可用，不是生产签名或生产推送验收。

### 账户、数据迁移与通知一致性

- 健康、运动、预警、元数据、同步游标和消息收件箱均按稳定账号所有者隔离；换号后旧请求、旧同步和迟到回调不能写入新账号。
- v5 升级遗留数据先进入 `legacy-unscoped`；仅升级启动时已持久化的账号可在单一数据库事务中认领。是否已尝试认领由 secure vault 一次性 migration marker 记录：若首次迁移时未登录，marker 仍会写入，之后登录的账号不得继承遗留数据。认领保留旧健康、运动、预警、元数据、游标和消息记录。
- 401 刷新采用按账号单飞和登录代次 CAS；账号 A 的迟到刷新不能覆盖账号 B 的 Token，也不能用旧身份重放请求。
- 通知按稳定事件 ID 去重；系统通知载荷与数据通知统一归一化，数据通知仅在客户端负责本地提醒，已由系统展示的通知不会再次弹出。
- 关爱日期范围明确使用中国时区日界线生成秒级时间戳，UTC 与 Asia/Shanghai 两套完整测试均通过。
- UTC 午夜边界测试夹具已改为显式中国时区日界线，不再隐式依赖测试宿主本地时区。

### iOS 原生与设备

- iPhone 12 / iOS 18.7.8：同日较早批次 iOS 原生 RunnerTests 曾执行 18/18 通过；最终工作区重跑在 XCTest 框架签名阶段被 `errSecInternalComponent` 阻断，18 项未执行，不能把较早结果冒充最终重跑结果。
- iPhone 12：签名 Debug 安装后完成三次独立启动，Runner 进程均持续存活，设备侧未发现新的 Runner 崩溃日志。该证据仅代表签名 Debug，不替代 Profile/Release 独立冷启验收。
- iPhone 12：Xcode 真实连接 `SD-Watch-W9`，设备页读取电量为 `98%`。
- iPhone 12：Debug 包完成安装并稳定运行，W9 连接、健康同步和原生电量读取均有真机证据；后续因手机重新要求信任开发证书，UI 补充取证被阻断，不能把未执行页面继续写成通过。
- iOS 签名 Profile 因当前 Provisioning Profile 缺少 APNs entitlement 被阻断；这是签名资源阻断，不得写成 Profile 真机通过。
- 最终工作区 iOS 无签名 Debug、Profile 和显式 QA Release 构建通过；默认 Release 无签名按上线门禁正确失败。模拟器 RunnerTests 还受宇程 `JLAudioUnitKit` 缺少 Apple Silicon 模拟器模块阻断。
- UI integration 尝试受 LLDB/Xcode attach 链路影响，最终结果为 `No tests ran`；不能计入通过测试数。
- iOS Veepoo 表盘目录、下载和安装资料已改为调用原生 `VPMarketDialManager`，不再把 Android 目录接口用于 iOS；目录与下载结果绑定连接代次和真实设备 profile。
- iOS 电量采用真实百分比/格数语义；电量、健康历史同步、测量和表盘传输共用原生命令互斥与超时控制，换表后的迟到回调不能覆盖当前连接。
- 极光控制台当前没有与 `cc.saidian.app` 匹配的 iOS APNs 证书/Bundle 配置；iOS 系统推送未接通，不能沿用 Android 通道结果。控制台 Android 集成度仍为 `--`，HarmonyOS 的应用包名、Server Key/JSON 也未配置完成。
- iPhone 15 Pro Max：收尾阶段已连接，机内旧版 `0.1.19 (23)` 可启动并持续运行 30 秒；最终代码签名包因 Xcode 当前 `No Accounts` 且 Provisioning Profile 不包含该设备而无法安装。只能记录旧包稳定性，不能计入最终代码真机通过。
- iOS 生产更新仍只能跳转真实 App Store 产品页；当前没有产品页及生产清单，线上更新未验收。

### Android MED 多设备真机

- MED Android 已分别扫描并连接 ET488、W9S、W8；本轮只对实际进入的功能逐项记录，不用单一手表结果代替其他型号。
- ET488 在线表盘目录实测 215 项；W9S 严格 profile 为 `dialShape=58`，在线目录实测 161 项。
- W8 只读返回 5 个已安装表盘；没有厂商授权在线目录时不开放安装，也不生成虚假缩略图。
- W9S 电量实测为 `100%`；最终代码在 W8 重连后读取到 `85%`、未充电。重连过程未出现 GATT 133，捷理日志敏感对象计数为 0。
- 同日较早批次曾临时切换表盘 144 并恢复原表盘 146；本次最终回归没有再次改变表盘，避免占用唯一自定义槽位。
- Android Debug 冷启动仍偏慢；使用同包名、同调试证书的最终 QA Release 覆盖安装后，首次安装时间保持不变，进程持续存活，未发现本应用 `FATAL EXCEPTION` 或 ANR。
- 最终 Android QA Release 冷启动后恢复 Veepoo BLE 通知与写入流量；本次覆盖安装保留登录、本地健康数据、设置和手表绑定。
- QA Release 冷启动后历史健康记录恢复可见（数值已脱敏）。
- W9S 自动恢复连接，页面显示真实 MAC `<MAC 已脱敏>`、电量 `100%`；表盘商城返回 161 款且真实缩略图可见。
- W9S 心电启动和停止命令均收到设备 ACK；测试时手表未佩戴，因此没有有效波形。该项只能记为“命令链路通过、有效心电样本未验证”。
- W8 相机系统策略禁用真机复测通过：页面显示明确不可用原因且快门禁用；恢复权限后预览与快门入口恢复。本轮异常路径未拍照，也未留下测试媒体。
- 另一台 JAD Android 已存在 `0.1.19 (23)`，但处于物理 PIN 锁定状态，本轮无法打开 App 或完成独立回归，不计入设备覆盖。

### 客户端问题修复补充

- 远程关爱指标详情曾直接遍历整行原始字段，导致 HRV 页面混入步数、心率、血压和英文嵌套键，并显示时间 `-1`。客户端已改为按当前指标白名单投影，统一中文标签/单位，血压拆分收缩压和舒张压，无效时间显示“第 N 条记录”，复合身体/血液成分只保留相关子项；定向 `ui_shell_test.dart` 41/41 通过，MED 上真实成员 HRV 页面复测为 4 条纯 HRV 记录，无混入字段及 `-1` 时间。
- “关于我们”页面对异常短文本/脏数据的回退已修复；MED 真机确认异常短值未展示，改用本地安全说明。真实生产接口的更多异常结构仍由自动化覆盖并继续保留防御。

### 推送通道现场结果

- Android JPush SDK 已完成注册并建立 TCP 连接，控制台应用包名与 `cc.saidian.app` 一致；该证据只证明 Android 客户端到极光的传输层接通。
- 真机日志审计发现上游 Android 插件会无条件回显包含 AppKey 的 `setup` 参数。仓库现锁定本地 `jpush_flutter 3.5.1` 源码并移除参数日志，同时在所有构建模式关闭厂商详细日志；最终 APK 覆盖安装后 AppKey 精确值与 Registration ID 形态日志均为 0，`onConnected=true`，现场临时日志已删除。
- 客户端随后按有限退避尝试登记设备，最终状态为 `retryScheduled / server_rejected`，再次证明服务端登记接口仍是外部阻断而非 SDK 连接失败。
- 未记录或提交任何 AppKey、Registration ID、Token、AuthKey 等敏感值。
- 服务端设备登记、未读/已读、关爱 Outbox 和真实业务推送仍缺失，因此不能把 SDK 在线等同于健康预警或关爱邀请端到端到达。

### 外部阻断与上线结论

- 尚缺受保护 CI 中的生产 JPush 配置、iOS APNs 配置、已选 Android 厂商通道凭据、Android 正式签名、公开 HTTPS 更新清单和 App Store 产品页；现场 Android 调试通道已连通不等于生产凭据完成。
- 2026-08-29 现场请求 `https://app.saidian.cc/app-update.json` 返回 HTTP 404，证实该地址尚不能作为生产更新清单。
- Apple 公开查询中包名 `cc.saidian.app` 在中国、美国、香港区均无产品结果，iOS 正式商店跳转无法验收。
- 服务端推送设备登记/解绑、未读数和已读路由只读请求均返回业务 `code:404`，关爱邀请 Outbox 推送链路也未能验证；客户端轮询只能作为前台兜底，不能冒充后台即时推送。
- 现有 `/api/v1/member/notify` 在未授权请求下返回业务 `code:500` 并暴露 Yii 文件路径/堆栈；服务端需统一为 401/403 并关闭生产堆栈输出。
- 因上述资源和接口缺失，关爱请求与健康预警的生产推送“10 秒内到达”无法认证，Android 旧正式包升级和 iOS App Store 跳转的线上更新也无法认证。
- 当前结论：Android MED 上 ET488/W9S/W8 的扫描连接、表盘能力、W8 电量、关爱详情、关于页、相机异常恢复和 Android JPush 传输层均有真机证据；iPhone 12 Debug 的 W9 连接、同步和电量有证据，iPhone 15 Pro Max 仅旧包启动稳定。有效 W9S 心电波形、iOS APNs、HarmonyOS 推送配置、业务推送、正式在线升级、iPhone 15 Pro Max 最终包安装及 PIN 锁定的 JAD Android 均未完成，不能标记达到正式上线条件。

后续每次格式化、静态检查、测试、构建和真机验证继续追加记录，失败项保留原始结论并注明修复结果。

## 15:50 鸿蒙保留式测试版与防回归收尾

- 安装方式改为同包名覆盖安装，不使用 `flutter run`，不卸载、不清空应用数据；测试结束后 App 继续保留在手机桌面，可脱离电脑冷启动。
- JAD-AL00 / HarmonyOS 4.2 已完成保留式 Debug 真机回归：登录态、本机健康记录、设置和手表绑定均保留；W9S 可自动重连，电量读取为百分比语义，数据同步结束后进程稳定，未发现本应用 FATAL 或 ANR。
- 扫描页已在设备名称同行明确显示 `Vep` / `Yuc`，为真实 MAC 留出完整宽度；iOS 无真实 MAC 时仍只显示明确的 iOS 标识，不把 UUID 冒充 MAC。
- 权限页从系统设置返回后会刷新实际状态；通知入口在华为系统上改为打开当前 App 设置，避免反复请求已拒绝权限却没有可操作入口。
- 相机遥控曾复现“退到后台后未按快门却自动保存照片”；现已增加前后台代次、回调序列和激活宽限保护。真机退到桌面 20 秒再返回，预览恢复且相册文件数不变。仅删除了本轮明确创建的 2 张测试照片，其他相册内容未动。
- iOS 新增相机照片写入系统相册的原生实现及“仅添加照片”用途说明；参数限制、文件名清理和 50 MB 上限由 RunnerTests 覆盖，原生测试目标已完成无签名 `build-for-testing` 编译。
- 全局收键盘改为被动指针监听，不抢占按钮或输入框手势，不向 VoiceOver/TalkBack 增加全屏点击语义；点空白和按钮可收键盘，切换输入框、重复点当前输入框与滚动均保持正确行为。
- SQLCipher 不可读时改为先完整隔离主库、WAL、SHM 和 journal，再建立新库；任一移动或重开失败只回滚已移动文件，不删除原路径上未移动的文件。恢复待处理状态跨启动保留，并阻止提前写入旧数据迁移完成标记。
- 支付 `pay_type` 的 `100/101` 改为字符串序列化，与只读交付小程序中同字段的字符串接口约定保持一致；真实 App 微信/支付宝支付仍需服务端签名参数和幂等策略完成后再做付费验收。
- 最终静态检查为零问题；`TZ=UTC flutter test` 与 `TZ=Asia/Shanghai flutter test` 各 341/341 通过；iOS 无签名 Debug 构建通过；Android 显式 QA Release APK 构建通过。
- 远程关爱与消息接口在当前登录态仍返回 401，客户端已展示真实失败态；极光设备登记仍受服务端接口阻断；公开更新清单、Android 正式签名、Huawei 厂商推送配置和 App Store 产品页仍未提供，均不得标记为生产上线通过。
- 当前 QA Release 使用调试签名，只适合现场长期测试。将来正式包如改用生产签名，Android 不能直接覆盖此测试包；正式发布前必须固定生产签名并单独验证数据迁移或云端恢复方案。

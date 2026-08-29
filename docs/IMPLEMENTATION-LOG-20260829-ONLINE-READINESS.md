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
- `TZ=UTC flutter test` 与 `TZ=Asia/Shanghai flutter test`：各 310/310 通过。
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

- iPhone 12 / iOS 18.7.8：最终代码的 iOS 原生 RunnerTests 真机执行 18/18 通过，结果位于 `build/runner-device-tests-online-readiness/Logs/Test/Test-Runner-2026.08.29_07-50-02-+0800.xcresult`。
- iPhone 12：签名 Debug 安装后完成三次独立启动，Runner 进程均持续存活，设备侧未发现新的 Runner 崩溃日志。该证据仅代表签名 Debug，不替代 Profile/Release 独立冷启验收。
- iPhone 12：Xcode 真实连接 `SD-Watch-W9`，设备页读取电量为 `98%`。
- iOS 签名 Profile 因当前 Provisioning Profile 缺少 APNs entitlement 被阻断；这是签名资源阻断，不得写成 Profile 真机通过。
- UI integration 尝试受 LLDB/Xcode attach 链路影响，最终结果为 `No tests ran`；不能计入通过测试数。
- iOS Veepoo 表盘目录、下载和安装资料已改为调用原生 `VPMarketDialManager`，不再把 Android 目录接口用于 iOS；目录与下载结果绑定连接代次和真实设备 profile。
- iOS 电量采用真实百分比/格数语义；电量、健康历史同步、测量和表盘传输共用原生命令互斥与超时控制，换表后的迟到回调不能覆盖当前连接。
- iPhone 15 Pro Max：本轮不可用，未执行该机型回归；不得写成通过。
- iOS 生产更新仍只能跳转真实 App Store 产品页；当前没有产品页及生产清单，线上更新未验收。

### Android W9S 真机

- 严格 profile 读取为 `dialShape=58`，在线目录实测返回 161 项。
- 手表 SDK 电量读取值实测为 `battery=100`。
- 临时安装并切换表盘 144 成功，验收后已恢复原表盘 146。
- Android Debug 冷启动仍偏慢；使用同包名、同调试证书的最终 QA Release 覆盖安装后，首次安装时间保持不变，进程持续存活，未发现本应用 `FATAL EXCEPTION` 或 ANR。
- 最终 Android QA Release 冷启动后恢复 Veepoo BLE 通知与写入流量；本次覆盖安装保留登录、本地健康数据、设置和手表绑定。
- QA Release 冷启动后旧健康数据恢复可见：血压 `136/81 mmHg`、心率 `84 次/分`、体温 `36.5℃`。
- W9S 自动恢复连接，页面显示真实 MAC `38:23:A4:5E:CA:69`、电量 `100%`；表盘商城返回 161 款且真实缩略图可见。

### 外部阻断与上线结论

- 尚缺 JPush AppKey、APNs 配置、已选 Android 厂商通道凭据、Android 正式签名、公开 HTTPS 更新清单和 App Store 产品页。
- 2026-08-29 现场请求 `https://app.saidian.cc/app-update.json` 返回 HTTP 404，证实该地址尚不能作为生产更新清单。
- Apple 公开查询中包名 `cc.saidian.app` 在中国、美国、香港区均无产品结果，iOS 正式商店跳转无法验收。
- 服务端推送设备登记/解绑、未读数和已读路由只读请求均返回业务 `code:404`，关爱邀请 Outbox 推送链路也未能验证；客户端轮询只能作为前台兜底，不能冒充后台即时推送。
- 现有 `/api/v1/member/notify` 在未授权请求下返回业务 `code:500` 并暴露 Yii 文件路径/堆栈；服务端需统一为 401/403 并关闭生产堆栈输出。
- 因上述资源和接口缺失，关爱请求与健康预警的生产推送“10 秒内到达”无法认证，Android 旧正式包升级和 iOS App Store 跳转的线上更新也无法认证。
- 当前结论：客户端、自动化门禁和 iPhone 12／已连接 Android 范围内的验证已就绪；生产推送与正式在线升级仍为服务器、凭据和商店资源阻断，iPhone 15 Pro Max 也未完成本轮回归，不能标记达到正式上线条件。

后续每次格式化、静态检查、测试、构建和真机验证继续追加记录，失败项保留原始结论并注明修复结果。

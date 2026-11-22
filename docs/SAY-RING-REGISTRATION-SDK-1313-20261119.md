# 注册修复与双SDK升级合并、正式1313安装（2026-11-19）

## 范围与合并

- 用户确认1312不包含最新注册修复后，明确要求合并、重新打包并安装当前手机。修改前工作区干净、fetch成功；SDK基线 `3cfd0ead1f2b744c954580776911e065d6341bf9`，注册修复目标 `07dae22c0cbcc7be58b7e23a95c2bc69200f60ee`。创建 `codex/registration-sdk-install-1313-20261119`，使用非快进合并保留双方历史。
- 业务源码和测试自动合并，唯一冲突为CHANGE-TEST-LOG索引，保留双方的注册、CoolWear和QRing记录。没有丢弃SDK修改、覆盖独立注册工作区或合入独立客服/iOS功能分支。
- 合入“注册实际已创建却报验证码错误/操作失败”的客户端修复：不确定响应只使用本次明确身份与刚设置的密码确认一次，不重复注册或消费验证码；保留服务端明确验证码失败，区分已创建/待确认，注册后的可选资料刷新不推翻成功。找回密码与已登录账号隔离保护保留，具体测试见原注册修复记录。
- 保留官方CoolWear1.4.1原始AAR（F9181033…）和QRing1.0.0.86原始AAR（1c89c4ae…），不改原生桥接、初始化/清理ACK、同步、手测或功能门禁。本机build仍使用上一轮经核验迁移的D盘缓存junction。

## 验证与交付边界

- 计划执行认证定向回归、离线认证工具和SDK指纹、格式/静态分析、完整Flutter双时区回归及Debug/正式Release、原证书/包身份/ABI/SDK副本检查，版本1.0.14（1313）。SDK和原生源码与已验证1312相同，沿用其135项原生与46项协议通过证据，不将沿用写成重跑。
- 不发送真实验证码、不注册或切换客户账号，不触发戒指绑定/清空或实物测量。安装使用当前USB授权手机，保留原账号、绑定和记录；只有手机系统安全验证需要本人操作。
- 本机原始日志和APK放在Git外 `E:/SayRing-registration-sdk-1313-20261119`。完整验证、Git/CI、正式包和实际安装结果待完成后追加，不将已发起安装写为安装成功。

## 定向验证与过程

- 合并后的lib/test内容与原已验证注册修复分支07dae22完全一致；android/pubspec/lock/config/assets/tool与已验证1312完全一致，SDK指纹保持F9181033…及1c89c4ae…。沿用原生证据有明确源码和依赖一致性依据。
- `dart format --output=none --set-exit-if-changed lib test` 检查361个文件、0改动；四个认证相关Flutter测试文件64项全部通过。离线认证/账号QA/SDK锁定Node82项全部通过，均不发送真实请求。
- 首轮离线CLI的Windows ACL夹具在E盘的临时目录被操作系统拒绝设置ACL，81通过/1失败；同一夹具在本人C盘临时目录可正确设置并验证ACL。只把本轮Node测试的临时目录移到本人C盘，Flutter/构建继续使用E/D既有缓存；完整82项重跑全通过。未修改ACL验证策略、跳过测试或更改客户凭据目录，原失败日志保留。

## 全量回归与打包故障修正

- 合并后静态分析无问题，UTC / Asia/Shanghai完整Flutter回归各2452项通过；Debug构建通过。库/原生桥接保持1312一致，135项原生与46项SDK协议结果沿用，非本轮重跑。合并源码ecfd84a已推送，保留3cfd0ea与07dae22双方父提交；初始CI44502526065状态另行核对。
- 首个Release虽通过原签名/清单/ABI对称性检查，最终条目比较发现仅46,240,741字节，缺少两种架构的libapp.so。该包SHA-256 40AA2231…已隔离为rejected-missing-runtime-1313.apk，未发起手机安装，不能交付。此前stage=complete只反映旧门禁范围，不能当作可运行证明。
- 实际Gradle输出中同一AOT文件同时出现E盘junction别名与D盘物理路径；新AOT已编译但复制后的app.so被增量输出清理。保留证据，把本次AOT缓存及release暂存目录完整移动到核验过的D盘备份位置后重新生成，不删除或复制旧APK内的主程序。
- 修正Android构建根目录解析，使用Java NIO toRealPath统一实际物理路径，兼容首次checkout尚无build目录的情况。实测File.canonicalFile仍返回E盘别名，故不能仅靠该API；NIO返回D盘真实路径。旧SDK缓存与用户数据保留，只有本机生成缓存重建。
- 发布门禁要求每个生产ABI必须包含非空libapp.so和libflutter.so，防止“两边同时缺失”绕过对称性检查。新增缺程序/缺引擎/空文件回归，原ABI/JPush正反例保留；相关APK测试7项、JPush1项通过，新门禁实际拒绝了上述损坏包。
- 清理旧路径缓存后曾生成74,634,353字节的完整包并通过新门禁和Release后Debug复建；随后继续完成NIO真实路径构建复核。最终交付hash、正式验证与安装结果以末尾实测记录为准，不将中间包当作最终已安装版本。

## 最终正式包与实装结果

- NIO修正后的实际Flutter输出路径为D盘物理目录，两种架构的当前app.so均存在；普通main入口Release、原正式签名验证、新主程序完整性门禁、包身份/清单/ABI/ZIP16KB及Release后Debug复建全部通过。stage=complete，SDK构建副本30项一致性再次通过，android/key.properties不存在。
- 最终APK `E:/SayRing-registration-sdk-1313-20261119/SayRing-1.0.14-1313-release.apk`，74,634,353字节，SHA-256 `AC5508112196957AADA65BAAEB2A8FCF1DF556A8A3DC79AB42AE6B62CC3E30C4`；cn.saydian.ring、1.0.14（1313）、non-debuggable，原正式证书SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。相对1312文件集合1027项一致、无遗漏；两种ABI的libapp.so均含本次新增的两个注册状态标识，且hash与1312不同，确认并非误用旧主程序。
- App lib/test与注册分支07dae22一致，SDK原始字节/原生桥接保持1312一致；后续1f42eef仅修正输出目录和发布门禁，不改变已通过两时区各2452项的业务逻辑。原生135项/SDK协议46项仍为明确沿用证据；新门禁APK7项及JPush1项实际通过。旧JPush ARM64-only受控例外及两项32位ELF LOAD 4KB限制保留，不宣称所有市场审核或16KB ELF要求通过。
- 对当前USB授权的华为LIO-AL00执行adb install -r，等待本人解锁/确认后返回Success。手机PackageManager实读versionCode1313、versionName1.0.14；firstInstallTime与原1310一致，保留数据覆盖安装。再从手机只读取回base.apk，SHA-256与最终交付包AC550811…完全相同。启动/恢复MainActivity后进程持续存在、前台焦点为Say Ring，未执行退出账号、解绑、清空、重置或真实注册/验证码发送。
- 合并源码ecfd84a及构建修正1f42eeffeef49089dde084c2a040854305160cb1已推送同一交付分支。后者CI44510667675最后检查两个时区Harmony成功，quality仍在上海时区测试；未将进行中写成全通过。无后台发布、商店提交或下载页变更，原始日志和手机读回APK仅在本机Git外private目录。

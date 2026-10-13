# Say Ring 1051 原位安装与只读真机回归

## 范围与基线

- 基线 `4d2e43b2cf261bb251406609c43a7a4f60946e29`，工作分支 `codex/macos-update-20260930`。开始时工作树干净，origin 获取成功。
- 仅 Say Ring / `cn.saydian.ring`，优先 iPhone 15 Pro Max。无卸载、无健康数据清理、无账号切换、无换环，不操作 App Store 审核或其他 App。
- 初次正常 main 实际连接 R21，后续只读集成测试启动时实际恢复 HR01，固件 `758.2.1.9.0`。未主动调用扫描/选择/换环 API；两次真实观测分别记录，不能合并为同一枚设备验收。HR01 监测写入仅在测试入口再次确认当前精确绑定并完成真实握手时执行。

## 安装与真实观测

- `xcrun devicectl list devices` 确认目标 available (paired)，安装前 `device info apps` 显示 Say Ring 1047。
- `device copy from` 分别备份当前 Library / Documents 到忽略目录 `.build/1051-preinstall-20261004-private`，两次均成功、合计 22 MiB。该备份是当前容器，不代表此前卸载丢失的本机时间轴已恢复。
- 原生产 main 签名候选 `.build/1051-profile/Payload/Runner.app` 再验 `codesign --verify --deep --strict` 成功，Bundle ID / 1051 一致。
- `devicectl device install app` 原位安装成功；再次查应用列表确认 1051。使用 `flutter run --profile --no-pub --use-application-binary=...1051...Runner.app --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY= -d <目标UDID>` 启动，约 12 秒附加真实 Dart VM。
- 私有只读 VM 检查确认有认证会话，当前 R21 自动完成连接和 ready 能力握手，固件 `RF22B_2.00.06_260930`。设备功能仅 findWatch / healthMonitoring；相机、手势、来电不因其他 SDK 已实现而强开。
- 原生屏幕截图确认设备页“已连接”，无重连按钮，查找戒指 / 健康监测入口存在，真实历史同步进行中。截图/设备标识/账号/健康值均留在忽略目录。
- 第二次临时 VM 检查脚本遇到缺少字段错误，不计通过；首次结构化结果及实际截图仍各自有效。
- iPhone 镜像因本机 iCloud 退出登录无法交互；不创建登录、不改变系统授权，改用已有 Flutter 真机集成测试。

## 测试实施规则

- 只读巡检显式选择健康首页，避免保留设备页选中项时产生误失败。对真实能力未就绪的相机、手势、来电检查入口隐藏；健康监测只读实际设置并断言读取成功，不发送修改指令。
- 所有真机 drive 必须经 `tool/drive_ios_preserving_data.mjs`，显式选择新构建验签的 Profile 测试包，保留运行；结束后无论结果均重新覆盖生产 main 1051，不卸载。
- 本轮生产代码未改；1051 已完成的双时区全量 / 双端构建 / 原生门禁仍按上一份记录。新增巡检代码将单独分析、构建、执行并追加结果，不将旧结果写成新增实机通过。
- HR01 的严格设置保存本轮执行结果见下；相机实际快门、手势系统效果、来电及振动、真实闭合夜睡仍待对应实物；三轮物理远离靠近、锁屏与蓝牙开关不因一次开机恢复而宣称通过。

## 本轮失败与校正

- 初次逐页 Profile 构建 33.9 秒成功，60.6 MB，验签 / ID / build / iPhone-only 通过。保留数据 wrapper 启动约 11.6 秒，真实首页、心率、血氧、皮肤温度、HRV、睡眠详情/概览、全部数据、关爱、百科、运动页面均已打开。
- 随后消息入口 tap 产生 hit-test warning，标题断言失败，整项测试不通过。实际截图显示仍停留首页，头部部分滚入状态栏；修正测试在点击前将首页列表 jumpTo(0)，并要求 hitTestable，不屏蔽 warning、不删除消息断言。未确认这是生产页面故障，不为测试选择位置错误修改生产 UI。
- 失败后 wrapper 明确 Leaving the application running，无卸载；立即原位覆盖生产 main 1051 并用 devicectl 成功启动。
- 同时运行的 UTC 全量单测在 +76 后停止进展，进程及编译器 CPU 为 0；原因未确定。主动 SIGINT 停止，不计通过。之后改为与 Flutter 真机 drive 串行，重跑完整门禁；不沿用中断进程的退出码作为成功。
- 私有 VM 对 Null-capability 字段读取补防御后，真实 HR01 返回 find/camera/gesture/monitoring 能力，未返回 callReminder；已有 HR01 睡眠记录计数为 0，不伪造数据。
- 增加串行组合入口，逐页只读后执行已有 HR01 三项监测切换/严格回读/原值恢复，再检查六项手势选择只读页面、相机开启/关闭 ACK、查找开始/停止 ACK。SDK 无可靠当前手势查询，故不改变未知原模式；ACK 不当作实际照片、手势或振动通过。
- 额外查询旧 native/home 文件名失败，使用 rg 定位真实模块；未修改原厂 SDK 或图片素材。磁盘持续检查。
- 第二次默认并发 UTC 重跑也在 +227 / teardownAll 后失去进展，约 90 秒时停止，不计通过；无法证实由并发 drive 引起。改用 `flutter test --no-pub --concurrency=1` 完整串行执行，当前已跨过原停止位置。没有删掉测试或改生产逻辑来规避。
- 最终新增集成测试 Analyzer 6.0 秒零问题，保留数据 wrapper 两项 Node 测试通过；格式化 / `git diff --check` 通过。监测测试在写入与清理前校验原账号和精确设备 ID，不将 HR01 原值恢复到其他设备。
- `TZ=UTC flutter test --no-pub --concurrency=1` 完整 1174 项 / 145 秒通过。新增文件只改变测试入口/断言和记录，生产客户端源码及 native transport 均未变，Android 不新增安装或功能通过结论；原同源 1051 双端构建和原生门禁以先前记录为准。
- iOS 重建前可用空间约 0.3 GiB。确认本项目没有 GradleWrapper/Android 构建，仅有空闲 daemon，且目标为本项目非链接的生成目录后，清理 `build/app/intermediates/merged_native_libs/debug`（963 MiB，可通过 Android 构建重新生成），空间恢复约 1.2 GiB。首个带 force 的删除命令被工具拒绝，未执行；采用不带 force 的 scoped 删除成功。没有删除 APK、源码、SDK、签名、归档、手机数据或测试缓存。
- `TZ=Asia/Shanghai flutter test --no-pub --concurrency=1` 完整 1174 项 / 126 秒通过，成功后才串行构建组合真机 Profile。两个时区均完整执行，没有以定向测试或中断结果替代。
- 组合 Profile `--target=integration_test/ios_owned_ring_regression_test.dart` 构建 32.7 秒、60.7 MB；验签 / cn.saydian.ring /1051/仅 iPhone/team W7SXQ4A226 通过。AOT 中存在两项测试名称，确保 wrapper 使用的是本次新测试二进制，而非旧 main；保留的生产 main 中无这些测试名称。最终 Analyzer 3.9 秒零问题。
- 组合 wrapper 原位启动 12.2 秒，真实 HR01 再次完成能力握手。所有临时二进制、日志、SDK回包、VM和截图留在忽略目录，不加入 Git。

## 实际验收结果

- 组合真机测试 191 秒完成，wrapper exit 0，All tests passed。驱动显示 +3 含框架 teardown 项；产品测试两项（逐页巡检、HR01 监测与控制）。首轮失败记录保留，不宣称第一次就通过。
- 逐页实机已打开 23 项：首页、心率、血氧、皮肤温度、HRV、睡眠详情、睡眠概览、全部健康数据、远程关爱、百科、运动、消息、设备、监测真实设置、我的、资料只读、单位、健康档案、账号、权限、反馈、客服、关于。每页无 tester 捕获异常，不等于完成这些页面所有服务端写入/上传验收。血压、血糖、心电、压力等不支持且无记录的入口隐藏，未强开。
- HR01 原始三个开关（heartRate / heartRate24h / bloodOxygen）分别 UI 切换成功；每次均在后续刷新前断言“设置已写入戒指”，之后独立新读确认修改且其他字段不变，再写回并读回原值。finally 再次三项恢复，结果文件 `originalSettingsRestored=true`，无账号/精确设备变化。
- 控制结果：六项手势选项只读页面、相机开启 ACK / 关闭 ACK、查找开始 ACK / 停止 ACK、未支持来电提醒入口隐藏全部通过。没有实际拍照保存、改变手势模式或发起测试来电；振动和系统手势效果未观察，不按 ACK 推断。
- 测试后重新覆盖无测试入口的生产 main 1051；devicectl `--terminate-existing` 冷启动成功，最终安装应用列表仍 1051。独立启动截图确认真实认证健康首页正常，无启动闪退，HR01 暂无睡眠样本的空状态正常显示。
- 直接 `flutter attach --profile` 等待 VM 发现未连接，安全终止；改为显式生产二进制的 Profile run 再附加，不使用旧测试包或改包名。
- 最终生产 main 的真实 VM 再次确认认证会话、HR01、固件 758.2.1.9.0、能力 ready，find/camera/gesture/monitoring 四项存在，睡眠旧记录仍 2 条、当前 HR01 0 条；不打印或提交真实健康数值/账号/设备标识。随后 detach 保持 App 运行。

## 交付与待验

- 本轮变更为集成测试与证据记录；普通安装包仍是已经完成完整双端编译门禁的生产 1051。安全清理的 Android 合并中间件后续可重建，两个旧 APK 及所有签名/SDK/备份均保留。
- 同账号原位覆盖、独立启动、真实恢复/握手、监测严格回读已通过；非三轮距离/锁屏/蓝牙开关验收，仍不将工作分支提升为完整硬件验收 main。
- HR01 实际相机快门/本机照片、六种系统手势、来电硬件通知、查找振动、真实闭合睡眠（含小睡）、插拔充电仍缺对应实物动作或数据证据；不强行开启缺失来电能力，不伪造评分/阶段或睡眠时长。
- 本轮未执行注销、删除、上传照片、修改分享、AI健康上传、来电呼出或其他 App 操作。App Store 构建与审核未改。此前卸载造成的旧本机-only 睡眠时间轴仍无恢复证据。

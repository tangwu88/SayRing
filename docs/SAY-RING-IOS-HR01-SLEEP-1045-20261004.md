# HR01 睡眠自动处理 1045

## 现场与修改范围

- 基线 68d9df4，远端当前分支已同步，工作树干净。1044 iPhone Profile 已自动连接 HR01、完成能力握手和电量读取；不改已提交审核。
- 当前只读 AppController 能力包含心率、血氧、HRV、皮肤温度，未包含睡眠；首页缓存存在其他睡眠记录，不将它当作 HR01 实测睡眠。当前未确认有效 HR01 睡眠包，不宣称已有睡眠被修复回读。
- 原厂保留副本的 iOS 蓝牙SDK使用指南说明：sleepInfos 记录状态变化，同一段只发送一次；完整睡眠必须 START(1) 到 WAKEUP(4)。原文和 SDK 只读，未发送清空命令。
- 代码缺口：自动恢复 CoolWear 后有意不执行手动长同步，而睡眠仅在手动同步 25 秒结束时整理；迟到的历史能力发 capabilities，但控制器处理的是 capabilitiesUpdated。
- 仅修改 iOS CoolWear：接收真实睡眠包后，在当前连接代次/资料握手/账号数据接收已就绪的条件下，用独立 25 秒窗口处理已完整接收的批次；不加蓝牙命令，不阻塞测量。与手动同步共用闭合/时间/缺包校验和稳定记录去重。补齐控制器可识别的能力更新事件。
- 不补造未知阶段、时间、REM/小睡或旧睡眠；尚未收到/不完整的原始包不宣称睡眠成功。曾在其他 App 或旧版本被消费的唯一片段不保证可补回。

## 检查与实物结果

- `flutter analyze --no-pub` 零问题；`TMPDIR=/private/tmp TZ=UTC flutter test --no-pub` 与 Asia/Shanghai 完整测试各 1162 项通过。
- 新增 Dart 回归覆盖 CoolWear 初始无睡眠能力、真实形状的被动汇总事件、迟到能力更新、重复记录去重、无额外手动同步及换号隔离。定向 11 项通过；修正夹具的心率 wire 名为 heart_rate 后再跑 11 项通过。合成数据不代表实物返回。
- Node 四组包、日志、桥接检查 29 项通过；新增被动睡眠代次隔离、完整批次、去重、不发送额外 BLE 指令契约。Python release discover 31 项通过。
- Foundation CoolWear history/battery/name/capability/RRI 与 QRing mapping 可执行测试通过。Android `:app:testDebugUnitTest --max-workers=1` 40 项通过，失败/错误/跳过均为 0；这些不是 iPhone 硬件验收。
- iOS Debug 无签名回归 30.2 秒通过；串行签名 Profile 44.7 秒/59.9 MB 通过。cn.saydian.ring/1.0.0/1045、UIDeviceFamily=[1]、Team W7SXQ4A226、get-task-allow 和设备包含校验通过；codesign verify 通过。
- Profile 和匹配 dSYM 独立保留于忽略目录，arm64 UUID 同为 28DA1C53-7F13-37DC-B320-AB8D0F8D0E15。1044 回退包保留。
- Android 双 ABI Debug 9.3 秒、内部 QA Release 32.6 秒/69.4 MB 通过；独立保留 APK，aapt 核对 cn.saydian.ring/1045，apksigner 和 zipalign 16 KB 通过。QRing SDK 构建副本 30 项未变化，未安装或操作 Android。
- 1044 原调试会话只读 getVM 查询超时，已结束只读查询并增加 10 秒查询边界；不因此推定 HR01 没有睡眠或 App 闪退。新包会重新建立调试连接。
- 原厂保留 SDK 头文件实际在副本的 ios/sdk/SDk 目录；第一次查错 demo 子目录未取得文件，已找到真实只读副本。没有修改原 SDK。

## 1045 真机结果

- `devicectl device install app` 在 iPhone 15 Pro Max（iOS 26.6，开发者模式已启用，有线）原位覆盖成功；设备安装列表实际为 cn.saydian.ring/1.0.0/1045。
- `flutter run --profile --no-pub --use-application-binary=.build/1045-profile/Payload/Runner.app -d <本机已注册设备>` 使用同一签名包启动、连接真实 VM。启动后截图显示原账号和旧健康卡片，睡眠概览仍为空；不将其他戒指旧记录用于填充。
- 初次查询发生在 VM 尚未公布时，返回 No VM service；等待启动完成后只读查询成功。实际 AppController：HR01 已自动连接、恢复=false、能力 ready、真实电量存在；首页缓存有睡眠，但精确当前 HR01 的睡眠记录数为 0，当前能力亦未包含睡眠。
- 尝试通过 VM 调用正常 syncDeviceData（已连接 HR01、未同步/未测量守卫）得到 @Error/UnhandledException，未启动手动同步。没有绕过守卫、改运行时字段或插入测试健康值；不标为实际手动历史读取成功。App 日志无 Unhandled Exception，不能把调试调用错误混为真实 App 崩溃。
- 已公布 VM 后日志没有失联、布局溢出或 App 未处理异常；闭源日志未见 SleepStartTime 字段，不将缺日志当作确定的 SDK 无数据回执。实物睡眠仍未验收通过。
- 真机日志、VM URI、账号、精确设备标识、健康值及截图仅在忽略目录，不提交 Git。未修改网络接口、服务器上传范围或任何现有审核资料。
- 最后复查同一 Profile VM：HR01 固件 758.2.1.9.0、持续连接且能力 ready，当前设备睡眠仍为 0。只读检查没有执行测量或修改缓存；不宣称睡眠实物通过。
- 最终 Analyzer 再跑零问题；夹具修正后 UTC、Asia/Shanghai 再跑完整测试各 1162 项通过。Dart format 零变化和 git diff --check 通过。提交前 fetch 核对当前分支本地/远端仍为 68d9df4，没有覆盖其他改动。

## 尚未完成的硬件边界

- 未取得这枚 HR01 的完整真实夜睡。唯一片段已经被旧 App 消费，或 START/WAKEUP 缺失时，不承诺旧夜睡补回。
- 原始未闭合片段仍只在本次连接内保留；不能声称已支持跨断连/重启收集同一夜全部唯一片段。本轮仅修复已完整收到批次的自动整理和能力通知。
- REM、小睡、原厂归属日和完整阶段时间轴继续未确认；不把深浅睡汇总伪装为 QRing 明细。
- 1045 只做原位覆盖，不卸载、清数据、执行清空戒指命令或更换审核包。

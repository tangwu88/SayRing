# iPhone HR01 自动重连 1044

## 修改前现场与根因

- 基线 944f6c8，origin 当前分支已同步，工作树干净；iPhone 15 Pro Max 已配对可用。保留 1042 签名 Profile 回退包，不卸载、不清除绑定和健康记录，不改审核。
- CoolWear 未实现精确目标恢复接口。路由仅执行一次扫描，iOS 分别搜索 F618/F818 共 10 秒；未出现目标就返回空，之后靠近不会再次搜索。这解释了等待后靠近仍不连接的代码缺口；现场持续靠近验收另记。
- 修复范围：iOS CoolWear 原生恢复循环、iOS 专属 Dart 接口、bootstrap 平台选择、路由精确事件校验。Android CoolWear 保持原桥接契约，QRing 不变。
- 当前账号和环境只授权一个 UUID＋真实型号；有限扫描无目标后暂停 2 秒再搜索。目标出现立即进入原厂连接和新能力握手，完成才发布 reconnected。
- 换号、解绑、手动搜索/换环取消旧代次并排空原请求；原 SDK 任意历史自动恢复继续禁用。没有完整后台/强退实测不宣称后台恢复。

## 检查与真机结果

- 最终构建号 1044，生产 /global API，不变包名。`flutter analyze --no-pub` 两次均零问题；本轮四个 Dart 文件 format 最终零变化；`git diff --check` 通过。
- `TMPDIR=/private/tmp TZ=UTC flutter test --no-pub` 和 Asia/Shanghai 各 1161 项通过。定向 CoolWear iOS/已有精确恢复共 12 项通过；覆盖 iOS 专属方法、等待、异设备 UUID、换号后迟到 reconnect、原绑定保留。
- `clang -fobjc-arc -fblocks -framework Foundation test/native_coolwear_policy_test.m` 执行通过；新增 UUID、型号、owner context 和代次拒绝用例。QRing Foundation mapping 执行通过。这些使用合成输入，不代表硬件回包。
- Node 四组契约/包/日志检查 28 项通过；最终 CoolWear 契约复跑 13 项通过。Python release discover 31 项通过。Android `:app:testDebugUnitTest --max-workers=1` 40 项，失败/错误/跳过均 0。
- iOS Debug 无签名构建 103.7 秒；补上显式断开清除恢复目标后，最终 Debug 再跑 20.9 秒通过。中间串行签名 Profile 58.5 秒成功，59.9 MB；核对签名、Team W7SXQ4A226、get-task-allow、设备包含、cn.saydian.ring/1044、UIDeviceFamily=[1]。
- Profile 独立保存 `.build/1044-profile/Payload/Runner.app`，dSYM 与 Runner arm64 UUID 均 A642E58B-07CF-3BCB-A892-16343176E2E1。首次从 iphoneos 路径复制 dSYM 失败；改用真实 Profile-iphoneos 路径成功，失败未当作缺少符号交付。
- Android 1044 双 ABI Debug 11.6 秒、内部 QA Release 54.5 秒/69.4 MB 通过；独立保留两个 APK。aapt 均核对 cn.saydian.ring/1044，apksigner、zipalign 16 KB 校验通过。没有安装或操作安卓登录/绑定，QA 签名不等于商店正式签名。
- 原始 CoolWear SDK 二进制 SHA256 契约仍一致；QRing SDK 构建副本 30 项字节不变，仅既有 mapping-output 规则被移除。未修改原 SDK、算法、接口上传范围或另一款 App 源码。

## 真机现场与边界

- iPhone 15 Pro Max（已配对开发设备，iOS 26.6）从 Say Ring 1042 覆盖安装 1044 成功，未卸载或清数据。重新核对安装列表版本 1.0.0 (1044)、原账号仍登录、既有健康记录可见；独立 Profile 启动进程持续存活。
- 初次读取时前台为另一款 Health 测量页面，不作为 Say Ring 验收。随后按 cn.saydian.ring 明确启动。AX 读取可以取得标签，但激活请求未可靠切换页面；这项未标为设备页触控通过。
- 直接 `flutter attach --profile --app-id cn.saydian.ring` 未发现独立启动 Profile 的 VM，结束该等待。改用 `flutter run --profile --no-pub --use-application-binary=.build/1044-profile/Payload/Runner.app -d <本机已注册 UDID>`，仍是同一签名 Profile，原位安装、VM 和 DevTools 成功，连接持续稳定。未把此前 Debug 失联当作已修复。
- 从 Profile Dart VM 只读 getClassList/getInstances/getObject 检查实际 AppController：connectedDevice 名称 HR01、isWearableRecovering=false、deviceCapabilityState=ready、capabilities 存在且 supportsHistorySync=true、真实电量字段存在。没有调用重连按钮或修改运行时字段；认定新进程自动恢复、完成新能力握手并读取电量通过。
- 截止复查 VM 未失联，当前日志 Unhandled Exception 与 RenderFlex overflow 均 0。日志、VM URI、实例数据、真实账号、设备标识和截图仅在忽略目录；不提交健康数值。
- **待验**：三轮真实远离后再靠近、首次 10 秒无广播后再出现、后台/蓝牙开关、同名第二枚 HR01、取消时物理断开，以及本轮未取得的新健康样本。不能用冷启动连接、主机测试或旧健康值替代这些实物验收。
- 保留可独立启动的 Profile 1044 与其调试会话；不撤回、更换或提交任何 App Store 审核包。

# iPhone 真机 Debug 1067 启动

## 授权与基线

- 用户要求启动苹果版真机测试调试。本轮实际安装并附加正常生产 main 的 Debug 版本，保持活动/睡眠范围、原账号/绑定恢复逻辑及正式产品 ID；没有重新提交苹果审核或改变下载页。
- 修改前 main 干净，`git fetch --prune origin` / `git pull --ff-only origin main` 成功，基线 `412f3f2c0a4febd7b81c6dc2639236e4c2d29a23`，树 `d375d1c70fee5264e520882bf235afcec5b9c5cf`。阅读 AGENTS、交接、复盘/回归、此前 iOS 调试及 1064 发布记录。
- 本轮未改业务代码、pubspec 或签名身份。Debug 通过构建参数使用 `1.0.1 (1067)`，与已发布 1064 和 Android/鸿蒙 1066 分开标识。

## 手机与数据状态

- CoreDevice 确认真机为 iPhone 15 Pro Max / iPhone16,2 / iOS 26.6，USB wired / paired / connected，开发者模式已启用。没有使用模拟器结果代替真机验证。
- 精确产品查询及完整安装清单均未发现 `cn.saydian.ring`；已有单独 QA 测试 Runner 不等于主 App。安装前尝试复制主 App 数据容器返回 `ContainerLookupErrorDomain error 3`，与主 App 未安装一致；不能声称完成了安装前容器备份，也不能据此推断 Keychain 已被清除。
- 安装启动后，原有登录会话和已绑定目标实际恢复；没有重新索取账号凭据、卸载、清库、解绑或选择附近的新目标。自动恢复只沿用现有账号/绑定逻辑。
- 启动后私有容器复制成功：44 个文件、32,496,371 字节，逐文件 SHA-256 清单保存在忽略目录。副本在 App 运行期间取得，未进行恢复演练，不等同于已验证的静止数据库快照。

## 构建与签名

- 构建前没有其他 Flutter/Xcode 编译任务，磁盘约 174 GiB 可用。原有效 Apple Development 身份及团队 W7SXQ4A226 沿用，未创建新证书或导出私钥。
- 串行执行：`flutter build ios --debug --no-pub --build-name=1.0.1 --build-number=1067 --dart-define-from-file=config/ios-app-store-no-push.json`。通过忽略目录的 `XCODE_XCCONFIG_FILE` 只覆盖最低 iOS 为 15.0；Xcode 构建 12.3 秒成功。
- sqflite_sqlcipher / yc_product_plugin 的 SPM 兼容提醒和 WechatOpenSDK 模拟器 arm64 提醒保留；没有关闭门禁或改写厂商二进制。真机目标为 iphoneos。
- `codesign --verify --deep --strict --verbose=2` 通过。实际 bundle 为 `cn.saydian.ring` / `1.0.1` / `1067` / iOS 15.0 / UIDeviceFamily [1] / iPhoneOS。
- 开发签名 `get-task-allow=true`，application-identifier 为 W7SXQ4A226.cn.saydian.ring；描述文件包含目标真机且有效至 2027-10-13。未以其他 bundle ID 绕过签名。
- 独立 Debug IPA `.build/SayRing-1.0.1-1067-debug.ipa`：58,119,371 字节，SHA-256 `743c2fdae97c224d952017b0daddd36f5b2995e37a4e0d3c868a21eb64b9f261`。
- 实际 Runner SHA-256 `05a03b4adb2306891a87ba4c0320dd739fee200bd2fea1a58845de8bcd6537f0`；Flutter App.framework/App SHA-256 `1cf685005acc74c02739d10e1db060df93b1181d65dc20fef9b6ce5f0384dfc3`。旧 1064 Debug 包没有作为失败回退使用。

## 实际启动与验证

- `flutter run --debug --no-pub -d <已核实真机> --use-application-binary=.build/SayRing-1.0.1-1067-debug.ipa --host-vmservice-port=52767 --dds-port=52768 --pid-file=<私有目录>/debug.pid --dart-define-from-file=config/ios-app-store-no-push.json --vmservice-out-file=<私有目录>/vmservice.json` 实际安装/启动 24.1 秒，文件同步 88 ms，保持 Flutter/LLDB 附加。
- CoreDevice 回读主 App 为 `cn.saydian.ring / 1.0.1 / 1067 / builtByDeveloper=true`，正常 Runner 进程 PID 37136 存在。Dart VM `getVM` / `getIsolate` 成功：一个主 isolate、runnable=true、Resume 状态，调试服务与 Inspector 扩展可访问。
- 实际发送 Flutter 热重载命令 `r`：`Reloaded 0 libraries in 342ms (compile: 17 ms, reload: 0 ms, reassemble: 70 ms)`。未改源码，因此 0 libraries 为预期；该结果证明实际附加/重组可工作，不是仅生成了调试包。
- Inspector 树确认 SaydianApp / AppShell / DevicePage 已渲染；真机渲染截图确认当前已绑定 **SD-RING-R7 Ultra** 显示“已连接”、电量可读。没有手工选择其他广播设备，也没有仅凭扫描名称宣称握手完成。
- 启动记录显示正式国际服务及产品更新请求成功；日志检查未见 `Unhandled Exception`、`EXCEPTION CAUGHT BY` 或 `Lost connection to device`。本次观察不扩大为所有后台模式或长期稳定性验收。
- DevTools 地址已由 Flutter 实际生成；Codex 打开面板返回 queued，只提供可用入口，不把队列状态写成面板已展示。含调试认证码的 URL 仅保留在私有运行日志，不写入 Git。

## 失败、更正与交付边界

- 最初将 `--vmservice-out-file` 的内容按 JSON 解码失败；本机 Flutter 实际写入纯 URI 文本，改为兼容纯 URI/JSON 后 VM 两个接口成功。此辅助读取失败不代表 App 崩溃。
- 一次旧 xcconfig glob 没有匹配，改为使用明确路径生成仅含最低版本覆盖的本轮文件，没有修改源码、清缓存或降低目标身份要求。
- 所有原生日志、设备清单、描述文件、截图、容器副本和校验文件位于权限 0700 的忽略目录 `build/ios-device-debug-20261016/`；IPA 与更新的本地重启脚本位于忽略目录 `.build/`。不将账号、完整设备标识、MAC、健康记录或调试认证 URL 提交到 Git。
- 本轮仅启动正常 App 并进行只读运行检查/热重载；未执行新的生理测量、清除记录或改写设备设置。未运行 `flutter drive` 或其他会替换 App 入口的 integration_test，未将一次型号连接等同于全型号、活动/睡眠样本、远距重连或后台完整验收。
- 未改运行时代码，不重复执行历史完整 Flutter/Android/Profile 构建回归；本轮实际门禁为新签名 Debug 构建、签名/设备资格、安装身份、VM/热重载、真实设备页及容器副本检查。
- 当前 Debug 会话留在运行中，未发送 quit/detach；本地 `.build/run-sayring-ios-debug.command` 已更新为本次明确二进制，用于会话结束后的重启。调试说明/索引提交并推送 main，源码树保持一致。

# Say Ring 1042 iPhone 原位安装与调试

## 基线与保护

- 2026-10-04，源码 97588b2eb71c8f6f854e34c6290356b8834eed41，codex/macos-update-20260930；工作树干净，fetch 后无远端更新。仅 Say Ring，不改现有 App Store 审核或其他 App。
- 当前连接 iPhone 15 Pro Max / iOS 26.6，开发者模式和 DDI 服务可用。安装前通过 devicectl 核对 cn.saydian.ring 为 1.0.0 (1038)，真实截屏为已登录“我的”，不是未保存资料表单。不卸载、清数据、退出账号或改包名。
- 1042 源码先前已通过 Analyze、UTC/Asia/Shanghai 全量各 1159 项、Node 27 项、Python 31 项、Android 原生 39 项、Foundation 合成测试、Android Debug/内部 QA Release 和 iOS 无签名 Debug/Profile 回归。本轮不将这些编译证据当作 iPhone 真机通过。

## 签名构建

- 构建前无本仓库活动 xcodebuild，磁盘约 884 MiB；不清理 SDK、签名、归档或手机数据。使用既有 Xcode 自动签名配置，生产 API https://app.saydian.cn，空 JPush 调试定义。
- flutter build ios --profile --no-pub --build-name=1.0.0 --build-number=1042 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY= 成功，Xcode 30.7 秒，app 67.1 MB。
- codesign --verify --deep --strict 通过，Bundle ID cn.saydian.ring、1042、UIDeviceFamily=[1]；开发签名团队和 application-identifier 匹配，描述文件含当前设备，未采用 App Store 分发 IPA 调试。
- 描述文件有效期经实际核对，get-task-allow=true；Profile app 与 dSYM 的 arm64 UUID 一致。独立留存 .build/1042-profile/Payload/Runner.app 与 dSYM 后才进行后续构建，不覆盖 SDK 原包。
- 随后同源码、同生产 API、同 1042 串行执行 `flutter build ios --debug --no-pub --build-name=1.0.0 --build-number=1042 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=`，成功，Xcode 34.6 秒。签名严格校验通过，包名/构建号/仅 iPhone/描述文件含目标设备/get-task-allow 再次核对一致。该 Debug 包仅准备就绪；因设备已断连，未覆盖安装或附加。
- 辅助验证首次尝试将整个 development plist 转 JSON 失败（包含 JSON 不支持的 plist 对象），改用 PlistBuddy 定向读取包名、构建号、device family 和签名必要字段；不输出证书、设备列表或配对密钥。此工具读取错误不等于编译或签名失败。
- 设备详情、截图、签名描述文件、原始浏览/诊断信息均只在本机 .build 忽略目录；不将真实账号、照片、健康值、设备配对信息或 VM 访问令牌写入 Git。浏览结果原始字段包含敏感配对信息，不再输出，日志权限收紧为 600。

## 安装、启动与检查（按实测追加）

- `xcrun devicectl device install app --device <当前 iPhone> .build/1042-profile/Payload/Runner.app` 和 `device process launch ... cn.saydian.ring` 均返回 success。没有卸载；安装后再次读取设备 App 清单，实际版本为 1.0.0 (1042)，Bundle ID 保持 cn.saydian.ring。
- 未附加 Flutter 的首次 Profile 启动后，进程查询仍确认该进程存活；真实截图显示已有健康记录。只证实旧记录可见，未逐项核对整个数据容器、资料头像或绑定，不能声称全量数据一致。
- 继续第二次冷启动时设备连接中断，终止进程命令失败；后续 processes 返回 CoreDeviceError 1011，devicectl 将该 iPhone 列为 unavailable，pymobiledevice3 usbmux list 返回空列表。可用性故障先按连接中断记录，不凭这一点推断 App 闪退，不卸载、不切换设备或账号。
- 因断连未完成连续三次冷启动、Debug VM/热重载、逐页操作、真实头像上传与戒指专项；这些仍待验。手机现有安装保持为可独立启动的签名 Profile，不把没有调试器的 Debug 留在手机上。
- 本轮未改业务源码。若真机发现需修复的问题，将另记根因、范围、递增构建号和全量回归；真实戒指、照片上传等专项没有执行时仍标待验。
- 本轮仅新增本记录和索引；`git diff --check` 通过。业务源码仍为上述已全量回归的 1042 基线，不将先前 Android 头像真实上传的成功移作本轮 iPhone 验收结论。

## 连接恢复后的续验

- 用户要求“更新”后重新 fetch，当前分支与 origin 一致，工作树干净；业务版本仍为 1042，没有虚构新版本或创建无内容代码提交。磁盘可用空间约 13 GiB。
- iPhone 15 Pro Max 恢复为 available (paired)，查询后为 connected；实际 App 清单仍为 cn.saydian.ring / 1.0.0 (1042)。截图设备页保留 HR01 绑定，显示等待靠近；本轮尚未取得新的握手或测量回包，不能标设备连接通过。
- 未附加 Flutter 的 Profile 用 `devicectl device process launch --terminate-existing ... cn.saydian.ring` 连续重新启动三次；每次等待 20 秒后 `device info processes` 核对该次 PID 仍存活，三次均通过。没有注销、解绑或清理手机数据。
- 严格校验已构建 Debug 签名，包名 cn.saydian.ring、版本 1.0.0 (1042)、仅 iPhone、get-task-allow=true。Flutter 本地实现确认预构建输入支持 .app 目录；首次 run 命令误用 build 专用的 --build-name/--build-number，CLI 在安装前返回不支持选项，随后移除这两个参数，实际版本由已签名 app 保持。
- 修正 run 参数后，预构建 Debug 原位安装/启动耗时 18.4 秒，Dart VM 与文件同步出现，文件同步 354 ms；随后 Flutter 报 Lost connection to device 并结束，未完成热重载或持续 Debug 稳定性验收。该观察窗口没有 Unhandled Exception、RenderFlex overflow、SIGABRT、EXC_BAD_ACCESS 文本，但不能据此排除崩溃或把断连当作通过。
- 用户随后要求排查安卓自动重连，结束本轮 iPhone 界面操作。先重新原位安装独立保存的签名 Profile 1042，并启动；两个 devicectl 操作实际均 success，保留数据，不将需调试器的 Debug 留给用户独立启动。Debug 短时断连根因、头像上传、完整逐页与 HR01 测量仍待后续专门验收。

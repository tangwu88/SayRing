# XR 1275 原位安装与持续真机调试

2026-11-08（Asia/Shanghai）。用户要求把最新 Say Ring 安装到连接的 iPhone XR 真机调试。本轮只安装和接入正常主程序，保留现有数据；没有变更功能源码或苹果分发状态。

## 版本、目标与原位保留

- 开始时当前分支 `codex/connection-cross-model-1275-20261108` 干净，HEAD 为 `139079bcd64186053a1ed8c6d0ecfe9a27412976`。已 fetch/prune 并对当前分支执行 ff-only 更新，结果 Already up to date；没有合入其他产品或 Harmony 分支。
- 新鲜设备清单确认仅 iPhone XR 可用；15 Pro Max 不可用，没有操作它。系统安装列表起始已为 `cn.saydian.ring` **1.0.12（1275）**。
- 使用最终 1275 的正常 `lib/main.dart` Profile 构建，与已上传 TestFlight 的运行源码指纹一致：`0d1d82933bad5209a5ff165a3cebbbb93d4bffc311d100ba46f0b8e14ee6729e`，对应运行源码 `5c70deebbe0363eb80fb81d741f711ad129b6759`。本轮未重复编译或以旧二进制冒充最新修复。
- 安装前再次校验 `codesign --verify --deep --strict`、版本、团队 `W7SXQ4A226`、正常 AOT、无 Debug 内核及最终构建的原生/AOT 哈希。只停止本 Bundle 的精确现存进程，私有备份容器 **126 文件 / 12,560,006 字节**。
- `devicectl device install app` 原位覆盖成功，安装列表核对为 **1.0.12 / 1275**。启动前 Documents、Application Support、本 App Preferences 合计 **71/71 个业务文件完全一致，0 缺失、0 改写**。
- 未卸载、退出或替换账号、解绑、忽略系统配对、恢复出厂、选择新戒指或人工改写提醒/监测设置。物理戒指设置未另行读写验收，不能将容器保留等同于设置回读通过。

## 实时调试与纠正记录

- 使用当前 Flutter 的标准 `flutter run --machine --no-pub --profile --use-application-binary=<已验签正常 Runner.app> -d <XR>`。没有运行默认 `flutter drive`，没有安装测试入口。
- 启动日志先出现设备移除通知，但随后新鲜 `devicectl list devices` 仍显示 XR connected；标准启动继续取得 `app.debugPort`、`app.devTools` 和 `app.started`。未将瞬时列表事件直接认定为 USB 物理断开原因。
- 首次只读账号检查发生在初始化期间，返回 `MissingLiveSession`，未执行账号替换、自动登录或数据写入。等待初始化后重新只读检查成功，当前 session、存储 owner 和健康 owner 对应。
- 使用 `getVM/getIsolate/getObject/getInstances` 只读核对 VM PID，与系统中当前安装路径的实际 `cn.saydian.ring` 进程一致，isolate 为 Resume。最终检查为 `booting=false`、`busy=false`、`appIsForeground=true`，Flutter 首帧已报告。
- 一次额外 PID 连续性检查原先依赖可被运行中启动器重写的本机临时配置字段，报 `KeyError: process`。改为独立读取已核验的系统 App/进程证据与当前 VM PID 对照后通过；这是验证脚本问题，未改 App 源码。
- 首次打开页面请求仅返回 queued，不能当作 DevTools 已打开。随后在内置浏览器实际新建调试标签页，画面明确显示 **Connected app / Flutter native (profile build) / arm64 iOS**，并将标签页保留供用户继续使用。没有改动已有 App Store Connect 标签页。
- 本轮启动器在服务就绪后持续保留 Flutter 主机进程，取消旧辅助脚本的 240 秒自动 detach 行为。交付前 VM 仍有响应、Flutter 主机未结束；不主动 detach 或终止用户要求保留的调试会话。后续手机/USB/系统状态变化仍可能终止会话，不能承诺永久在线。

## 启动后数据与连接状态

- 启动后再次私有复制容器，使用现有只读 SQLCipher 工具在副本中逐条比对原健康记录。解密密钥仅在精确 VM 内存中读取并临时使用，没有打印或保存；读取前后加密文件哈希不变。
- **原 450 条健康记录全部保留，启动后仍为 450 条；0 缺失、0 payload 改写、0 指标/测量日期改写**。没有把数据库正常运行写入等同于数据丢失，也没有把未确认上传当作成功。
- 本轮实时记住的型号为 **SD-RING-R7 Ultra**，`connectedDevice=null`，自动恢复未挂起。没有用户要求选择新目标，因此没有代选旁边其他戒指。仅证明安装、主程序启动、只读数据保留和实时调试通过；R7 Ultra 连接/活动/睡眠同步、R7y 或其他型号自然掉线和后台稳定性仍需分别实测。
- 未操作 TestFlight 内部组、正式审核、销售地区或下载页；沿用此前 1275 已内部可测试的独立交付记录。

## 命令和证据

- `git status --short --branch`、`git remote -v`、`git fetch --prune origin`、当前分支 `git pull --ff-only`。
- `xcrun devicectl list devices`；精确 Bundle 的 `device info apps`、安装路径对应的 `device info processes`；`device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring --source .`；验签后 `device install app`。
- 正常主程序的标准 Flutter Profile 启动及上述四种只读 VM 方法；没有通过 VM 调用 App 方法、写 SQL 或点击手机页面。
- 安装/运行/账号/450 条保留证明与 DevTools 截图位于忽略的 `build/xr-1275-live-debug-20261108-ag414cmk/`；原容器只保存在用户私有 `Library/Application Support/SayRing/device-backups/`。设备标识、账号、密钥、完整日志、鉴权调试地址和数据均不进入公开 Git。
- 本轮没有产品源码变更，不重复已经通过的全量回归，也不把本次调试接通当作新的无线稳定性验收或远端 CI 全通过。

# 2026-09-10 国际媒体相对地址收尾修复

## 基线与范围

- 修改前工作树干净；`git fetch origin --prune` 后 `HEAD == origin/main == b323114ddce6833d5e755da433ba4858befa2785`，ahead/behind 0/0。
- 独立只读复核发现 P2：`/global/media/`、`/global/assets/` 相对地址被仅接受 API 路径的解析器拒绝，而同路径完整 HTTPS 地址可以使用。会出现缺图占位；不是旧域名请求泄漏，线上影响尚未验证。
- 只修复已允许媒体路径的相对地址解析，补充正反向与传输测试。不扩大域名、协议、端口或路径允许范围，不改变蓝牙、服务端、历史数据或健康算法。
- 本轮第一次定位误用了不存在的 `lib/config/global_environment.dart` 和测试文件名，命令失败且未修改文件；按 `rg --files` 定位实际文件后继续。

## 验证记录

- 新增两个相对路径复现：`flutter test --no-pub test/global_network_boundary_test.dart --reporter expanded`，修复前 **23 通过 / 2 失败**，失败恰为媒体与素材相对路径。
- 最小修复只在 `media()` 增加两个既有允许路径的同源解析分支，在 URI 规范化之前检查原始路径，保留 API 解析器限制。
- 扩展编码中文、空格、query、字面/多重编码遍历等用例后首次回归 **27 通过 / 1 失败**：旧路径检查重复调用 `Uri.decodeComponent`，已解码中文第二轮抛出 `ArgumentError`。已检查无 dot/backslash 且不含百分号的路径直接结束解码，避免重复解码；未增加允许域或跳转。
- 再跑同一文件 **28/28 通过**，覆盖相对/绝对对称、单次安全传输、签名 query 保留、API 兼容，以及旧域、错误前缀、fragment、反斜线与编码遍历拒绝。原始 Unicode 与百分号编码混杂的非规范输入仍保守拒绝，未增加额外解析算法。
- `dart format --output=none --set-exit-if-changed lib test`：**137 文件 / 0 改动**。
- 基线 `b323114` 的 GitHub CI `34378886814` 当前 quality 与两个 Harmony 合约任务通过，Android/iOS 仍执行中；不是本次媒体修复的 CI 通过结论。

- 独立只读复核结论：未发现此次变更引入确定的 P1/P2 或安全回归；没有放宽原点、端口、API 路径或重定向限制。
- 完整 `flutter analyze --no-pub`：**0 issues**。
- `TZ=UTC flutter test --no-pub --reporter expanded`：**809/809 通过**，约 47 秒。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：**809/809 通过**，约 38 秒。
- 本次仅改 Dart 媒体解析与回归测试；此前同轮 Android 原生 **16/16**、日志源码测试 **8/8**、Harmony 宿主合约双时区各 **481/481** 结果保留，不当作本次 iOS 编译或 SDK 运行日志合格证明。

## 构建、安装与联合验收边界

- 普通入口 `lib/main.dart`，`flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64`；显式设置 `SAYDIAN_API_BASE_URL=https://app.saydian.cn`、`SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update`、空天气密钥，不启用本地 API。Release 显式 `SAIDIAN_ALLOW_QA_RELEASE=true`。
- Debug **16.5 秒成功**；QA Release **55.3 秒成功**。现有 Kotlin 迁移/插件提示仍保留，不改无关依赖。
- 两包签名验证通过，证书 SHA-256 均为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`，与此前手机安装包相同。版本仍为 **0.1.21 / 1003**，包名 `cn.saydian.app.global`，名称 **Saydian**，两种 ARM ABI。仅内部 QA，不是商店正式包。

最新产物位于忽略目录 `build/joint-qa-20260909/`，与前一检查点文件分开，避免覆盖证据：

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `Saydian-global-0.1.21-1003-media-debug.apk` | 185303339 | `015356b4c30b4ff5168df13c295a96434c970cb49d89fd2175c7c366a3f83fe8` |
| `Saydian-global-0.1.21-1003-media-qa-release.apk` | 68157960 | `b3d1d7d48f2a10c746add0b0e0ca17ad0ac01cf004527e842421b02c88e36ec1` |

- `adb install -r` **Success**，按现场安装器再次确认两个“继续安装”；没有卸载、清库、恢复备份或修改手表设置。
- 手机 `base.apk` SHA-256 与上表 Debug **完全一致**。`am force-stop` 后正常 Activity 冷启动 **Status ok / LaunchState COLD**；当前进程缓冲区 **0 fatal/ANR 标记、0 自动 QA 标记**，登录页显示服务暂时不可用，不误报网络故障。
- 冷启动捕获 6 条脱敏网络事件，带响应状态的更新清单/能力/内容均为 `app.saydian.cn:443` HTTP404，requestId 分别为 `5ebd1aea-6565-4491-9b6e-9a49f0a3c39e`、`7379ca0d-4e4d-4f18-952a-4516f4ac6c7c`、`202e6301-4100-4515-a589-ffea47a839bf`。这只覆盖已观测客户端路径，不代表闭源 SDK 出站已全量抓包。
- 独立 HTTP 复查：`/global/health/ready` 404（`bc5c6b12-1fb1-438b-a1b4-3eba42ee803f`），`/global/api/saydian-app/v2/auth/capabilities` 404（`1bb31c4f-433b-4810-8207-28575199859c`）。服务端独立仓库工作树干净、分支已同步，提交 `4bf44bd9c9d5cc33a775d317cc7227740a249f45`；不能将服务端源码/镜像构建成功等同部署成功。
- **整体联合验收仍未通过**：国际服务部署和专用测试账号尚未就绪；厂商运行时日志隐私问题、原生出站、其他型号、权限/恢复矩阵及云端回读等仍未关闭。此前 W9 三轮设备侧连接与同步证据保持有效，此次媒体修复未改蓝牙，不虚报重新完成三轮硬件测试。
- 服务器缓存清理待用户明确确认，私有镜像拉取也须由服务端任务解决；未转移 GitHub 凭据、清理服务器或触碰生产数据。上述部署阻塞不通过回退旧域或本地服务规避。
- Git 仅纳入本轮 5 个源码、测试及脱敏 Markdown 文件；`git diff --check` 通过。原始日志、截图、安装包、私人备份与实际设备标识不入源码库。交接先更新远端、读本记录及联合覆盖矩阵，再继续验收。

旧轮次失败与真机边界保留在联合验收记录中；最终 Git 提交号及远端 CI 状态以交付时实际核验为准。

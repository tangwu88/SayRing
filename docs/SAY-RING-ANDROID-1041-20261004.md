# Say Ring Android 1040 真机巡检与 1041 日期修复

## 基线与范围

- 基线 bc1225506c6241c0973a62bd6c9b9b519990d19c，当前分支 codex/macos-update-20260930；修改前 fetch/ff-only 无更新、工作树干净。仅 Say Ring，不操作其他 App 或现有 iOS 审核。
- 华为 PPA_LX3、Android 10，USB 调试已授权。1040 Debug 通过 install -r 覆盖；用户安装确认页显示未发现风险，继续安装后返回 Success。firstInstallTime 不变，旧登录、绑定和历史健康记录仍可查看；未卸载或清空数据。
- 1040 启动后进程存活、前台为 cn.saydian.ring，Flutter attach 返回有效 VM 服务。完整日志、真实截图、健康值和 VM 地址仅在忽略目录，不进入 Git。

## 1040 页面观察

- 首页“健康数据”标题不再截断，日期独立显示，“全部数据”入口保留；睡眠概览与详情同日总时长一致。
- 保留的 R21_4F5F 自动进入 SDK 连接并返回电量，无需点击连接；已连接设备页不出现“重新连接”。本次不是三轮真实距离断连验收。
- 观察到自动同步进度；一次手动同步由读取、进度恢复为可操作按钮且连接仍在。未捕获短暂的终态 Snackbar，不能据此证明全部指标完成或“暂无新增数据”分支已通过。
- 健康百科分类与三篇后台中文文章已返回。真实睡眠阶段图与旧记录仍可读。手机时区为 America/New_York，页面按记录时区显示；没有擅自改时区或旧时间戳。

## P2 问题与修改

- 复现：进入健康百科，文章下方发布日期直接显示完整 ISO 时间字符串。预期为可读日历日期，实际带 T、小数秒和 Z。
- 根因：ArticleTile 仅将数字按秒格式化，字符串未经解析直接作为文字显示。仅修改 lib/ui/pages/content.dart 的展示转换，不改接口、文章原始字段或正文。
- 兼容 ISO/时区偏移、DateTime、旧秒时间戳与毫秒时间戳；统一本机日期格式 yyyy-MM-dd。无效、缺失及超出 DateTime 范围的时间不显示，不编造当前日期。字段优先级仍为 publishedAt、createdAt、created_at。
- test/global_localized_pages_test.dart 增加 9 项：跨午夜本机日期、秒/毫秒及字符串、异常值、字段优先级、窄屏、点击和原始字段不变。

## 检查记录（持续追加）

- 定向文件 35 项通过；Node 原生/打包契约 27 项通过。格式化两个修改文件成功。其余全量、双端构建及 1041 安装以实际结果追加。
- 只读搜索曾使用不存在的日期辅助文件/通配符和错误的脚本名称，被 shell 或 sed 拒绝；未改文件，改用实际 content.dart 和现有测试文件。
- 旧 attach 会话标准输入已关闭，尝试 h 返回 stdin is closed；未发送 q、未据此认定 App 崩溃。仍以实际进程、前台和 attach 日志验证当前状态。
- 构建前磁盘约 1.7 GiB，需保留现有 APK、iOS 产物和符号，再用项目正常 clean 任务释放可重建输出；不删除 SDK、源码、签名或手机数据。
- 静态检查零问题；UTC 全量 1155/1155（93 秒）、Asia/Shanghai 全量 1155/1155（80 秒），格式检查 204 文件零修改；Python 发布测试 31 项、bash -n、shellcheck、actionlint 通过。两个 Foundation 测试均 PASS，使用合成输入，不是实物验收。
- 全量结束后确认无本项目活动构建；另一个 Flutter 测试的 cwd 属于 Health App，未终止它。独立留存 1040 两份 APK、无签名 iOS Debug/Profile app 与 dSYM、最终 iphoneos app 及 build/reports，gzip 完整性和原 SDK/APK SHA 回读一致。正常 flutter clean --scheme Runner 完成，删除仅可重建 build、.dart_tool 和 Flutter 生成配置，空间约 1.5→4.1 GiB；手机进程仍存活，源码/SDK/签名和原位数据不变。可重建目录可重新构建，旧 app 与符号可从忽略目录归档恢复。
- 后续只读截图发现手机进入个人资料编辑页，未点击保存、返回、退出或其他输入，暂停主动 UI 和覆盖安装，继续构建以避免丢失未保存编辑。
- 离线 pub get 成功，pubspec.lock 无变化；按手机 America/New_York 时区定向 35 项再次通过。1041 Android Debug 67.5 秒、内部 QA Release 159.3 秒成功，Release 后 Debug 8.9 秒成功，未关闭不可变缓存校验。
- 两包 cn.saydian.ring / 1.0.0 (1041)、ARMv7/ARM64、与 1040 相同本机 Debug 证书；签名、ZIP 完整性及 16 KiB ZIP 对齐均通过。Debug SHA-256 c7f716c0dde81c57d2559b2f3cae0ebada9254d5580ec6e255b71cb510e74c09，QA Release d9607c3fdbae8253dc703ff80d549c222c0a7bb8acf769512a9871e1cec64d69。QA 包不是正式分发包，未上传应用市场。
- Android 原生 8 个 suite 共 39 项，零 skipped/failures/errors；Gradle 单测及实际 releaseRuntimeClasspath 16 秒成功。QA ABI 门禁通过，仅采用锁定 JPush/JCore 的既有 libjutils ARM64 例外。原 SDK 构建副本 30 条目逐一检查通过，只有两条 consumer 映射输出规则被移除。
- 空间降到约 535 MiB 后暂停开始 iOS 构建；先核对两份独立 APK 与源输出字节一致、归档 native XML/符号/映射/manifest 日志/SDK 构建副本，再运行本项目 :app:clean。保留失败或警告日志，不清全局 Gradle 缓存或其他项目。

## 未通过或待验

- AI 报告终态、真实充电插拔、三轮距离恢复、CoolWear 实物及原厂数据核对、两账号关爱撤权、真实头像上传仍需独立验收。本轮没有代用户授权上传、生成新 AI 报告或执行破坏性设备操作。
- 1041 构建/安装及日期正文回读尚未完成，不将 1040 或组件通过当成 1041 真机通过。

## 1041 构建终态与后续任务

- :app:clean 3 秒完成，空间恢复约 2.8 GiB；iOS Debug pod install 34.1 秒、Xcode 编译 31.9 秒成功，Profile Xcode 59.1 秒成功。实际 cn.saydian.ring、1041、UIDeviceFamily=[1]、arm64，均无签名编译，未安装 iPhone或送审。
- Android 1040 最终日志没有检索到 FATAL EXCEPTION、E/flutter、Unhandled Exception 或 RenderFlex overflow；rg 无匹配 exit=1 不代表构建/测试失败。进程和 attach VM 仍有效。
- 用户随后报告资料编辑错误，优先切入 [1042 头像地址兼容修复](SAY-RING-PROFILE-1042-20261004.md)。1041 未覆盖安装，手机资料编辑状态仍保留，不以组件或已安装 1040 冒充 1041 真机通过。

# 客户端整理与源码交接：1060

## 范围与基线

- 2026-10-05，用户要求整理代码、提交推送 Git，并附交接包及说明；仅 Say Ring。
- 基线 `56fe18be4bb3ec8f486601c905aee67bdda4175c`，当前分支 `codex/macos-update-20260930`；工作树干净，fetch / ff-only pull 已最新。
- 不改变包名、图标、登录/绑定/健康数据、SDK、服务器配置、商店审核或现有 TestFlight。

## 修改

- `prototype_pages.dart` 原 6203 行，机械拆为 9 个 `part` 功能模块，兼容入口 54 行；类名、导入 API 和私有成员库关系不变。
- 关于页与正文读取统一复用 `plainTextFromHtml`，去除同实现的重复函数，不改变输出。
- 页面源码审计改为读取完整 Dart 库或明确功能分部，新增页面保留、模块数量及共享文本工具的契约检查。
- README 更新为 Say Ring 当前入口、设备边界和开发导航；历史国际版说明不作为现状，原版本仍可从 Git 查看。
- 新增安全源码打包与离线导入工具：只包含当前分支可达 Git 历史及已跟踪文件，SHA-256、原提交校验、拒绝覆盖；异常不自动清除目录。
- 包仅供授权开发者交接；快照敏感路径/明显密钥检查不是完整历史安全审计。原始 SDK 和图像未改写，不删除已有功能或依赖来伪造减包。

## 失败、修正与验证

- 初次机械生成分部时相对路径落在工作区父目录，立即移至准确仓库位置并删除本轮误建的文件；未触碰用户原素材。
- 同一文件的 Delete/Add 合并补丁被工具拒绝，改为逐步执行；未丢弃旧 Git 源码，全部分部保留并经回归验证。
- 首轮 `flutter analyze --no-pub`：无问题（5.3 秒）。其余验证结果按执行顺序如下。
- 交接工具初次测试发现 macOS `/var` 与 `/private/var` 路径别名导致目录内输出拦截失效；统一真实路径并增加目录符号链接测试。复查离线导入、已有目录保护、损坏文件拒绝全部通过。
- 原型实现按原模块顺序重新组合，排除共享函数重命名和格式化空白后，与基线内容比较完全一致（`normalizedPrototypeSourceUnchanged=true`）。该检查不替代页面测试。
- `TZ=UTC flutter test --no-pub --reporter compact`：1197 项通过（2 分 47 秒）；`node --test tool/test_*.mjs tool/*.test.mjs`：119 项，118 通过、1 项 Windows ACL 平台跳过。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：33 项通过（11.435 秒）。Foundation 编译并执行连接、相机、记录映射及 CoolWear 策略四个程序均通过；均为合成输入的主机检查。
- 低磁盘下精确缓存删除命令被执行工具拒绝，未执行删除；完整 UTC 测试结束后确认 build 无活动占用，改用 `flutter clean`。保留 `.build` 的旧安装包、证据和私有容器备份，空间从约 0.5 GiB 恢复到 6.6 GiB；被清理项可由编译重建，不是资料或健康数据。
- `flutter pub get --enforce-lockfile` 恢复依赖成功，不升级锁定包；`sh -n`、ShellCheck 和 `git diff --check` 通过。清缓存后的回归/构建在下文追加。
- 清缓存后上海时区完整 Flutter：1197 项通过（58 秒）。Android `JAVA_HOME=…temurin-17… ./gradlew :app:testDebugUnitTest`：35 秒，11 套 / 51 项，无失败、错误或跳过；XML 位于 `build/app/test-results/testDebugUnitTest`。
- 最终 Node 全套 119 项中 118 通过，Windows ACL 1 项平台跳过；清缓存后静态分析无问题（2.9 秒）。Git 当前分支文本历史约 20 MB 未检出所检查的明显私钥/令牌模式；这不是完整安全审计，也不据此宣称历史已做彻底脱敏。
- iOS Profile：87.1 秒成功，1.0.0 (1060)、`cn.saydian.ring`、`UIDeviceFamily=[1]`，strict codesign 通过；本地未压缩 App 60.1 MB，不代表商店下载体积或减包比例。
- 独立保留 `.build/1060-profile/Runner.app` 及 Runner / App 的 dSYM；`dwarfdump --uuid` 逐项一致。SDK 的 Swift Package Manager / 微信模拟器 arm64 警告保留，不据此删 SDK 或声称模拟器通过。
- iOS Debug 串行构建成功（53.5 秒），strict codesign、1060、包名及仅 iPhone 再核对通过；未安装或启动手机 App。
- Android Debug 成功（34.4 秒）；KGP 插件未来兼容警告保留。QA Release 成功（95.6 秒、69.5 MB），APK v2 签名通过，1.0.0 / 1060 / `cn.saydian.ring`、arm64-v8a 与 armeabi-v7a 核对通过；不是正式市场签名。
- QA APK 单独保留为 `.build/SayRing-1.0.0-1060-QA.apk`，SHA-256 `3437dfc8c57ec8d8b3ece38fb34804ddbb0a43176bbacda177e1e8153aeb12cb`。未上传、安装或混入源码交接 ZIP。
- 最终静态分析无问题（6.6 秒）；`dart format --output=none --set-exit-if-changed lib test`：219 文件、0 改动；最终 Node 119 项中 118 通过、1 项平台跳过。
- 打包工具增加 Say Ring 双端标识校验、源码目录内输出拦截及打包期间源码变化检查。测试同时覆盖目录别名/符号链接、看似父路径的内部目录、损坏包、原目录保护和错误产品拒绝。
- 为交接验证腾出空间，已核对并单独保留 Profile、匹配 dSYM、QA APK；构建完成且 build 无占用后再次清理可重建缓存。原 1059 包与私有备份继续保留，手机和服务器不操作。

## 最终交接验证流程

提交后的干净源码使用 `node tool/handoff/create_source_handoff.mjs REPO NEW_OUTPUT` 生成包。
从 ZIP 而不是打包源目录重新解压，运行 `unzip -tq`、SHA-256 与 `IMPORT.sh` 校验。
再核对提交、完整已跟踪文件、Git fsck，并在独立目录执行锁定依赖恢复、静态分析及交接工具测试。
最后一轮的准确提交、ZIP 哈希与导入结果另随包提供验收说明；不要修改包后沿用旧哈希。
- 本轮不执行手机安装/解绑/清库；主机回归不代替新的实物验收。磁盘余量初始约 1 GiB，构建空间限制及处理如有发生须记录。

## 交付与未完成边界

交接入口：[开发交接说明](SAY-RING-DEVELOPER-HANDOFF-20261005.md)。最终 ZIP 的准确源码提交与分支以包内 `COMMIT.txt` / `BRANCH.txt` 为准。
包体积属于交接源码压缩包，不是 App Store 下载体积；本轮不承诺安装包缩小。
现有实物待验继续保留，不把文件整理计为修复全部蓝牙、OTA 或 AI 供应商问题。

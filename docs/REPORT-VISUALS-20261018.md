# AI 报告图形展示

## 范围和基线

用户确认两种 App 报告和总后台都优化。仅改变报告阅读呈现，保留原登录、产品门禁、独立说明、上传确认、轮询和账号代次检查，不改设备、健康值、评分算法或既有商店审核。

- 固定基线 `741d83f4d7e6b6d8f1cfbb8d5e99bc602737a4ce`，独立 `codex/report-visuals-20261018` 工作树，原有目录和会话保留。
 - Say Ring fetch 成功，origin/main 与本基线一致。

## 修改计划

- 新增只读图表组件：AI 参考评分环、有效睡眠时长/醒来次数、真实阶段占比、健康指标均值与每日趋势、编号建议卡片。
- 图形只读取既有报告授权接口新增的可选 visuals 快照；不读取其他账号、不上传更多数据、不额外请求 AI。旧服务无 visuals 时保留正文；未知不补零，稀疏日期不连成连续曲线。
- 两种 App 的通用报告页复用一致组件；Say Ring 专用睡眠页保留原生成/同意/重试与撤回流程。
- 预期：窄屏和大字体可阅读，图形旁保留文字/数值，AI 分析与记录值分开。

## 验证记录

以下逐项追加实际结果；未执行项不标为通过。App 安装和商店发布与源码/编译验收分开。

- 离线锁定依赖解析成功。首次 analyze 两条括号风格提示及图表大字体溢出/Material 背景警告均保留，已修复；第二次分析零问题，Say Ring 定向 31 项、国内版图表 3 项通过。评分文本和非设备评分说明兼容原有睡眠流程测试。

- 2026-10-18T06:04:06.129958+00:00 `TZ=UTC flutter test --no-pub --reporter expanded` exit=0 (39.4s).

- 2026-10-18T06:04:41.976327+00:00 `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded` exit=0 (35.8s).

- 2026-10-18T06:10:40.812010+00:00 `/Users/saydian/develop/flutter/bin/flutter analyze --no-pub` exit=0 (2.4s).

- 2026-10-18T06:10:53.927624+00:00 `/Users/saydian/develop/flutter/bin/flutter build ios --debug --no-codesign --no-pub --build-name=1.0.2 --build-number=1110 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn/global` exit=1 (13.1s).

- 2026-10-18T06:12:34.029518+00:00 `/Users/saydian/develop/flutter/bin/flutter build ios --debug --no-codesign --no-pub --build-name=1.0.2 --build-number=1110 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn/global` exit=0 (30.5s).

- 2026-10-18T06:13:19.407751+00:00 `/Users/saydian/develop/flutter/bin/flutter build ios --profile --no-codesign --no-pub --build-name=1.0.2 --build-number=1110 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn/global` exit=0 (45.2s).

- 2026-10-18T06:14:13.452029+00:00 `/Users/saydian/develop/flutter/bin/flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.2 --build-number=1110 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn/global` exit=0 (54.0s).

- Android debug QA artifact: package/version, ARM32+ARM64 and APK signature verified; SHA256 3efaaf14dd4270377270865a6d814fda1315f2c64239d07a726631d5409e2d29. Not installed or published.

- 2026-10-18T06:16:56.475705+00:00 `/Users/saydian/develop/flutter/bin/flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.2 --build-number=1110 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn/global` exit=0 (88.0s).

- Android release QA artifact: package/version, ARM32+ARM64 and APK signature verified; SHA256 3cbd2a91368f5a0b716348703d3ad5198fd6f2be2624d9671b77c6bb410f0bfd. Not installed or published.

- 双时区全量各 1267 项通过；最终 analyze 零问题。首次 Xcode 27 编译因工程既有 iOS 13 最低目标失败，仅使用本任务忽略目录的 min15 xcconfig 进行无签名 QA 编译，未修改工程/Pods 支持范围：Debug 30.5 秒、Profile 45.2 秒成功，包名 cn.saydian.ring、1.0.2（1110）核对。无签名编译不能用于直接安装或代表发行验签。
- Android 双 ARM Debug 54 秒、内部 QA Release 88 秒成功；两包包名/版本/ABI 和 APK 验签通过，Release 仍为 Android Debug 证书的 QA 包，未对外发布。第一次证明脚本因系统 Python 无 hashlib.file_digest 中断，APK 构建已成功；改用流式 SHA256 补验后继续 Release，没有重写为构建失败或用旧包替代。
- 本轮没有安装手机、替换商店包或操作审核，实际设备阅读效果仍待新版本安装后确认。

- `python3 -m unittest discover -s scripts/release -p test_*.py` 通过：发布门禁均为合成夹具，不表示调用了日志中的旧 API、上传正式包或修改分发配置。

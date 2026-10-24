# 2026-10-24 今日活动热量单位保护修复

## 原因、基线与范围

用户在只读排查后要求修复。P1：同一只R7 Ultra首页今日活动显示异常偏大的千卡值，进入详情仅1条记录/1个点；预期只将已确认单位的热量用于千卡统计，实际原生K6_Sport整数被无条件标为kcal。具体换算倍率仍未查实，本轮不猜除数或热量算法。

修改前git status/remote及fetch origin --prune成功，工作树干净；HEAD和所跟踪开发分支均为0e79810f9e48fb5d0723642b2085bf34adeea1f5。origin/main为0e350063d727678b2dab8d9e61abf8edec51fd11，不合并/推广未验收main。已阅读AGENTS、国际交接、最新1137实施/真机及热量排查记录、跨端复盘与回归清单。E:\saydian h5另有用户已有改动，本轮不触碰该工作树或后台。一次上游merge检查发生在编辑后，结果Already up to date、没有合入任何变化；不能记作修改前执行了干净快进。

## 实现与数据边界

- lib/domain/health_record_units.dart：CoolWear wearable v1原始热量（包括旧版误标kcal、缺少可选app/category元数据）进入统一单位待确认保护；该来源显式未知单位也不转成kcal。保持已有QRing保护、已换算Android QRing及其他厂商来源不变，不使用数值阈值或机型黑名单。
- android/app/src/main/java/cc/saidian/saydian_app/CoolWearRecordMapper.java：新日活动热量保留SDK原整数，unit改为unknown；不改变版本、时间、稳定记录ID、步数、距离、SDK同步行为或单独运动记录协议。
- 复用既有首页/运动今日活动、健康卡片、日周月趋势/记录和分析的同一保护函数，不复制页面专属除数。仅暂停未经证实的kcal显示/目标/统计；原始记录及来源保留，不清库、不补零、不迁移历史或伪造正确热量。
- test/calorie_unit_safety_test.dart：旧/新单位、零/小/大合成计数、日周月及前期对比、可选元数据缺失、原始JSON不变、其他指标/来源不误伤。
- test/qring_dashboard_visual_test.dart：CoolWear旧/新记录在332dp及200%大字仍保留步数，热量显示单位待确认、目标环不计入原值；详情保留记录但无伪kcal图表/数值。所有值均是合成夹具，不提交真机健康数据。
- CoolWearRecordMapperTest.kt：原始计数不缩放，unit未知、来源版本保留，重复映射及旧误标kcal记录ID不变，避免单位修正导致重复历史。

## 过程与验证

- 初期Windows rg命令把通配符作为路径及猜测不存在的趋势测试文件，返回路径错误；改用rg --files和--glob发现实际文件。未删除或修复无关文件。长输出截断后分段补读所需规则。
- dart format仅本轮3个Dart文件：2个格式化、1个无变化；定向Flutter热量安全和首页/趋势27/27通过（含新旧CoolWear6项页面及2项策略测试）。
- 后续静态检查、双时区全量、Android Debug/QA Release、原生测试及发布工具门禁实际结果续记。当前不将待执行项写成通过。

### 已完成回归

- Git外Run-Checks.ps1的targeted/analyze/utc/shanghai阶段分别执行flutter test --no-pub test/calorie_unit_safety_test.dart test/qring_dashboard_visual_test.dart --reporter expanded、flutter analyze --no-pub及TZ=UTC/Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn。定向27/27、analyze零问题、两时区全量各1450/1450通过。
- Node --test tool/test_coolwear_android_sync.mjs tool/test_qring_monitoring_integration.mjs tool/test_coolwear_ios_integration.mjs：21/21通过；python -m unittest scripts.release.test_release_gate.ReleaseGateTest scripts.release.test_release_gate.PushConfigTest：23/23通过。这些是合成/源码门禁，不是实际云端联调或iOS编译。
- flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.6 --build-number=1138 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true：成功，assembleDebug约235.3秒。既有插件Kotlin迁移/厂商deprecated警告保留，未为本轮单位问题扩大工具链升级。
- 只读复核本地后端HealthRecordInputContract.unit为可选string，未新增接口字段；这不是线上未知单位上传验收，也未实际上传或修改后台。
- 原生:app:testDebugUnitTest和显式SAIDIAN_ALLOW_QA_RELEASE=true的Release编译正在执行，结果稍后续记。

### 原生回归结果

android目录执行gradlew.bat :app:testDebugUnitTest --no-daemon --max-workers=1成功，约3分19秒；读取本次JUnit XML为14个suite、60项、0失败/错误（mapper 8项含新增稳定身份用例）。测试确认新记录保留原始整数和未知单位，旧kcal标记记录与新记录ID一致，不把单位修正当新历史。Release编译仍未完成，此处不提前记为通过。

### 编译及交付核对

- 显式SAIDIAN_PRODUCTION_RELEASE=false、SAIDIAN_ALLOW_QA_RELEASE=true执行flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.6 --build-number=1138 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true成功，assembleRelease约355.1秒。apksigner verify通过且证书明确为Android Debug；aapt核对cn.saydian.ring、1.0.6(1138)。这是QA编译验证，不能冒称正式签名包或上架包。
- QA副本仅保存在Git外E:\SayRing-calorie-fix-20261024\SayRing-1.0.6-1138-QA-NOT-FOR-DISTRIBUTION.apk，SHA256=B197E62967DAC5444C2DE23DF444A1BA71380CD3BD4DD2188067D22409AB61CA；未安装或上传。android/key.properties不存在。既有1137正式归档和手机安装不变。
- git diff --check通过；提交前再次fetch成功、HEAD与所跟踪远端仍0/0，无新远端冲突。只暂存本轮7个明确文件，不含构建、私有证据或其他后台改动。可选gh命令在本机未安装，未把该工具缺失计为编译失败，也不宣称远端CI/iOS已通过。远端推送和实际SHA以提交后核对为准。

## 未验收与发布边界

厂商K6_Sport.calories单位及倍率仍需明确契约/校准；本轮修复的是错误单位展示和统计，不是声称恢复准确热量。Windows无Xcode，不能执行iOS Debug/Profile和原生实机验收；共享Dart保护并不代表iOS已发布。鸿蒙无该戒指原生SDK，不新增猜测接入。

本轮不改后台接口、生产配置或上传授权，不卸载/安装手机，不解绑/重置/清历史，不发布商店/下载清单。Android Release若执行为明确QA编译验证，不是可上架正式签名产物。Git仅显式提交本轮文件与日志，推送当前开发分支；最终SHA、检查结果和远端核对续记。

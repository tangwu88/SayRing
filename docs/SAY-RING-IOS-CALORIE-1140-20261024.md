# 2026-10-24 iOS 1140 历史热量保护与真机验收

## 授权、基线和范围

用户要求优先修复热量，连接的iPhone真实测试通过后才上传TestFlight并提交苹果审核。基线007fee9b5b53096b5610e8201ef53c1ef630b04e；开始时工作树干净，origin fetch后pull --ff-only返回Already up to date。仓库SayRing保持Public；新开发分支codex/ios-calorie-1140-20261024，不推广未验收main。已复核AGENTS、国际交接、回归清单、复盘、1139及1138实物失败记录。1139对应远端CI 40096081222本轮读回completed/success，只证明旧候选宿主CI，不替代本轮修复或实物验收。

## P1问题与真实来源

预期：未知量纲的原始计数不能当作千卡或进入目标/趋势；实际：1138正式Android实物仍显示异常值，旧保护要求wearable及可选vendor字段，真实旧记录可能绕过。

Mac本轮检测到iPhone XR在线、已解锁。先以devicectl copy from备份本App容器到Git忽略的700目录，严格验签明确Profile二进制，经tool/drive_ios_preserving_data.mjs --keep-app-running执行两次只读元数据探针；每轮均备份后容器、原位恢复普通1139并启动，未卸载、解绑、切账号或清数据。两轮探针和恢复命令均0。仅输出协议元数据/计数；真实健康值、ID、时间、账号及所有原始截图/容器留私有目录。

第一轮138条旧热量v3/kcal记录vendor不在已知集合，均pending=false；第二轮明确vendorEmpty=true、qringId=true、activityV3Id=true、qringDevice=false、ringApp=false、ringCategory=false。由记录自身原生版本化ID识别来源，不能凭当前连接型号或数值猜测。另读到2条CoolWear v2步数、178条旧v3步数、7条旧v2睡眠；这些是历史计数，不代表当前绑定戒指本日活动或昨夜睡眠已同步。两轮hasSession=true、原owner/target不变，connectedToRememberedTarget=false。

## 修改

- lib/domain/health_record_units.dart：仅热量且非手动输入，先尊重显式vendor；缺失时使用持久化scoped deviceId，或rawVersion=3且精确qring记录ID协议前缀。云端缺measurementSource仍保留imported，但沿用已知SDK单位保护。保留已确认Android v2和其他厂商来源；不改ID、单位、原值、历史存储、同步协议、服务端、权限或算法。不猜倍率、不封顶、不按值大小/连接名称屏蔽。
- 统一函数继续供首页目标、活动、健康卡、微趋势、日周月统计、记录和详情使用；未知显示既有“单位待确认”，历史原值保留。该修复不声称已校准厂家未说明的热量倍率。
- 回归覆盖：原始空vendor/匿名deviceId的iOS v3形态、imported云端来源、明确其他vendor优先、非协议ID负例、已确认v2、手动输入、零/小/大计数、原始JSON不变；332dp和200%大字首页目标/趋势；真实云端parser缺measurementSource契约。所有Git夹具均合成数据。
- integration_test/ios_calorie_provenance_test.dart：只读实际历史元数据及保护、真实日期趋势、存储读回一致、睡眠日期导航。integration_test/ios_owned_ring_sync_acceptance_test.dart另独立验证原owner精确戒指握手和完整同步，失败不与历史展示通过混淆。

## 复现与过程

1. 新imported回归先失败（期望true、实际false），其余5项通过。
2. scoped旧记录回归再次失败，加上imported共2项失败；既有5项通过。
3. 只补deviceId fallback时合成61项曾通过，但真实第二轮证据显示deviceId为匿名，因此不是最终修复验收。
4. 将单位夹具改成实物相同的空vendor、缺App/category、匿名deviceId，仅保留原协议ID；页面夹具同样为空vendor和匿名deviceId（仍保留可选App/category），单位及首页/趋势7项失败，证明原始漏洞。
5. 补精确版本化ID后定向61项全部通过。一次apply_patch上下文不匹配没有应用修改，重读格式化后的文件后按实际上下文修正。一次猜测不存在的integration文件名读取失败，改用rg --files找到实际文件；均不是App运行故障。
6. dart format仅改本轮Dart文件，git diff --check通过。尝试以shell内Python写中文记录时遇到stdin编码错误，未写入，改用apply_patch。全量和本轮1140构建/实物结果待执行完成续记。

## 宿主回归完成

- pub get --offline --enforce-lockfile成功；格式门禁通过；flutter analyze --no-pub零问题13.0秒。拆分实物历史核验与连接验收两个integration文件后，均格式化，并重新全项目analyze零问题15.0秒；业务源码及test目录未在全量/原生编译中修改。
- TZ=UTC及Asia/Shanghai分别flutter test --no-pub --concurrency=4 --reporter=expanded，各1465/1465，均35.3秒。定向61项通过不能替代此全量。
- Node工具139项：138通过、1项Windows专属跳过、0失败。Harmony两时区各518/518。Python scripts/release discover为35/35。均是宿主/合成门禁，没有因此宣称鸿蒙戒指SDK或真实正式发布通过。
- Android Debug成功10.1秒；显式SAIDIAN_ALLOW_QA_RELEASE=true内部QA Release成功45.9秒，不交付、不发布此QA包。Android原生单测6.2秒，读取build/app/test-results/testDebugUnitTest本次14个suite，60项、0失败/错误/跳过。
- 用户本轮确认暂不在手机旁，要求先完成修复和历史数据验证。故将原戒指完整同步实物用例保留为单独后续验收文件，本轮不再次扫描等待不存在的目标，不将未执行写成通过；TestFlight和审核仍以前置完整验收为门禁。

## 发布门禁

当前未上传1140，未选择审核构建、未提交。若实际戒指/账号条件未满足，继续保留待验收；不得以空态、宿主测试、探针通过或1139 CI替代完整真机通过。不改其他App/销售地区/协议，保留法国已暂停状态。

## iOS构建与XR真实历史验收

串行flutter build ios配置和xcodebuild开发签名：Debug配置21.2秒、编译10.0秒；普通Profile配置20.8秒、编译23.5秒；历史核验Profile配置21.0秒、编译24.5秒，全部exit 0。显式build-name=1.0.6、build-number=1140、target为普通lib/main.dart或明确核验文件。使用原DerivedData，不清除其他构建、归档或容器。

两份Profile均codesign --verify --deep --strict通过，Info为cn.saydian.ring / 1.0.6(1140)，团队W7SXQ4A226、XR在profile中、get-task-allow=true、完整application-identifier正确；geolocator未含requestAlwaysAuthorization。App.framework SHA256：普通cb5197d6fd95a0284e70d154377e59ba881fa02d83b26f3f2ab81e931bb512b5；测试dbf64cc259c449a0f397fec6428ea1b8875616157442d5125ef9657f82d873cb。

经tool/drive_ios_preserving_data.mjs --profile --no-pub、明确--use-application-binary及--keep-app-running运行：driver34.4秒exit 0，实物测试正文约8秒、全部断言通过；后备份0.7秒、原位恢复普通1140 5.3秒、启动0.3秒，均0。不是默认会卸载App的flutter drive，未卸载/解绑/重置/清历史。

- 138条真实旧热量记录协议元数据与修复前相同，pending由false变为true；真实记录而非插入合成样本。对这些真实记录日/周/月分析均无伪千卡点、当前/前期均值为空；所有原始热量payload再次读回与前一致。
- 实际打开一条旧记录对应日期的热量趋势，单位待确认提示出现；私有截图人工核对均值/最大/最小为未知、无伪曲线、仍保留记录数。首页/目标的该来源覆盖由332dp/200%大字回归验证；普通真机首页当天无活动样本，不能说本日实际热量已校准。
- 睡眠页“最近一次睡眠”→上一日“按日期查看”→回最近一次，真实页面和异常检查通过。当前原绑定目标没有最新睡眠样本，hasCurrentTargetSleepSample=false；7条历史记录不属于本轮当前目标的有效夜睡验收，不能把空态或日期导航说成新睡眠同步已通过。
- 原账号和记忆目标未变，connectedToRememberedTarget=false。用户不在旁，独立完整连接/同步测试未执行，本轮没有擅自采用扫描中的其他戒指；不声称当前活动增长、完整历史同步或实际佩戴睡眠通过。
- 恢复普通版后第一次立即截图为黑色，仅launch退出0不能算渲染成功。随后仅对本App执行--terminate-existing冷启动，4秒后截图人工核对首页正常；安装清单再次读回cn.saydian.ring / 1.0.6(1140)。未据此凭空判定长期黑屏问题或抹去第一次观察。

所有原始元数据JSON、日志、截图、备份、APP均只留build/ios-1140-20261024及此前探针私有目录，不进入Git。本轮未归档/导出发行包、未重复已知No Accounts失败流程、未上传TestFlight或提交苹果审核；等原戒指和实际活动/睡眠完整验收后再按用户原授权继续。

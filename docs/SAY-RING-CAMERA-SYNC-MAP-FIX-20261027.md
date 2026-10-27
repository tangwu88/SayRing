# 2026-10-27 整体巡检后续修复

> 后续结论：1146相机实测未通过；1147/1148仅为拦截拍摄的诊断包。用户随后明确要求恢复原相机逻辑。本页临时单次遥控方案已全部撤回，当前实现及正常包交付以[SAY-RING-PAYMENT-SLEEP-20261027.md](SAY-RING-PAYMENT-SLEEP-20261027.md)为准，不能从本页恢复临时限制。

## 范围及基线

- 用户授权按巡检建议处理，保留账号、绑定和所有记录；不重置、不解绑、不删除意外照片。
- 起始分支 `codex/login-camera-r7ultra-1136-20261024`，HEAD `7e23496074da65173908960cff2ada7ffa3887e7`，工作树干净。
- 修改前及交付前重新 fetch：HTTP 代理7897的schannel、OpenSSL、SOCKS代理及直连分别遇到 TLS握手失败/连接重置；GitHub公共API读取也超时。不能据缓存远端声明目前已是远端最新。
- 已阅读 AGENTS、交接、最近实施记录、回归清单和 Android1145巡检。iOS XR 同事的运行会话不操作。

## 问题及处理

1. P1：进入相机后未点快门也连续保存。原自动开启遥控后，SDK 同一 OPEN 回调被持续当快门。改为默认仅预览、显式开启一次遥控、单张消费、30秒有效窗口；退后台/连接变化撤销，不自动重开遥控。原手动快门、相册确认和失败重试保留。涉及 Dart 相机页、面板、快门门禁与 Android CoolWear 回调。
2. 相机 Android 回调也增加连接代次/设备目标、显式遥控开启、命令代次及有效窗口校验，并携带deviceId；断开/释放撤销。Dart消费单张后关闭遥控。保留手动快门和相册保存失败重试。
3. 同步完整性、地图和运动取数继续分别核对；未取得 SDK 终态或单位证据前不得宣称完整/补零/猜倍率。
4. 高德官方坐标转换输入 `|`、输出 `;`，静态图路径样式 `5,0x316EF5,1,,`、尺寸720*320均符合文档，未盲改请求格式。
   文档： https://developer.amap.com/api/webservice/guide/api/convert 、 https://lbs.amap.com/api/webservice/guide/api/staticmaps 。

## 验证记录

- `dart format`：限定相机门禁/页面/面板及对应测试，完成。`git diff --check`通过。
- 定向快门门禁、相册保存、332dp/大字体面板共11项通过。新增真实页面+假平台相机测试：默认预览不发送遥控/不拍照、显式一次开启后多回调只触发一次、发送关闭指令、后台返回不重新开启，通过；该测试不生成实际照片。
- 测试夹具失败及修正：首次漏模拟Android相机权限；随后补控制器初始化以订阅事件、补connectivity插件流、区分帧时钟与真实时钟；异步假设备回调中使用guarded expect导致停止指令被测试异常打断，改为记录调用并在测试主体断言。诊断输出全部移除，生产控制器未改。
- `flutter analyze --no-pub`：首次3项大括号lint，补全后零问题，17.7s。
- UTC全量测试首次因旧契约要求保留“摇动戒指触发拍照”提示而失败，恢复准确动作说明，未削弱契约断言；修复后UTC1490/1490（88s）、Asia/Shanghai1490/1490（96s）。
- Android `:app:testDebugUnitTest --no-daemon --max-workers=1`最终62/62，0失败/0错误（3m18s）；此前一轮3m47s也通过。随后单独生成releaseRuntimeClasspath依赖报告（1m46s）。
- `node --test tool/test_coolwear_android_sync.mjs tool/coolwear_reminders.test.mjs tool/qring_history.test.mjs tool/ring_scan_lifecycle.test.mjs`：8通过、2跳过；两项是macOS原生编译门禁，Windows不能冒充执行。
- Android双ABI Debug构建173.9s、原发行证书Release构建394.4s；1.0.6(1146)，包名cn.saydian.ring，无debuggable，清单/JPush/ABI/16KB对齐及正式证书检查通过。签名SHA256仍为`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`；临时key.properties已清理。
- APK：`E:\SayRing-market-artifacts-20261027\fix-1146\SayRing-1.0.6-1146-release.apk`，72014291字节，SHA256 `558b372ab0224de05a1b7e61b5ef82013821147b5ea41d1efb5e8a1f6959868a`。产物不入Git。
- `adb install -r`：Success，系统“安装成功”；手机实际versionCode1146、versionName1.0.6，首次安装时间未变。拉取实际base.apk后哈希与候选一致；启动Status ok/WARM，健康记录入口和原R7 Ultra绑定仍可见。未卸载、清数据或解绑，不扩大为所有历史逐条验收。

## 地图线上只读诊断和配置复查

- 用户要求发起SSH后亲自在独立窗口输入密码。密码不经聊天、不记录、不提交。通过已认证会话只读检查当前API容器，不修改服务器配置、镜像、数据库或维护状态。
- 第一次容器模块路径按`/app`探测失败ENOENT；确认cwd为`/workspace/apps/api`，改用`./dist/common/`。已说明失败，没有据此重启服务。
- 仅解析`say_ring_map`公开/启用/供应商标志，通过现有IntegrationSecretsService在容器进程内读取Key；不输出/导出Key。测试使用固定公共示例坐标，不使用用户轨迹或健康数据。
- 真实坐标转换HTTP200但业务status0，`infocode=10009`、`info=USERKEY_PLAT_NOMATCH`；根因是已保存Key的平台类型不匹配，并非未保存或轨迹格式。
- 高德官方错误码： https://lbs.amap.com/api/webservice/guide/tools/info 。已向用户解释选择“Web服务”，不是“Web端（JS API）”。
- 用户确认后台替换后，原样复查：坐标转换HTTP200/status1/infocode10000；静态地图HTTP200、image/png、48814字节。未替换其他项目Key或变更服务开关。
- 生产`renderAmapSportRoute`函数以相同固定公共样本直调，实际返回image/png、25433字节、valid=true。手机已保存轨迹页的图片仍另验，不能用provider/服务函数测试替代客户端全流程。

## 1146相机实测失败，停止推广

- 用户准备戒指后，原R7 Ultra重新连接成功，未解绑、清空或重置。相机进入后显示“手机相机”“开启一次戒指拍照”，未通过工具按快门或开启遥控。
- 进入前Say Ring专用图片目录35文件，随后37文件。两个新文件时间15:41:58、15:42:18；用户再次明确没有操作手机。已立即退出相机，文件保留，不查看照片内容、不删除。
- 因此1146 **零误拍未通过**，上方自动测试与构建通过不能替代此实测。禁止把1146作为已修复版本推广、推main或上传商店。先前“未再产生照片”的待验说明被此事实取代。
- 一次相机入口语义定位失败，0匹配时工具没有点击；重新读取后使用唯一前缀定位成功。没有盲坐标点击快门。
- 新增显式诊断编译标志`SAY_RING_CAMERA_DIAGNOSTICS`：默认false；仅诊断候选true，在`camera.takePicture()`前阻止任何拍摄，记录manual/remote结构化来源，不含图像、账号、位置、设备地址或健康值。界面明确显示诊断拦截。1147为原证书诊断候选，不是上架包；待实际追踪。

## SDK复核及厂家所需确认

- 原提供的SDK Guide第8/9节仅描述sendAsynInfo与开启数据传输；没有声明历史结束事件。
- `javap -p/-c`复核原classes.jar的`K6_Action.RCVD`、`IK6AnalysiDevRcvDataManager`、`IK6SendDataManager`及`ProcessDATA_TYPE_DEV_SYNC`：DEV_SYNC解析混合设置，不是历史结束。
- `ProcessDATA_TYPE_SPORT.realProcess`读取原始allItem/item后只返回K6_Sport列表；public回调没有暴露总条数/结束状态，sendMsg对空列表不发送通知。不能把无回调当已完整，也不能仅统计已收到条数补出终态。
- `K6_SEND_APP_SPORT_STRUCT`仅有type/status/time/distance，没有步数或热量；日常K6_Sport与历史K6_Mix_sport_Struct并不构成实时运动累计值契约，不挪用今日累计冒充本次运动。
- 原getCalories整数没有单位/倍率证据，继续保留原值及未知单位。需要厂家说明：①此SDK/固件历史总量与全部结束回调；②R7 Ultra运动中实时步数/热量回调与开始时基；③两种calories字段的单位及倍率。以上仍未修复，不能以UI提示更改宣称完成。

## 未验收

- 新版真机零误拍未通过，须继续修复；主动一次遥控、后台/返回/断线未完成。1147诊断须先拦截拍摄再追踪，不通过实拍重复产生照片。
- R7 Ultra完整同步、实时步数/热量依赖上述厂商协议证据。地图上游错误已定位并由用户更换正确类型Key后通过服务调用；手机轨迹展示另验。
- 用户准备前原目标连接未成功；准备后重新连接成功。未代绑其他设备，相机失败结果以本页后续实测为准。
- Git网络失败，当前不声称远端已同步；源码验证通过后仅提交当前开发分支，不推广main。
- Windows 无 Xcode，iOS Debug/Profile 不可在本机验证。

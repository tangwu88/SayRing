# Windows Android 1128 正式包与覆盖安装

## 用户范围、基线与保护

2026-10-22，用户要求最新正式包并安装当前USB手机。仅构建Android 1.0.5（1128），同签名覆盖安装；不卸载、不清数据、不手动解绑/重新绑定，不触发首次绑定清空/恢复出厂，不做生产OTP、付款或供应商测试。不把提供的锁屏口令写入源码、脚本或实施记录；系统身份验证由用户本人完成。仅新增实施记录和索引，不修改业务源码、服务端、公开下载、市场审核或原正式证书。

起始工作树`E:\SayRing-market-release-20261005`位于`6946bda`，干净；status/remote/fetch-prune成功，1128最新开发分支为`7ffa55e7a9239c9eaf332dfb952cfcb81c270339`。原Windows分支仅多出一项安装文档，与新源分叉，不强合并或覆盖；从最新远端创建`codex/windows-formal-1128-20261022`，完整保留原分支。另一个`E:\SayRing`用户工作树不动。

已读AGENTS、国际交接、回归清单/Bug复盘及最新首次绑定/Android1128记录。首次绑定清理须服务端终身历史判定和明确目标/owner授权，缺少或异常决策不清空；本次安装不是破坏性流程验收。原生初始化读取必须使用项目固定SDK真实getAction/ACTION_READ，不回退旧isRead错误。原Mac正式1128仅作为历史回执，不冒充本次Windows产物。

## 本机流程与当前现场

ADB仅一个已授权在线JAD-AL00，旧包`cn.saydian.ring`、1.0.5（1126）、首次安装时间2026-10-20 10:58:24。沿用原P12/DPAPI身份，生产API和JPush客户端配置、原生商城参数true、双ARM、正常lib/main.dart。Git外包装器复用已验证1126阶段脚本，仅在内存替换产物目录/构建号为1128，全量Flutter并发设4以缩短本机执行；所有Flutter/Gradle阶段仍串行。

计划prepare、analyze、UTC/上海全量、Android Debug、原生/Release依赖、正式Release、验签/Manifest/ABI/16KB，再`adb install -r`。不在Windows重复不可执行的Xcode shell类；运行可执行发布门禁23项。具体命令/结果/失败/安装回执完成后续记，不提前声称通过。签名材料、产物和本机详细日志仅在Git外目录。

## 实际验证续记

- prepare退出0、7.7秒；锁定依赖未升级。analyze退出0、81.8秒（工具内部78.9秒），零问题。
- `TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，1410项全部通过，阶段63.7秒。TZ只用于进程配置，不改Windows系统或手机时间。
- Python可执行`ReleaseGateTest`和`PushConfigTest`23项全部通过；不重复上轮已证实Windows不可执行的Xcode shell类。
- 上海进程配置的同命令全量1410项全部通过，阶段65.2秒。Android双ARM Debug退出0、阶段226.4秒（Gradle213.4秒），仅作回归不安装；保留既有Kotlin迁移警告，不升级依赖掩盖。
- `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`退出0、阶段110.3秒，302任务中10执行/292缓存；独立读取JUnit XML为54项、失败/错误/跳过均0。实际Release依赖报告留存用于ABI门禁。
- 首次读取Node初始化测试时工作目录在scripts/release，返回相对路径不存在；回到仓库根后成功读取。该文件两项Foundation可执行夹具限定darwin，因此本机未执行或冒称通过；原Mac回执仍按既有记录区分，不做实物恢复出厂来替代。

## 本次Windows正式产物

正式Release阶段退出0、280.4秒（Gradle273.2秒）；原P12/DPAPI临时签名配置在finally移除，结束后Test-Path为false。普通lib/main.dart、双ARM、1.0.5/1128、生产API及JPush客户端身份/channel production、厂商通道none、原生商城参数true；没有使用服务端Master Secret或新证书。

冻结文件`E:\SayRing-market-artifacts-20261022\formal-1128\SayRing-1.0.5-1128-release.apk`，72,030,451bytes，SHA-256 `c9493ca0f466d420be7e1e7706ae627acd1ea61ed58c80aa64b977d8f07f5560`。这是本次Windows新构建，不冒充Mac记录中72,030,115bytes的另一产物，也没有上传替换它。

验证阶段退出0、8.4秒。官方apksigner v2通过，证书SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`、MD5 `09d14504fd119ae833b2aaaaeecc13fe`，沿用原正式身份。实际aapt包名cn.saydian.ring/1.0.5/1128、min26/target36、双ARM、非debuggable；zipalign16KB、Manifest/资源表、原生产推送门禁和本轮Release依赖对应ABI门禁均通过。保留JPush6.2.0/JCore5.5.2精确libjutils例外，不扩大豁免。

43个ELF实际检查全部ARM64满足16KB；原ARM32 libDspConfig.so/libEcgAnaly.so仍4KB，不能声称全部库16KB。

## 手机安装过程（持续记录）

正式包核对冻结SHA后，仅对原唯一JAD-AL00执行`adb install -r <1128正式APK>`；不执行uninstall、clear、降级或强授予权限。安装回执尚在等待时，系统仍deviceLocked=1、AOD。尝试正常WAKEUP和上滑，首次只获取普通锁屏截图；后续截图为空文件，view_image明确拒绝，不把空图当有效密码界面。只读UI层级也未提供可确认的密码输入控件，因此没有盲输口令或绕过系统安全检查；已请用户本人解锁和确认安装。该UI阻断不影响已完成的构建/验签，不提前写成已安装。

## 用户确认后的最终安装回执

用户回复已确认，原安装进程返回`Performing Streamed Install / Success`。未取消/重发第二个安装任务，亦未因锁屏改为卸载重装。随后独立系统回读：cn.saydian.ring、1.0.5/1128、min26/target36、无debuggable；首次安装时间仍2026-10-20 10:58:24，更新时间2026-10-22 13:58:11。时间不变只证明非卸载重装，不冒充全部数据库/会话内容已逐项比较。

`am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity`返回Status ok、COLD、TotalTime505ms；真实PID存在，resumedActivity精确为Say Ring，系统deviceLocked=0。仅核对安装、启动与前台系统身份；不测试真实登录/OTP、采样、提醒写入、首次绑定、清空或恢复出厂，不以Activity回执替代全页面功能验收。

构建后fetch成功，源基线7ffa55e与远端开发分支0/0；本轮只提交记录及索引至独立Windows正式分支，保留其他工作树和旧1126记录提交。第一次记录提交为237a439，安装当时尚待用户确认，后续用本段保留实际时间线。未提升main、上传线上包、修改下载清单、后台配置或市场审核。最终`git diff --check`和远端提交核对以实际收尾输出为准。

iOS/鸿蒙本轮未构建；Mac/Foundation夹具和真实戒指清空/恢复出厂验收边界保持原样。首次绑定新能力的服务端部署及真实效果不因本轮安卓覆盖安装而视为已联调通过。

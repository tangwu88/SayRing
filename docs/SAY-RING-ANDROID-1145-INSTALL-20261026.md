# 2026-10-26 Android 1145正式构建与保数据覆盖安装

## 范围与源码

用户要求“安装到手机”。仅重新构建当前已验证源码的正式Android包并覆盖安装，不继续测量/同步调试，不卸载、不清数据、不解绑或重置，不改后台、高德配置、下载清单或商店状态。地图配置按用户要求稍后填写。

已阅读AGENTS、国际交接、修改索引和R7 Ultra后续记录。开始时工作区干净；`git status --short --branch`、`git remote -v`、`git fetch origin --prune`确认当前分支`codex/login-camera-r7ultra-1136-20261024`本地与远端均为`e36f3a19c7fc011b2f276a8c09dd52cb3fa819be`，无分叉或待更新，不切换/提升main。安装前再次fetch核对结果相同。本轮不修改产品源码或依赖。

## 正式构建与验证

- 私有输出目录：`E:\SayRing-market-artifacts-20261026\install-1145`。沿用本机受保护发行脚本及原证书，临时签名配置在构建结束清理；`Test-Path android/key.properties`返回False。没有输出或提交签名密码、私钥。
- 私有包装器`Build-Install1145.ps1`串行执行release、native、verify阶段；复用既有发行门禁，将版本设为1.0.6、构建号1145，依赖使用锁定的离线pub缓存。生产模式启用，QA模式关闭，国际API/更新产品边界及Say Ring独立推送身份保持不变。没有将上一轮debug证书的QA Release包安装或重签充作正式包。
- `flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.6 --build-number=1145`及原发行dart-define配置：通过，assembleRelease 412.2秒。现有Kotlin插件迁移警告保留，不在安装任务扩展修改构建系统。
- `gradlew.bat :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`：通过，2分24秒；本轮没有重新运行原生单元测试。
- `apksigner verify --verbose --print-certs`：通过，v2有效；正式证书SHA256为`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，与旧版一致。
- aapt包身份检查：`cn.saydian.ring`、1.0.6(1145)、无debuggable，arm64-v8a及armeabi-v7a。`zipalign -c -P 16 4`、发行manifest/JPush检查、APK ABI门禁均通过。保持既有受控JPush arm64-only例外，没有新放宽规则。
- ELF审计43个原生库：arm64检查通过；两个既有armeabi-v7a库`libDspConfig.so`、`libEcgAnaly.so`仅4KB LOAD对齐，报告如实保留，不能表述为所有ABI的ELF均16KB兼容。
- 正式文件：`SayRing-1.0.6-1145-release.apk`，72,014,255字节；SHA256为`a06753117f08d738a39abad312ab40ef24374c2e3423e9fe2c3cef22d911f809`。

详细构建、依赖、验签及ELF原始日志均保留在上述Git外目录。本轮未重跑Flutter分析/双时区测试、Android Debug或iOS编译；源码未变，上一轮验证见R7 Ultra后续记录，不将其冒充本轮重新执行。

## 安装过程与实际终态

- 唯一授权手机为Huawei JAD-AL00，安装前1.0.6(1144)。用户按提示解锁；`adb install --no-incremental -r <正式APK>`仅执行覆盖安装，没有卸载或清数据。
- 首个系统安装确认后，华为安全页的继续安装按钮禁用。自动确认守卫检测不到唯一enabled按钮，停止点击并保留失败信息，没有盲点或更改安全设置；请求用户本人完成风险/安装确认。用户随后回复“已安装”。没有操作推荐应用的安装按钮。
- ADB最终明确返回`Performing Streamed Install / Success`。`dumpsys package cn.saydian.ring`核对versionName=1.0.6、versionCode=1145，lastUpdateTime=2026-10-26 13:52:17；firstInstallTime仍为2026-10-24 16:48:38，与安装前一致。
- `pm path`定位实际base.apk并拉取至Git外`installed-base-private.apk`。其SHA256与上述正式产物逐字一致，证明手机实际安装的是本轮正式包，而非仅同版本QA包。
- `am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity`：Status ok、WARM约619ms。实际UI进入今日活动/健康双列首页，仍显示既有登录状态及健康记录。仅核对可启动与页面留存，没有逐字段核验完整数据库，也不声称执行了冷启动/硬件全量验收。真实健康值、用户身份和UI原始文件均留在Git外。

## 未验收与交付边界

- 本轮没有新运动、实时心率、监测周期、来电或支付实测，不把安装成功当作这些功能全部正常。运动步数/热量实时取数与K6_Sport热量倍率仍待厂商证据及实物验收；首页仍保留未知单位提示，未猜算为千卡。
- 高德地图配置仍待用户后续填写；没有启用未配置服务。支付仍由后台实际渠道状态限制，不改维护/只读状态或实际付款。
- 只将本日志与修改索引提交到当前Say Ring开发分支；不提交APK、私有日志、证书、健康信息，不推main，不部署后台。

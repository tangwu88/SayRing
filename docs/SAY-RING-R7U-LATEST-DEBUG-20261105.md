# 同步共享最新代码并续调R7U（2026-11-05）

## 用户范围与同步

用户要求同步最新代码，继续R7 Ultra HRV与手势调试。当前独立App仓库tangwu88/SayRing，原分支codex/r8-gesture-control-20261105，起点ac4fd07，工作区干净，fetch后共享最新7810678。创建codex/r7u-latest-debug-20261105，以原已推送提交为可恢复基线合入共享代码。唯一冲突为CHANGE-TEST-LOG索引，保留双方条目；业务代码自动合并后逐项核对中文链接与R7U重连/配对、R8互斥修复均仍在。

合入周期日记、最新健康提醒和活动卡片源码，不代表线上周期接口/AI服务已部署，也不改生产数据库、下载页或商店状态。继续使用原签名、保数据覆盖，不解绑、不重置、不清除记录。用户确认同一R7U已佩戴连接；手机正常设备页已读回R7 Ultra已连接。R8阶段允许删除的系统配对只针对R8，不能套用到R7U。

## R7U复测边界

HRV必须有真实且明确单位的RRI回包；历史61、实时60与62指令应答分别验收，不将旧45/压力值或原厂生成显示值冒充毫秒HRV。手势需真实模式确认、系统配对与实际输入，不能用命令ACK替代滑动成功。记录原场景，测试后关闭；不因刚解决的R8问题直接删除R7U配对。

合并回归、SDK深入检查、构建与实物结果按实际逐轮追加；Windows无法完成iOS编译，不用源码检查代替。私有日志/构件/设备及健康内容留在仓库外E:\SayRing-R7U-latest-20261105。

## 合并门禁完成

- flutter pub get --offline、flutter analyze --no-pub通过。UTC、Asia/Shanghai各2040项全量Flutter通过；独立周期shadow回归5项通过，Android JUnit103项无失败。
- Android双ARM Debug/普通原签名Release1250通过，1.0.11、cn.saydian.ring、原证书、Manifest/JPush/ABI/zipalign门禁通过；正式APK SHA-256 `797F8BB0B7DC504F5D56B0DBD9D0E064687434DBE1981C9CF6627ECBF479B825`。既有ARM32两个闭源库4KB对齐限制不变，不宣称全部市场认可。尚未安装1250，不将本机代码已合并写成手机已更新。
- Android协议/真实AAR/恢复/相机/手势/隐私初轮40通过、2失败，原因是当前测试进程缺ANDROID_HOME；显式设置为已有Android SDK后原命令重跑42/42通过，无跳过，无修改SDK或放松测试。合并索引冲突只移除三行标记，保留双方所有条目；中文参考链接、新版健康提醒、R7U精确目标重试和配对修复、R8互斥仍在。
- 串行检查本机脚本Invoke-1250-Checks.ps1，prepare/analyze/utc/shanghai/debug/native/release/verify各阶段日志均留在私有目录；Node命令同CI的Android协议列表，另加tool/test_native_log_privacy.mjs。git diff --check与暂存检查作为合并提交门禁。

## 新的SDK对照线索（尚未作为能力开放）

- 同机原厂APK的能力构造器还解析第4字节的触控/手势音乐位，现集成AAR构造器只处理前三字节。原厂GestureConfigV2Activity区分体感与触控命令；尚未证明R7U实际返回该扩展位，不按型号猜能力或启用另一条命令。
- SDK的sendOffOnGensor是原始采集入口；只读DEX调用检查显示原厂相关switchGSensor调用在LifePresenter游戏路径，不是目前手势场景前置条件。没有盲目开启原始运动/PPG采集、写默认配置或把同名函数当根因修复。
- 原厂旧45显示与新RRI结构的区别沿用既有记录。下一步只补类型/长度/扩展位诊断，以区分SDK解析与戒指未返回；不存在有效HRV时不补造数值。

# 注册与忘记密码内置验证码按钮1309

## 范围与基线

- 用户补充：注册页和忘记密码页的获取验证码同样放到验证码输入框内；延续当前安卓登录调整和正式包安装交付。
- 修改前fetch成功，当前分支codex/u19s-android-connect-20261111的HEAD与同名origin均为85c0b7aabcbd1e748dd1a85a26bd1df4fb82b634，工作区干净。前一轮1308已覆盖安装。
- 仅修改lib/ui/global_auth_page.dart的安卓布局：手机号和邮箱、注册和找回密码共用同一右侧按钮，保留原点击、渠道能力、忙碌状态及重发冷却；iOS/Web保持原排列。未改注册/找回/验证码API、协议与年龄确认、6位格式或戒指数据逻辑。
- 不向真实邮箱/手机号发送验证码；不退出账号、不卸载、不清数据。验证后原正式签名1309覆盖当前手机。

## 验证与交付

- 沿用现有登录、注册、找回、协议提示与自动填充回归；这是布局移动，不新增模拟业务测试。静态检查、双时区全量、构建与签名及实际安装状态执行后追加。
- 前轮运行时代码721fc59的云端quality与鸿蒙双时区已成功，Android/iOS编译仍在进行；不将其当成本轮最终源码验收。
- 定向21项通过，包含手机号/邮箱注册验证码、找回原入口、协议未选时的醒目提示和英文窄屏1/1.5/2倍字号；未改变验证码消费或发送条件。静态分析已通过，完整回归进行中。
- 复查前轮1308云端iOS失败日志：停在CocoaPods安装WechatOpenSDK-XCFramework时下载腾讯OpenSDK2.0.7.zip，尚未开始Xcode编译；与安卓按钮移动无编译关联。保留失败，不改供应商SDK/锁文件/CI断言来隐藏网络问题；本轮最终云端状态另行核对。
- format和静态检查通过，UTC与Asia/Shanghai完整Flutter回归各2432项通过。没有新增低影响布局专用测试，复用原有页面/验证码/协议检查。Debug/Release构建及验签正在进行。
- 本轮无原生或依赖改动，ABI检查使用本机1308原生134项通过时的releaseRuntimeClasspath作为不变对照；不把该复用记录写作新一轮实体蓝牙测试。无iOS本机Xcode环境，上一轮云端微信SDK下载的Empty reply失败保留，不改既有锁文件。

## 正式包与源码交付

- Debug/Release双ARM构建、apksigner v2、non-debuggable、正常Main入口、生产manifest/JPush、ABI及ZIP16KiB对齐、QRing构建复制30项全部通过。沿用既有两个32位厂商ELF的4KiB LOAD边界，本轮未改原生库；不能当作全部市场验收。
- 产物`E:/SayRing-auth-inline-1309-20261116/SayRing-1.0.14-1309-release.apk`，74519917字节，SHA256 `2a1be5acb286e4f7438da779c999690c87ddbff27e7a30303edfce71b14dc426`，1.0.14（1309）、cn.saydian.ring、正式证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。无临时key.properties，pubspec/lock及原生三平台源码均未变化。
- 再次fetch后HEAD和同名origin仍均85c0b7a。显式提交页面、索引与本记录三文件，不改后台、更新清单或商店状态。
- 当前同一华为已发起`adb install -r`，安装前仍读回1308；手机锁屏，已请本人完成华为确认，实际安装完成后独立读回再记，不把已发起当成功。

# 安卓1336分享历史及回应页美化与App链接恢复

用户确认双页面UI效果图后要求落地，同时反馈网页“在App里署名回应”可唤起App但无后续页面。基线44ade422e41f588cd0ca00ec3b00553d2239b092，当前SayRing分支修改前干净，status/remote/fetch与远端SHA相同。已阅读本仓库AGENTS、handoff、最新1335记录、回归清单及复盘。原文档、已安装1335及图片预览保留。

## 实现

- lib/ui/ring_share_page.dart：按确认稿使用米白背景、白色圆角卡片、报告类型图标、分享状态标签、最新回应色块与单一“查看回应”入口；回应详情增加报告背景卡、头像/匿名图标、姓名时间层次与分色回应卡。仅用已有snapshot、expiry和reaction字段；未知有效期不标有效，不添加阅读次数/总统计/未实现的筛选。过期分享仍能打开已有回应，分页/下拉刷新及账号隔离沿用。
- lib/app.dart：根因是AppLinks监听被controller.isGlobalEdition && controller.isWellnessOnly限制，安卓isWellnessOnly=false，OS唤起后没有接收链接。改为controller.ringExperience统一注册现有链接监听与恢复；保留原严格first-party路径/token校验、登录、必需更新、启动完成和稳定owner校验。没有更改设备、测量或iOS健康权限。
- 对照已安装app_links7.2.2 Android插件源码onListen：它会交付冷启动pendingLinks；不另加getInitialLink造成双交付。新增真实EventChannel替身的安卓/iOS冷/热入口回归，断言打开RingNamedResponsePage并向shares/open传入正确token。
- 本轮只读核对服务器H5 openApp逻辑：Android Chrome使用package=cn.saydian.ring的HTTPS intent/respond fragment，其他场景原链接校验保留。未修改服务器、关联域名配置、客户数据或后台诊断规则。

## 测试、截图与纠正

- 新增两个页面390x844、1x/2x字体测试及Git外截图能力；通知进入正确报告、旧服务器分页回退及实际时间显示继续验证。
- 初次分析发现测试if缺花括号，修正后无问题。卡片增高后原测试直接tap未构建的更早回应失败；按真实滚动流程先scrollUntilVisible，再加载和滚至新增回应，业务分页未绕过。初次截图使用Ahem占位字体，不能作为中文视觉验收；在本地截图运行中加载系统中文字体及MaterialIcons，普通CI未设置捕获目录时不读Windows字体，不将字体或截图作为生产依赖/真实健康数据提交。
- 定向34项通过（含4个App链接启动场景、4个新布局字体场景）；中文布局截图在E:/SayRing-share-ui-1336-20261127/previews。测试关闭回应页再销毁App，避免未结束路由影响后续测试的持久化状态。
- 接下来串行执行完整分析、双时区Flutter、Android Debug/原生/正式Release与签名门禁。Windows不能执行iOS原生构建；冷/热替身测试不等同实机网页到App验收。正式新包安装后仍需用户实际点网页按钮验证。

## 最终门禁进度

- 最终静态分析无问题；定向34项通过。UTC全量2557项通过；Asia/Shanghai、Android Debug/原生/正式Release与验签继续串行执行，最终结果后附。
- 中文截图经过字体加载后核对卡片/图标/姓名和日期层次；截图为合成测试内容。普通构建不使用本地预览字体，未将测试字体、图片或模拟健康内容写入业务记录。
- Asia/Shanghai全量2557项通过，与UTC一致。Android原生源码及依赖锁本轮未改，沿用1335已通过的142项原生策略证据；本轮native阶段仅执行releaseRuntimeClasspath依赖报告供ABI门禁，不将其写成重新执行原生单测。Android Debug/Release仍会编译并验证完整App，新链接监听通过本轮真实Flutter EventChannel冷/热启动回归覆盖，网页实机跳转另验。
- Android Debug成功，assembleDebug约250.8秒；当前releaseRuntimeClasspath依赖报告成功（约2分钟），不等同重跑原生单测。正式Release正在构建。
- 当前手机仅用am to-intent-uri对合成respond链接做解析往返，package和fragment得以保留；没有启动合成报告、发送回应或写客户数据。真实微信网页按钮仍留到新包安装后由用户验证。

## 正式包完成与安装发起

- 正式Release成功，assembleRelease约571.5秒。APK位于E:/SayRing-share-ui-1336-20261127/SayRing-1.0.16-1336-release.apk，76453716字节，SHA256=aaa1654d2e33be649b8585d93903aa8831d5c08c3958dffe71108bbfade3b35a。
- apksigner核实原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，包号cn.saydian.ring、versionName=1.0.16、versionCode=1336且非debuggable。production API/JPush manifest、ARMv7/ARM64运行库、ZIP对齐门禁通过；既有ARMv7 DSP/ECG 4KB ELF例外保留，不能称所有市场16KB验收。临时android/key.properties已按原脚本清除，构建产物/签名材料不提交Git。
- 一次提交前Git fetch因TLS unexpected EOF失败，保留错误后重试成功，远端分支仍与44ade42基线一致。没有覆盖或强推其他改动。
- 已向当前唯一USB华为发起保留数据的adb install -r；手机锁屏，已请本人完成解锁和华为安全验证。发起安装不代表安装完成，后续以系统实际版本为准。正式版网页到App的真实跳转仍待用户核对；不会代用户发送回应。

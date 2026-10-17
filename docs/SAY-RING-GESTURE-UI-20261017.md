# 手势控制布局与无状态回执处理

## 基线、原因和范围

- 用户要求参考 LuckRing 调整手势页，并修复连接后控制按钮无法开启。修改前 status/remote/fetch 成功；工作树干净，当前分支 codex/ring-screen-scroll-20261017、本地/远端均 b71fb1713847f82402f91f6d1de3577ef04834fa；main 4dee4e6。保留另一工作树的用户文档修改，不覆盖、不强推。
- 已阅读 AGENTS、国际交接、CHANGE-TEST-LOG、最近屏幕滑动记录、BUG-RETROSPECTIVE 和 REGRESSION-CHECKLIST。
- P1：已握手的 HR05 在 1104 可实际上滑，但未返回模式状态时，8 秒超时被当成硬失败、要求重连并锁死开关。预期：真实发送/系统配对失败仍报错；仅未返回模式状态显示未确认，可以继续关闭或设置。
- 原厂说明回调是手势开关状态，不能假定每次设置都有可关联的 ACK。不改协议、不猜参数、不将未收到状态伪造为 confirmedMode。状态缺失后，当前连接所有后续无请求 ID 的模式回调均隔离，直到重新握手重置；后续可发送，但只能显示 sentMode。
- Android CoolWear 在 SDK send 正常返回、必要系统配对已真实完成后，可以结束等待并返回“指令已发送/状态未确认”。新配对未完成、权限/发送错误、断线/账号切换仍失败并清理；未确认不代表功能验收成功。不持久化 sentMode，不跨设备恢复。
- 页面去掉重复大标题/两套开关，改为主题色圆角主开关+模式列表、耗电提示、独立手势说明子页及只读练习。开关显示已发送的用户请求时，副标题始终注明未确认；QRing 仍只读回确认，保留 availableModes 和 expectedMode CAS；iOS 原生不改。后端、健康和运动数据不变。
- 未解决的实体下滑问题保持独立待验，不宣称本轮 UI 修复已解决它。Windows 无法执行 iOS 编译。

## 验证过程

- 测试、构建及可能的真机结果按实际执行追加；产物/私有参考截图在仓库外，不提交密钥、安装包或原始设备输入。
- `dart format` 仅本轮 5 个 Dart 文件；`flutter analyze --no-pub` 无问题（58.2秒）。定向 `flutter test --no-pub --reporter expanded test/ring_screen_scroll_control_test.dart test/ring_gesture_guide_test.dart test/coolwear_gesture_control_test.dart test/qring_gesture_bridge_test.dart test/ui_shell_test.dart` 135/135 通过。
- 串行 `TZ=UTC flutter test --no-pub --reporter expanded` 1283/1283，`TZ=Asia/Shanghai` 同命令1283/1283。覆盖已发送未确认仍可关闭、未伪造勾选、独立说明跳转不写入、主开关/其他模式、QRing CAS和能力过滤、真实失败保持需重连、小屏大字体；主机拖动不代表实体手势通过。
- 本轮未改受保护签名脚本或厂商 SDK。选择新构建号1105；正式脚本仍仅在内存把默认版本1.0.0替换为当前1.0.2，并先严格核对替换数量，沿用原正式证书。Android Debug/原生测试完成后再串行构建 Release，Windows iOS Debug/Profile 未执行。
- `android/gradlew.bat :app:assembleDebug :app:testDebugUnitTest --no-daemon --max-workers=1` 成功（4分7秒），本轮报告XML总计63项/0失败/0错误/0跳过。新增测试验证未真正发送不能进入sent状态、未完成系统配对不能结束等待、没有ACK只保留sentMode、仍能发送关闭、迟到状态不确认后续操作、重连清除sent状态并恢复确认能力。既有工具链/Kotlin/Gradle弃用警告保留，非新增编译错误。
- 正式 Release 1.0.2/1105 双ARM构建成功（360.2秒，66.6MB）；包名cn.saydian.ring、min26/target36、原正式证书SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de、v2签名、16KB zipalign和生产JPush清单门禁通过。受保护临时key.properties已移除。APK仓库外gesture-scroll/SayRing-1.0.2-1105-release.apk，SHA256 D25EB65ABDB89E80968E6F38DCE6B9D7643229E44C2E2E89C371D24AE377EBA6。
- 手机息屏时仅请求用户解锁，没有使用历史密码。用户回复已解锁后 `adb install -r` 实际Success，版本1105，firstInstallTime仍2026-10-06 14:32:30，lastUpdateTime为2026-10-17 14:04:37。未卸载、清数据或解绑；为避免抢占，按既有授权暂时退出LuckRing。
- 真机HR05设备页实际已连接、手势入口存在；新页XML的单一主开关和模式按钮均可点击。初次截图前发生短时断连，显示真实“连接戒指后使用”，恢复后重新出现新页，没有把断线截图认作页面通过。一次开启试验后实际出现系统蓝牙配对请求，尚不能据此宣称模式设置完成；已请求用户核对HR05后手动配对，不自动确认、不授予通讯录/通话记录权限。后续依据实际结果补充。
- 用户反馈第一轮未看到弹窗；实时核对已超时并显示需重连。确认App在主屏display0，不是空闲display6。仅重启本App保留数据/绑定，真实HR05再次握手后重新发起一次；新XML确实显示系统“蓝牙配对请求”，用户及时回复“已配对”。未自动接受系统确认。
- 配对后的独立开启测试等待9秒：实际XML显示“已发送开启指令，戒指状态未确认；请实测效果，可再次设置”，checked=true、enabled=true、clickable=true。随后关闭等待9秒，显示“已发送关闭指令”，checked=false且仍可操作；再开启等待9秒，checked=true且仍可操作。未知回执未显示为已确认，没有再次锁死；最终保留模式1开启请求，不宣称固件确认或实体滑动通过。
- 新布局截图经实际查看，主开关/主题色模式卡/耗电提示/独立“手势说明”正常。说明入口点击后标题和“使用前”可读，再返回控制页；不触发模式写入。所有截图和XML仅留仓库外；中途用户/系统回到首页的截图不作为手势页验收，也不引用其中健康数值。
- 验收边界：本轮确认的是页面和真实发送后的开启/关闭可操作性；双向实体手势、持续蓝牙稳定性、全新配对不同手机及iOS编译/实物仍待单独验收。未发布后台、下载清单或应用市场，也不把此项作为原先下滑问题已解决的证据。

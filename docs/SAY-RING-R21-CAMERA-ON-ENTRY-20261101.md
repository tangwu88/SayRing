# R21 原厂相机入口与按需会话

## 范围与原厂依据

本轮仅 iPhone R21 相机入口、相机实际会话及必需的连接检查；其他专项和 Android 构建暂停。基线 6f50150，远端已同步。原 SDK ZIP 只读：原包 QCBandSDK 与项目内静态库 SHA-256 均为 dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393，没有替换 SDK。

原厂 QCSampleDeviceViewController.m 的 startCameraControl 先注册 QCSDKManager 的 switchToPicture / takePicture / stopTakePicture，再显式调用 switchToPhotoUISuccess；入口只检查连接。QCSampleTouchGesturesViewController.m 则用拍照子能力控制持久手势模式选项，两者不是同一能力条件。

## 本轮实现

删除连接握手期间进入/退出相机的探测，不再把一次命令超时永久转为入口缺失。对当前已确认的 QRing 手势/触摸设备提供已接入的相机入口；这代表可以打开相机和请求 SDK 会话，不代表遥控命令已成功。进入页面后按原厂顺序注册公开回调，再发送进入；只有实际 SDK 成功回调才能显示遥控就绪和接受快门事件。失败保留手机预览、真实错误及重试，不能虚报戒指拍照成功。

相机本来未被后台功能开关或账号授权拦截，本轮不修改其他业务门禁；系统相机/相册权限仍正常处理。单独隔离 Photo UI 与持久 HID 的超时状态；换设备/账号、后台或退出时清回调并拒绝旧事件。进入等待期间取消后，迟到 ACK 不得返回开启成功。

## 验证

正在增加生产原生方法的真实编译回调测试，再构建递增签名 Profile 并安装当前 iPhone；实物结果后续追加。原始日志、SDK 衍生只读证据、UUID 和照片全部保存在 Git 外。

## 已复现的退出补偿缺口

遥控启动没有 ACK 时，原 Dart 页只在 _cameraRemoteStarted=true 才发送关闭，可能漏掉结果未知的进入请求。新增 _cameraRemoteRequested，仅记录当前页面曾请求遥控，不能作为就绪标志；退出/后台时按原账号和精确设备尝试一次关闭。原有 owner/context 比对、晚到结果丢弃和快门门禁保留。

先新增 widget 复现：预期请求序列 [true,false]，原代码实际只有 [true]，测试失败。修正后相机定向 15/15；单独编译实际原生会话方法的测试验证回调先于命令、ACK 前不活跃、取消后迟到成功被拒绝、失败保留入口、旧连接事件丢弃和 HID/Photo UI 超时隔离。进入失败/超时不能自动开启或冒充拍照。

## 构建、签名和检查

- 新 QA 文件首次把 import 放在声明之后，格式化拒绝；移动后静态检查发现无用 models import。首个 QA 构建主动中止，清理后再构建，不使用未确认产物。
- QA Profile 1213：35.2 秒、62.0 MB；退出补偿加入后 QA Profile 1214：33.4 秒、62.0 MB；最终普通 main Profile 1214：34.6 秒、61.8 MB。iOS 构建串行，每份分别冻结、严格深度验签、校验 cn.saydian.ring、1.0.8、iPhone-only、开发设备授权、非 JIT 及 Runner/App 符号 UUID 匹配。没有编译 Android 或上传市场。
- 最终静态检查 flutter analyze --no-pub 零问题（2.7 秒）；格式化、git diff --check 通过。
- node --test tool/qring_photo_session.test.mjs tool/qring_capability_handshake.test.mjs tool/qring_camera_policy.test.mjs tool/test_qring_camera_integration.mjs：11/11 宿主测试。会话夹具直接编译当前生产原生方法，25 个行为断言及取消守卫负向对照；不是 25 项实物测试。
- flutter test --no-pub test/ring_camera_lifecycle_test.dart test/qring_camera_bridge_test.dart test/camera_remote_shutter_gate_test.dart test/ring_camera_panel_test.dart --reporter compact：15/15。此前相机/快门/模型定向 9/9 亦通过，不把两轮重复项累加。全量和其他平台构建按用户暂停指令未执行。

## iPhone / R21 实物结果

通过保留应用测试包装工具、已验签冻结 QA Profile 和真实 SDK 执行相机专项，不扫描/解绑/换账号/重置戒指，不注入快门或测量值。测试每一阶段断言当前账号及原精确绑定不变，清空命令尝试始终为 0。QA 目标和账号校验参数仅在私有定义文件中，不进普通 main。

1213 在 iPhone 15 Pro Max 上通过入口和实际相机预览检查，SDK 启动没有 ACK，准确保留失败文案；这轮不计遥控拍照通过。

1214 初次复测旧端口请求超时，Native IPv6 尝试亦未成功；不计运行通过。取消未取得结论的驱动，实际原生进程发生过更换，旧 PID/端口不能复用。最终重新读取原生进程表，匹配同一已安装 QA 应用路径和当前 PID，再比对受认证 VM PID 后附加，保留应用驱动退出 0、All tests passed。未确定重启来源，不归因于其他任务或把黑色暂停/测试结束屏当作 App 崩溃。

该成功轮的真实回执：固件 RF22B_2.00.09_261019；cameraOffered=true；realPreviewInitialized=true；remoteSessionConfirmed=true；ringShutterSequence=1；页面消息为“照片已保存到手机相册”。测试脚本没有点击手机快门、调用拍照函数或伪造 SDK 事件；事件由真实原厂 takePicture 回调，经当前连接/epoch 门禁进入 UI。保存文案仅在真实 camera.takePicture 及 CameraPhotoSaver 接到原生 saved=true 后设置。

这证明该固件至少一次成功完成 App 内遥控进入、设备快门事件和相册保存。成功轮的手势设置只读回包仍缺拍照模式选项（availableModes 为 0/1/2/3），进一步说明不能用持久 HID 拍照位否定 App 内 Photo UI。没有观察具体物理动作，不声称某一种双击/晃动动作已逐项验收；此前失败轮保留，不把单次成功解释为长期稳定或所有 R21 固件通过。

成功轮的新进程没有诊断启动环境，原 RingControlTrace 文件仍是旧失败轮，不能拿旧 trace 否定/冒充成功轮的 ACK 记录。成功结论依据匹配当前原生 PID 的驱动结果、测试回执、已验签 QA 构件及不变的源码哈希；设备标识、认证地址、照片和截图均私有保存。先前 commentary 将退出指令说成“实机日志已确认”不准确：退出补偿目前由回归测试证明，成功实物轮没有独立确认关闭 ACK。本记录作明确更正，旧失败证据不删除。

## 普通主入口交付

随后以同包名、同团队原位安装已单独验签的普通 main 1.0.8（1214），Apps 查询回读正确，再正常启动。受认证 VM 与当前原生进程再次匹配：当前账号、当前 R21 精确目标、固件和设备/能力均 ready；实际功能集合包含 find_watch、health_monitoring、camera、gesture_control。运行时没有 QA 的 _NoClearQRing 类，测试入口已移除；无手动测量。构建输入的原生、Dart、QA 源码及 pubspec.lock 哈希在最终验证时一致。

最终补偿关闭 ACK、长时相机会话、后台及其他型号暂未独立验收；其他专项继续暂停。仅本轮文件提交并推送当前 Say Ring 分支，不更新 main，不改后台、固件或现有上架审核。

收口时尝试通过普通 Profile 的 VM 调用 selectTab，AOT 反射入口返回 NoSuchMethodError，不作为页面导航或 SDK 故障，也不据此声称设备页已由该调用打开。普通主入口截图和状态另行核对正常；相机页的实际点击、预览与拍照证据来自前述真实 Widget/SDK 集成验收，不用这次失败调用替代。

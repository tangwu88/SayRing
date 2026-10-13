# QRing App 内相机与关于设备入口：1056 / 1057

## 范围与协议校正

- 基线 `60f1a8a3509ef11dad7a06495d0f1d885b9e0c8e`，修改前和提交前 fetch 核对远端。仅 Say Ring，保留 `cn.saydian.ring`、iPhone-only、账号、绑定和健康记录，不改当前 App Store 审核。
- 1055 将 HID 拍照模式 5 的门控当成了全部 QRing 相机能力。SDK 另有 App 内 Photo UI 协议；`supportRingCamera=false` 不能据此推断这个协议不支持。本记录校正旧记录，不删除历史证据。
- 原始 AAR/头文件只读。Android CameraReq 进入、保持、退出为 4/5/6，CameraNotifyRsp.ACTION_TAKE_PHOTO 为 2；iOS 对应 switchToPhotoUISuccess、holdPhotoUISuccess、stopTakingPhotoSuccess 和原厂拍照通知。
- 参考原厂 QRing 兼容产品说明的“打开 App 相机→授予权限→摇动佩戴手”流程：https://www.osawalla.com/pages/rp01-faqs 。未观测同一实物的 QRing App，不声称像素复刻或实际拍照效果已逐项一致。

## 修改

- 固件升级只留“设备→关于设备→固件升级”，删除设备功能区重复入口。可信固件、型号适配及失败恢复资源仍缺；保留真实版本查询和未知状态，显示“在线固件升级暂未开放”，不刷写、不虚报最新版。
- 握手按实际手势/触摸能力作为 Photo UI 候选，进入及退出都收到成功 ACK 才开放相机，不写 HID 模式 5。失败或超时不猜支持；超时冻结本连接的相机重试，重新握手再核对。
- 相机复用真实 CameraPreview、手机快门和保存相册，监听 SDK 拍照事件，每 10 秒保持会话。后台、退出、换设备/账号或 SDK 停止时关闭遥控；操作及连接代次丢弃迟到回调。
- 相机与同步/测量/设置互斥；退出先解除监听，再等在途命令结束。断连不向新设备发送停止；遥控停止后保留手机快门和重试，不重入旧相机控制器初始化。
- 既有 HID 读写/回读策略保留但主相机入口不再调用。增加桥接、事件隔离、双端导航、源代码契约及保数据真机测试。

## 回归与产物

- analyze 零问题。UTC、Asia/Shanghai 全量 Flutter 各 1194 项通过；重点回归 197 项通过。
- Android 原生 51 项，0 failure/error/skip；Foundation 相机策略、QRing 映射、CoolWear 策略通过。Foundation 和源代码契约不是物理拍照证据。
- Node 115 项：114 通过，1 项 Windows ACL 平台跳过；Python 发布门禁 33 项通过。提交前再次检查 analyze、工具测试和 diff。
- Android Debug、双 ARM QA Release 构建通过；Release 69.5 MB，非应用市场正式签名。保存在 `.build/SayRing-1.0.0-1056-{debug,qa-release}.apk`；Release SHA-256 `6d6266f1be06454ffef0ed7c243ae27b938224c457571b1b79c26a3329ab07a5`。
- iOS 普通 main 的 unsigned Debug 24.1 秒、开发签名 Profile 43.4 秒通过。严格验签，`cn.saydian.ring`、1056、UIDeviceFamily `[1]`；普通包保存在 `.build/1056-profile/Payload/Runner.app`，与验收脚本包隔离。

## 失败、重试与素材保护

- 初次 iOS BOOL block 返回类型错误已修正；完整测试各一次超时后，串行重跑两时区全量通过，未忽略失败用例。
- 磁盘不足导致构建复制失败和一次测试编译停滞；未安装不完整产物。保留原始 SDK、签名、旧 archive/IPA 和手机数据，清理仅限已核实可重建的 Flutter/Android intermediates。
- 旧 1055 APK 从手机已安装的同签名包恢复并核对旧 SHA，未卸载 App。1056 安装前备份 Library/Documents 到本机私有目录；敏感截图、日志和照片不入 Git。
- 真机脚本前两次用了不适配自定义导航的 pageBack 和无法构建懒加载条目的 ensureVisible；改为 handlePopRoute 与滚动构建。这是脚本问题，不当作 App 崩溃。

## 真机与发布边界

- iPhone 15 Pro Max / iOS 26.6：1056 普通 Profile 原位覆盖并启动成功，旧登录和健康首页可见。使用强制 keep-app-running 的保数据驱动，不执行默认 drive 卸载清理。
- 固件位置、相机预览、SDK 会话 ACK、照片保存和账号保留逐项记录；真实摇动触发不是 ACK 或手机快门可以替代的证明。
- Android 当前离线，1056 尚未安装安卓实物。其他 QRing 型号、真实摇动及 OTA 未验证项继续待验。
- 1056 是本机验证构建，未据此宣称已上传 TestFlight、发出外部邀请或审核通过；旧 Beta/App Store 审核保持不动。

## 1057：真实相册权限拒绝与恢复入口

- 1056 实物会话进入相机页并有 CameraPreview、遥控就绪文本；手机快门真实拍摄后，原生 PhotoLibrary 返回 PHOTO_PERMISSION_DENIED。没有照片保存成功证据，因此严格保存断言失败，未伪报相册通过。
- 原页面虽有准确错误说明，却在遥控仍开启时隐藏重试/设置入口。1057 新增“允许保存照片”按钮直达 App 系统设置，仅在这一权限错误时显示；成功保存或其他错误清除该权限状态，不自动修改系统授权。
- 验收脚本区分真实保存与权限拒绝恢复 UI 两条路径。权限拒绝分支可以通过错误处理检查，但 manualPhotoSaved=false 必须继续记录，不把测试脚本通过当作照片保存通过。
- 1057 analyze 零问题，UTC 全量 1194 项（50 秒）、Asia/Shanghai 全量 1194 项（56 秒）通过；Node 114 通过、1 平台跳过。运行时代码在这些检查前冻结。
- 普通 iOS Debug 25.6 秒、签名 Profile 54.8 秒和验收 Profile 27.9 秒通过。1057 验收期间 R21 断连、入口随能力消失；重试仍未在 45 秒完成握手，因此本轮真机脚本没有通过。补明确握手/同步后连接断言，避免缺失条目的 No element 掩盖实物待验条件；没有硬改绑定或猜测原因。
- 最后恢复普通 main 的 1057 Profile 并重新启动，保数据安装成功。权限恢复入口的代码门禁通过，1057 相册保存及实物摇动仍待验；1056 的 Photo UI ACK/相机初始化证据不能替代这些未通过项。
- 1057 Android Debug 42.8 秒通过。Release 首次因磁盘满失败，删除已核实可重建的 Debug 合并 native 库缓存后重跑 104.9 秒成功，未删除源码、签名或保留产物。QA Release 仍为非市场正式签名。
- 最终 APK 包名 `cn.saydian.ring`、构建 1057；验签通过，SHA-256 `15996d8bc0b6cbc3cabac1ead8fc902f2ffa68f37995b3a49af59f5f4f5e599a`。保存在 `.build/SayRing-1.0.0-1057-qa-release.apk`，尚未安卓实物安装。
- 代码只交付当前开发分支，未因静态/构建通过就替换审核或推至市场。真实设备未通过项保留为后续验收条件。

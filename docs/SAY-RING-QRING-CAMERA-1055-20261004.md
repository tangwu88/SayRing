# QRing 相机遥控与功能入口：1055

## 范围和依据

- 基线 debd64be1ff2816fa4e2c596953aad812d24e201；fetch 后当前分支与远端一致。只修改 Say Ring，不更换包名、图标、用户记录或当前 App Store 审核。
- QRing 的拍照控制为模式 5，不能复用 CoolWear 模式 4 或 watchCameraReq。依据当前原厂头文件、SDK 方法和 Android TouchControlReq 字节码核对参数。
- 只有握手解析到拍照能力并且具备已接通的手势/触摸控制链路时显示入口；Android RT11 触摸协议未映射时保持关闭。
- 双端读真实模式，再按预期旧模式写入，保留设备真实强度/触摸时长，并重新读取确认。写入 ACK 不是最终保存证明。
- iOS 原厂回调转主队列异步继续，避免 SDK 回调栈重入；25 秒超时或未确认写入后冻结当前连接的相机重试，重新连接才恢复。
- Dart QRing 蓝牙命令串行；连接/断开/恢复目标变更取消旧队列，连接代次、账号和设备校验丢弃迟到回调。
- QRing 相机页面提供实际状态、显式模式替换确认及原厂配对/系统相机使用说明。不假设某个固定手势，不将遥控开关当作实际拍照成功。
- 两端设备功能区新增固件升级入口，关于设备原入口保留。可信原厂固件、适配和恢复资源尚缺，OTA 保持未开放，不伪报最新版或执行刷写。

## 回归结果

- flutter analyze：零问题；最终 git diff --check 通过。
- TZ=UTC / TZ=Asia/Shanghai 完整 Flutter 测试：各 1193 项通过，包含新桥接队列、回读、换设备及窄屏测试。
- Android testDebugUnitTest：51 项、0 failure/error/skip；最终原生补丁后重跑成功。
- Foundation QRing 相机、QRing 映射、CoolWear 策略测试：通过，均为合成策略验证，不是物理设备证明。
- Node 工具全量：114 项，113 通过，1 项 Windows ACL 平台跳过；Python 发布门禁：33 项通过。
- iOS Debug unsigned 29.6 秒、Profile unsigned 62.7 秒成功；Android Debug 24.8 秒、双 ARM QA Release 107.9 秒成功（69.5 MB，非市场正式签名）。
- iOS App Store Release archive / export 成功。IPA 40,835,343 字节，SHA-256 5cde51414b82f47883d1c816cc38a2e5028615b85af7b8c4d54a751fcb2f1c5a。
- 实际 IPA 信息 cn.saydian.ring / 1.0.0 / 1055 / UIDeviceFamily [1]。archive 严格验签通过，get-task-allow=false、beta-reports-active=true，无新增 HealthKit 权限。

## 失败与修正

- 新 UI 测试起初用错“遥控拍照”名称并未滚动到懒加载条目；改用稳定 key 和实际“相机遥控”文案。
- 平台覆盖变量清理过晚导致 Flutter 调试断言；在用例内恢复并保留 teardown 兜底。
- 静态契约正则起初未接受多行布尔表达式；修正空白匹配后通过。
- 最终 analyze 的三项风格提示已修复，未忽略规则。

## 发布和硬件边界

- 用户提供的 App ID 6817980969 实际为 SAYDIAN Health；本轮只上传 Say Ring 的 6816549943。
- 使用已存在的苹果上传密钥，无新建或扩大访问权限。新包校验、上传、苹果处理及测试组资格需各自实际回读后追加。
- TestFlight 外部组和已授权邀请邮箱沿用已有配置，不把等待 Beta 审核当作邀请已发送或手机安装成功。
- 当前没有在线可安装的 iPhone。没有新 QRing 实物拍照、OTA 或 XR 安装验收；原始 SDK 包、旧构建、手机资料和健康数据未删除。

- 1055 altool 校验于 18:51:19 返回 VERIFY SUCCEEDED，0 错误、1 警告；90068 是 2027 年 4 月最低 iOS 15 的未来要求，目前没有因此拒绝。上传和后台处理仍单独验证。
- altool 上传于 18:54:26 返回 UPLOAD SUCCEEDED / 0 错误 / 1 个同类警告；40,835,343 字节传输 4.890 秒。上传收据 e1eb66b7-796c-41cb-80e3-8b498505fcff。没有改绑审核构建。
- 18:58 查询尚未出现 1055 Build 实体。已有 1054 外部 Beta 等待审核；苹果规定同版本同时只能审核一个构建，未擅自撤回 1054 Beta 或现有 App Store 审核。不能据上传成功宣称 1055 已可安装或邀请已发送。
- 19:03 只读 API 确认 1055 为 VALID，所属 App 6816549943 / cn.saydian.ring；沿用之前已批准且未改变的出口合规设置，保存后回读 usesNonExemptEncryption=false。
- 中文、英文 What to Test 已保存；首次创建中文遇到苹果预建的空中文记录而返回 409，改为 PATCH 已存在的记录后成功。没有重复创建或修改别的构建。
- 将 1055 加入既有内部、外部两个测试组并开启自动通知。按测试组的 builds 关联实读，两个组均有 1054、1055；内部状态 IN_BETA_TESTING，外部 READY_FOR_BETA_SUBMISSION。
- 尝试提交 1055 外部 Beta 返回 HTTP 422 / ENTITY_UNPROCESSABLE.ANOTHER_BUILD_IN_REVIEW；1054 仍 WAITING_FOR_REVIEW。未撤回旧审核，也未宣称外部邀请已发出。待旧 Beta 审核结束才能提交新 Beta。
- 初次用 builds 的 betaGroups 关系 GET 返回 403，该关系只允许 CREATE/DELETE；改用 betaGroups/{id}/builds 获取成功。此错误不是账号失去权限，不因此扩大人员或 API 密钥权限。

## 19:20–19:33 入口缺失反馈与 Android 实物续核

- 开始时 fetch、当前分支 ff-only 和 HEAD 核对完成：7dd15eb，工作树干净。只核对/安装既有 1055 产物，本轮不改运行时代码、不重新构建；此前测试及构建仍是此前证据。
- `devicectl list devices` 中 iPhone 均 unavailable。本轮没有 iPhone 安装或拍照效果证据。ADB 有 Huawei PPA_LX3 / Android 10，手机原包是 1.0.0 (1053)，尚未安装新增设备功能入口的 1055。
- `aapt dump badging` 与 `apksigner verify --print-certs` 确认两个既有 APK 都为 cn.saydian.ring / 1.0.0 (1055)、同一 QA 签名。`adb install -r app-release.apk` 成功；系统安装扫描显示未发现风险，经标准确认流程继续，未关闭安全检查、未卸载或清数据。
- 覆盖后真实登录、头像和已有健康记录可见，保存的 R21 自动重新握手。设备页有“固件升级”；进入固件页显示真实的未知版本和“在线固件升级暂未开放”，没有虚报可用固件。相机入口仍不显示，因此旧版本并不是拍照缺失的全部原因。
- 为核对实际 SDK 能力，临时同签名覆盖既有 1055 Debug，连接 SDK 握手后通过 JDWP 只读所持 DeviceSupportFunctionRsp 字段；没有反射调用设备命令、修改字段、暂停线程、读取账号凭据或健康数据库。第一次读取早于握手，明确报 Handshake not ready；随后两次一致返回 supportGesture=true、supportRingCamera=false、supportTouch=false、supportRingCameraTouch=false、supportRt11=false、supportBlePair=true。
- 上述结果只证明本次连接的 R21 没有报告拍照能力，不推及全部 QRing 型号，也不据此断言硬件永久不支持。现有能力门控拒绝强行启用模式 5；如原厂 App 可用，需要进一步核对同一实物的原厂功能/固件和协议，不用另一型号或合成数据替代。
- 只读调试完成后移除本次 JDWP 端口转发，再次 `adb install -r app-release.apk` 成功，恢复普通 QA Release；`dumpsys package` 回读 1055 且无 DEBUGGABLE 标记，启动成功、R21 再次自动连接。最终 APK SHA-256：30bf13322ec873ebc6b2f4493a3dfa3a451d88bbe42f1b82f796d9c24bb784db。
- `TZ=Asia/Shanghai flutter test --no-pub test/ui_shell_test.dart --plain-name 'QRing device functions' --reporter expanded`：2/2；`--plain-name firmware`：5/5（含上述两个用例），均通过。原生既有策略测试遍历全部 32 种功能位组合，原测试证据不冒充本轮新跑。只追加记录，不重复双端构建/全量测试或制作新构建号。
- 真实截图、UI dump、JDWP 辅助脚本只保留在本机私有临时目录，不入 Git。未向戒指写手势模式/固件，未改 App Store 审核。固件查询/下载/写入和实际拍照仍未完成；可信原厂固件、型号适配与失败恢复资源缺失的阻断继续保留。
- Apple API 续核：1055 内部 IN_BETA_TESTING、外部 READY_FOR_BETA_SUBMISSION；1054 仍 WAITING_FOR_REVIEW。没有外部可安装或新邀请发送证明，未撤回旧 Beta。

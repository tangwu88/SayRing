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

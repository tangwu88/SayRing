# R21 换环后的相机能力排查

## 范围与基线

用户换接另一枚 R21，发现相机遥控缺失，并要求解释同款同名设备功能不同。当前分支同步到 63848bd；本轮优先 iPhone 相机能力和连接，不运行测量、睡眠专项或 Android 构建，不改线上审核。

普通 main 1209 在 iPhone 15 Pro Max 真实重开后自动恢复到新 R21，固件 RF22B_2.00.09_261019；同一正常重连接口再次恢复精确目标并刷新能力对象。之前的另一枚 R21 固件为 RF22B_2.00.12_261028，不能用旧环能力覆盖新环。

## 已确认与排查

新环实际 Flutter 能力只有 find_watch、health_monitoring、gesture_control，相机未由原生发布。当前代码仅在 Photo UI 进入、退出均成功后发布 camera，不能仅凭名称判断。先补充可在 Profile 显式启用的有界无身份原生阶段记录，区分实际功能位、进入失败、退出失败和超时；该记录不含 UUID、账号和健康值，默认不开启。

旧 VM 端口已失效但普通 App 仍运行；原生重新启动普通 main 并重新发现认证端口后恢复观测。AOT VM 尝试直接调用扩展/桥接 readDeviceFeature 返回 NoSuchMethodError，不计为 SDK 读失败。仅有界、只读 VM 检查和正常重新连接已执行；诊断失败原始记录保留在忽略目录。

## 待验证

待新诊断构建读取真实 SDK 回包后，决定是否需修复能力门控或相机探测；尚不认定固件缺少相机，更不强行按同名开放功能。最终修复、签名安装、页面和真实协议结果后续追加。

## 原始包与真机结果

- 串行普通 main Profile：1210 构建 27.3 秒，1211 构建 12.2 秒，最终 1212 构建 11.0 秒，均 61.8 MB；三份分别冻结并核对严格深度签名、开发设备授权、cn.saydian.ring、1.0.8、iPhone-only、非 JIT 和 Runner/App 符号匹配。最终安装的是普通 main 1212，并非集成测试入口。
- 初次指定不存在的 config/production.json，未进入编译；随后校验环境定义时错误地把 API origin 当成 /global 前缀，校验拒绝并导致第二次缺定义文件，同样未编译。核对现有 Generated.xcconfig 与 GlobalEnvironment 后确认 origin 为 https://app.saydian.cn，由客户端映射 /global/api/saydian-app/v2；使用与 1209 相同 origin 完成后续构建，没有改 API 路由。
- CoreDevice 覆盖安装 45 秒超时，后续详情/应用查询亦超时；取消了未确认安装完成的启动请求。USB 硬件仍匹配原手机，usbmux 实际重新可用。通过 installation_proxy 覆盖安装后，逐次以 apps query 回读构建号，再由原生 DVT 启动，没有卸载、清账号或清戒指。
- 1210：新环 gesture=true、touch=false，初始 photoMode 检查为 false；Photo UI 进入回调失败，约 4 秒；退出也失败，约 4 秒。仅此 false 不能区分字段缺失与明确关闭。
- 1211：尝试让拍照探测离开固件回调下一事件循环再开始。实物仍为进入和退出失败，结果未变。该假设未被证实，已从最终产品代码及测试中撤回，原构件和失败证据保留；不声称修复了命令时序问题。

## 最终修改与结论

发现 resolveExtendedCapabilities 原先只要手势或触摸总开关为真就跳过独立扩展查询，不能保证拍照子能力有回包。最终改为同时存在合法的拍照子能力布尔字段才走快速路径；字段缺失/非法时，仍按原有最大两次独立读取和连接代次守卫查询，不沿用旧环能力。返回明确 false 时尊重 false，不按名称打开相机。

1212 实物确实执行了独立扩展读取，并成功回包；随后 photoModePresent=0（字段缺失），并非设备明确返回关闭。Photo UI 进入、退出仍失败。因此当前准确状态是“该固件的拍照能力未确认”，而不是“硬件一定不支持”，也不是“相机已修复”。最终未添加 camera 能力，页面继续隐藏未确认入口，保留查找、健康监测和手势入口。

这说明同款/相似蓝牙名称不能替代真实能力确认；本次两枚 R21 的固件版本确实不同，但仅凭此不能认定版本差异就是全部原因，也未取得两枚在同一原厂 App 下的对照。新环普通 main 重开和正常主动重连均为原精确目标、当前账号且能力对象刷新，不是把上一枚的缓存当成新能力。

## 检查与边界

- 最终原生/相机宿主命令：node --test tool/qring_capability_handshake.test.mjs tool/qring_camera_policy.test.mjs tool/test_qring_camera_integration.mjs，10/10；直接编译生产能力读取方法，包含子能力缺失触发补读、明确 false 保留及负向回归对照。
- 时序试验首轮宿主夹具仍期待同步完成而失败；试验夹具调整后通过，但因实物无改善，时序产品改动和夹具调整均撤回。最终能力读取负向变体首轮触发 unused-variable 编译错误，不算有效负向对照；修正为保留变量引用后，变体按预期断言失败，正常生产方法通过。
- Flutter 定向：flutter test --no-pub test/qring_camera_bridge_test.dart test/qring_gesture_bridge_test.dart test/device_feature_models_test.dart test/wearable_exact_recovery_test.dart --reporter compact，35/35。静态检查及最终收口结果见后续记录。全量、Android、其他模块依用户“其他测试暂停”不执行，不用既往全量结果代替。
- 1212 原生日志和受认证 VM 均对应已验签普通 main；同一账号、同一新 R21，固件 RF22B_2.00.09_261019，连接/能力 ready，未进行手动测量。原始 UUID、账号、手机截图、回包和调试地址均在 Git 忽略的私有构建目录，不入库。
- 当前没有该固件的有效相机进入/退出 ACK 或戒指快门事件，不能宣称相机恢复。尚需厂家核对该固件所支持的拍照协议/适用 SDK，或在同一实物原厂 App 取得对照后继续定位；没有可信升级文件时不刷写固件、不虚报支持。

## 收口

最终 flutter analyze --no-pub 零问题（2.1 秒），git diff --check 通过。普通 main 1212 随后以不带诊断 opt-in 的原生启动方式重开；受认证 VM 再次确认当前账号、新 R21 精确目标、固件和能力均 ready，无手动测量。未清绑定/健康记录，也未启动 Android 构建、App Store 上传或其他专项；新环真实远离/靠近三轮尚未执行，上一枚的三轮结果不能移用。本次仅提交上述范围的代码和无身份说明，当前分支推送后核对远端，不更新 main。

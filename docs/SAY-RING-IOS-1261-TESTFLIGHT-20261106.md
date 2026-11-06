# Say Ring 1.0.11（1261）TestFlight 上传

2026-11-06。用户要求「苹果构建新版本上传」。本轮将已完成的六项 iOS 修复制作成新的正式签名测试构建。R7 Pro 真机复测此前由用户明确暂缓，仍需单独验收。

## 源码和既有验证

- 固定源码提交 `5d630bad0f49381d274cf7514a9369903bd3e745`，分支 `codex/ios-six-fixes-1259-20261106`。构建前工作树干净，已 fetch origin，未改动应用逻辑。
- 运行源码清单 SHA-256：`b8ec69707e3651187b86401d6a018d42bdc8dae5253248f0dddf0bfe33fc07e5`；与已验证的普通 Debug／Profile 1259 一致。
- 构建号独立指定为 1261，保留版本号 1.0.11。远端另一路 Android 1259／1260 工作未合入本构建，避免将未经本轮整合验证的变更混入已验证的 iOS 修复源码。
- 复用同源码的静态分析零问题、2,060 项 Flutter 回归、22 项原生专项（含 Foundation 158 个断言）、108 项 Android 单元检查及双端构建结果；详情和失败纠正过程见 [六项修复验证](SAY-RING-IOS-SIX-FIXES-1259-20261106.md)。本轮没有再次修改源码或重复这些测试。
- 既有 XR 验证覆盖原位安装前后 71 个业务文件一致、R21 连接／启动同步及页面；不能推导为 R7 Pro／R7 Ultra 历史、运动实时心率或实际手势已通过。

## 构建与发行包

- 正常入口 `lib/main.dart`，沿用原生产配置；包名 `cn.saydian.ring`，团队 `W7SXQ4A226`。
- `flutter build ios --no-pub --release --config-only --target=lib/main.dart --build-name=1.0.11 --build-number=1261 --dart-define-from-file=<本机生产配置>`，后续串行执行 Xcode Release archive 和 App Store export。
- 18:17 归档成功：`Say Ring 2026-11-06 18.17.33 1.0.11-1261.xcarchive`。正常 AOT、arm64、包名／版本／团队和严格签名均通过；本机工具链目标 iOS 15.0，未将此构建结果表述为旧系统兼容性验证。
- 两个可选 xattr 清理子进程达到 30 秒上限后终止，继续正常构建；临时 Flutter 构建配置已恢复，源码哈希未变。
- 独立导出 IPA 为 39,108,402 字节，SHA-256 `2ecdf6e9d456256a767d69ffaeaeb179a5edda6c99a1319b663089a7e0228220`。Apple Distribution、App Store 描述文件、`get-task-allow=false`、生产 APNs、正常 AOT 及严格签名核验通过。
- 私有构件及日志：`build/ios-testflight-1261-u4udzpfs`。生产配置、签名资料、设备备份和账号信息不进入公共 Git。

## 上传及苹果处理

18:20 发起上传，18:23:52 Apple 明确返回 `Uploaded package is processing`、`Upload succeeded`，`xcodebuild` 退出码为 0，上传约 226 秒。已完成二进制上传，尚不能据此认定 TestFlight 处理完成或测试员可安装。

另对传输中的实际 IPA 留样并核验：39,108,394 字节，SHA-256 `8d6936babab081b83bc399ca7a988ecfd1f5b81dd4f73e465bb3215e4e55631f`。包名／1.0.11（1261）／团队、正式签名、App Store 描述文件、生产推送、禁止调试权限及正常 AOT 均通过；实际上传文件与独立导出文件分别留存，未混用两者哈希。

Apple 接收时仍报告 15 项第三方库 dSYM 缺失警告，与既有依赖有关，会影响对应库的崩溃定位。本轮未更换 SDK，也未将这些警告记为已解决。

原 TestFlight 群组页面仍能显示旧构建，但重新向苹果加载后返回登录页，已请求用户恢复认证。CLI 上传已完成；浏览器的最终处理状态、加密问卷、测试说明保存及新构建测试组可用性仍待登录后核对。中英文说明已写入本机私有交付目录，未将草稿说成已保存至 Apple。

## 测试范围与既有状态

- 已准备中英文测试说明：健康页热量展示、运动实时心率、两类戒指的 iPhone 手势说明、连接自动同步、历史完成计数和添加设备自动扫描。
- R7 Pro／R7 Ultra 自动历史同步、运动实时心率回包及实际手势待真机复测；R7 Ultra 有效手动 HRV 的既有未解决项继续保留。
- 本轮不安装手机、不修改健康记录或戒指设置；不撤回既有构建、替换 App Store 审核或改变手动发布设置，不修改销售地区或接受新法律协议。

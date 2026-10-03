# Say Ring 睡眠 AI 分析说明与授权修复

## 原因与范围

- 1025 真机“AI 睡眠分析报告”页显示服务或分析说明不可用。生产 AI 已有真实配置，后台未发布分析说明，所以生成前被保护性阻止。
- 客户端从 `db96c5cef2f7344b839ed84e6466e549ec247a42` 继续；fetch 发现远端 `c31d618` 仅新增更新文档。安全合并保留双方记录，索引冲突已逐项保留，没有覆盖源码或其他 App。
- 本轮只修改 Say Ring 睡眠授权 API 与相关文案：专属说明、专属授权与撤回，不再复用 Health App 的健康分析授权。用户仍须主动确认每次上传；游客、不完整说明、旧版本、换号及撤回继续拒绝。
- 预期：服务端说明发布后可加载并确认，不再显示含糊的不可用错误；真实 AI 成功后才显示实际评分和报告。保留现有账号、本机数据与 App Store 审核包。

## 检查与验收

- 格式化、静态检查、定向/全量测试、双端构建、1026 原位安装与真实报告回读逐次补记。模拟报告仅用于测试，不作为真实生成证据。

## 已执行

- `dart format` 四个运行时代码/测试文件通过；首轮 Analyzer 零问题。首轮定向 14 通过、1 失败，原因是撤回提示从“健康 AI”改为“睡眠 AI”后旧断言未更新；更新断言，第二轮 15/15 通过，保留首轮日志。
- 新增不可用原因不得触发同意/上传的 UI 测试后，最终 Analyzer 零问题（5.2 秒）；`TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub --concurrency=2` 与 `TZ=America/New_York` 全量各 1069/1069 通过。
- `devicectl list devices` 与 `xctrace list devices` 均显示 iPhone 15 Pro Max 离线，没有执行卸载、安装、清数据或真实第三方健康上传。构建产物与安装结果分开记录。
- Foundation 的 QRing 原生映射断言通过；它使用合成样本，不替代真实 SDK 睡眠或 AI 验收。
- 同源生产配置 `--dart-define-from-file=config/ios-app-store-no-push.json` 串行完成 `flutter build ios --debug/--profile --no-pub --build-name=1.0 --build-number=1026`。Profile 保存于忽略目录 `.build/SayRing-1.0-1026-Profile.app`；实际 plist 为 `cn.saydian.ring`、`1.0.0 (1026)`、`UIDeviceFamily=[1]`，Apple Development / `W7SXQ4A226`，`codesign --verify --deep --strict` 通过。Runner SHA-256 为 `27d45eac2404eadd764528c5bb6470865d3e2461d7301fdbb51f61084aedd3ce`。未将开发包作为 App Store 分发包上传。
- `JAVA_HOME=…/temurin-17.jdk/Contents/Home ./gradlew :app:testDebugUnitTest --rerun --max-workers=1` 首轮失败：QRing AAR 的 Gradle 9.1.0 immutable transform 单个缓存目录 `7d449599654a801d656c79251a8c1bc3` 校验不一致。确认没有文件句柄或活动构建后，将该 49 MB 缓存移至 `/private/tmp/sayring-gradle-quarantine-20261003.hweJRI/` 保留恢复，没有删除 SDK 或全局缓存。原命令重跑通过，JUnit 8 套件共 37/37，零失败、零跳过。
- Android `flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0 --build-number=1026 --dart-define-from-file=config/ios-app-store-no-push.json` 串行通过（29.4 秒 / 76.8 秒）；Release 使用显式 `SAIDIAN_ALLOW_QA_RELEASE=true`，仍是 Android Debug 证书，仅内部 QA，不是正式商店包。双包实际 ID 为 `cn.saydian.ring`、`1.0 (1026)`、ARM32/64，`apksigner verify` 和 `zipalign -c -P 16 4` 均通过。
- 已保留 `.build/SayRing-1.0-1026-Android-Debug.apk`（SHA-256 `4fd282ae4632abf7767def5a35866c84ba6567037a291d3950c999865f502fbf`）和 `.build/SayRing-1.0-1026-Android-QARelease.apk`（SHA-256 `fd6d5eafc4808d7f8831c1bef81c48f9caef6c12ab50c7ed9204fac8abc4aaa3`）。没有安装安卓手机或将 QA 签名写成正式签名。
- 日志保留于 `/private/tmp/sayring-sleep-consent-{analyze-final,full-shanghai,full-newyork,ios-debug,ios-profile,android-native,android-native-retry,android-debug,android-release}.log`；未关闭已有厂商插件 KGP/SPM 未来迁移警告，也没有改 SDK 或权限来绕过检查。
- `python3 -m unittest discover -s scripts/release -p 'test_release_gate.py'` 30/30 通过；均为合成发布门禁测试，不是对正式 App Store 分发包的验收。fixture 中打印的旧 Health 地址不代表本轮客户端请求或上线地址。
- 服务端专属授权修复 PR #17 首轮真实数据库/镜像 CI 已通过；安全合并同事后续主线改动后正重跑集成 CI，未在本条记录时上线或发布候选说明。客户端仍只推当前 Say Ring 分支；本轮没有真实 iPhone 报告回读，不先把它升级为已接受的 main 基线。

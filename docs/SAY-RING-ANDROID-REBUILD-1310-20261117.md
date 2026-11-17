# 安卓正式包1310重新构建（2026-11-17）

- 用户要求打包最新APK。本对话安卓分支codex/u19s-android-connect-20261111在fetch后HEAD/upstream均c092286d91efecf7067bace1808575e2231e7124、工作区干净；另一客服/iOS分支仍独立，未擅自合并。已明确本次最新指当前已验证安卓分支。
- git diff --quiet 6db41aa942e49450a01dfba77e84cd5f9b926944 HEAD -- lib android pubspec.yaml pubspec.lock config assets scripts/release通过；变化仅实施记录，故保留1.0.14（1310），不把重新打包当成新增功能/首轮同步与心率问题修复。
- 使用原DPAPI保护签名构建脚本、正式普通入口、ARMv7/ARM64、commerce=true和既有global服务地址重新执行Release，不读取/提交生产密钥，不安装或上传后台。本轮产物位于Git外E:/SayRing-android-release-1310-20261117。
- 业务源码/SDK/依赖与6db41aa已验证版本相同，沿用其UTC/Asia-Shanghai各2437项、Debug/Release和mobile-ci43851553879全通过证据；native134项/依赖报告沿用此前门禁。不在无新代码变动的重新打包中重复全量套件，也不将沿用结果说成本轮重跑。
- 本轮实际执行Release、apksigner、package/manifest、ZIP 16KB、双ABI及QRingSDK复制、git diff --check；最终结果与hash待完成后追加。原有JPush受控ABI例外和32位厂商库ELF LOAD 4KB限制仍按此前记录保留，不宣称所有市场审核/全部16KB库验收通过。

## 实际结果

- Release和verify实际执行成功。最终stage=complete，cn.saydian.ring、1.0.14（1310）、非debuggable、普通main入口；原正式证书SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，签名验证、生产清单、ZIP16KB及ARMv7/ARM64检查通过。
- 产物 E:/SayRing-android-release-1310-20261117/SayRing-1.0.14-1310-release.apk，74,601,585字节，SHA256 7D31CF0A8744C4644D3B590BE14B4AE1B5E7B90EB7DA4F64FC0509413A3D1B7A，与11月16日已验证1310相同；本轮从当前源码重新构建，没有以旧包冒充构建成功。
- 首次SDK复制门禁因父进程PATH缺少Git的unzip而ENOENT；Release/验签已通过，未改SDK或绕过门禁。补齐本机PATH后仅重跑失败检查，QRing30项复制一致性通过，原失败sdk-copy.log保留，成功见sdk-copy-rerun.log。git diff --check通过，签名临时android/key.properties不存在。
- 构建前后再次确认运行源码/依赖与6db41aa无差异。仅提交本记录与索引，密钥、日志及APK不入Git；本次按用户要求交付APK，没有安装手机、发布下载页、合并其他功能分支或修改服务器。

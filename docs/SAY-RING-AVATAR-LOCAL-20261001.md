# 2026-10-01 Say Ring 专用头像上传入口

## 范围与原因

- 用户限定本轮仅 Say Ring。安卓端反馈“照片能预览，但保存后头像不更新”；服务端旧共享头像上传依赖未配置的对象存储，现场返回 503。
- Say Ring 账号继续使用隔离国际 API；国内版与国际版 App 现有上传接口及存储方式保持不变。只将 Say Ring 客户端切到专用头像接口，资料保存时使用返回的原格式 URL。
- 修改前已核对分支、工作区和远端；本工作树已有自动重连、睡眠明细等其他未提交改动，全部保留，不并入本轮头像提交。

## 本轮文件与契约

- `lib/services/global_api_client.dart`：头像 multipart 改发 `POST /global/api/saydian-app/v2/files/say-ring-avatar`；继续携带当前账号 Bearer 与字段 `file`，不再发送原共享上传接口的 `purpose`。
- `test/global_api_test.dart`：检查专用路径、鉴权、multipart 字段及返回 URL；不使用真实账号或照片。
- 服务端仅在国际 API 增加专用入口。服务器本地存储开关默认关闭，必须在卷、备份及恢复演练后上线启用；客户端通过测试不代表真实头像已修复。

## 验证记录

- `TMPDIR=/private/tmp flutter test --no-pub test/global_api_test.dart`：27/27 通过。
- `flutter analyze --no-pub`：零问题。
- `TMPDIR=/private/tmp flutter test --no-pub`：1020/1020 通过。
- Android Debug 首轮构建在 `:app:processDebugResources` 报 Veepoo AAR 中 `zdial_preview_bg_default1_joemefit.png` 的 AAPT 编译错误。原 AAR 与 Gradle 解包资源 SHA-256 相同，AAR ZIP 检查和单张图的 AAPT2 编译通过；限制为单 Gradle worker 后，单独的 `:app:processDebugResources` 成功。
- 随后重试遇到主机磁盘满（根卷仅余 117 MiB），Gradle 无法创建缓存；确认没有 Xcode 构建或打开句柄后，删除仅可重建的 Xcode `DerivedData/ModuleCache.noindex` 文件，释放约 1.6 GiB。缓存重建过程中又发现先前未写完整的 Kotlin BOM，Gradle 已重新下载。
- 为防构建再次写满，清除无人占用的 Chrome `Code Cache` 和 `Cache/Cache_Data`、pnpm 下载缓存，以及本工作树的 Debug 原生库中间文件；保留 Debug APK、源码、厂商 SDK 和其他项目构建目录。这些文件按需可重建，但不是可从废纸篓恢复的删除。
- `GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --debug --no-pub` 最终成功；`SAIDIAN_ALLOW_QA_RELEASE=true GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --release --no-pub` 成功。两个 APK 的包名均为 `cn.saydian.ring`，版本 `0.1.21 (1006)`；QA Release 使用调试签名，仅供构建回归，不能上传市场。Debug SHA-256 `a32123fd9fe48dd369c6b425b89fc17d228139eb3720b0387609b165febdfbd1`，QA Release SHA-256 `2f4a8553bfd7779e3753843fa48958a359512b4a7a23de8f85ba09e1883ae2a8`。
- iOS `1.0 (1011)` 无签名 Debug 配置和串行 Xcode Debug 构建通过，包名 `cn.saydian.ring`、设备族仅 iPhone；该构建早于后续注销流程修复。修复后 `1.0 (1012)` 无签名 Profile 构建通过，仍不是可提交的签名归档；真机头像上传仍待验。
- 国际 API 发布到 `6ea9dd9de91c3f27a452efc1a23ad2f77e88a1b5`，公网 `/global/health/ready` 为 ready，专用头像路由的匿名请求由旧版 404 变为正确的 401。国内 `/health/ready` 仍返回 200。
- 生产头像卷由 `node` 用户持有且可写。备份容器已启动，生成每日归档与 SHA-256。用卷内测试标记做了隔离目录解包恢复，两份文件 SHA-256 相同；测试标记、恢复临时目录和仅含测试标记的归档均已移除。随后生成的正式空卷备份 `say-ring-avatars-20261001T073125Z.tar.gz` 及其校验文件保留，`sha256sum -c` 为 OK。
- 国际数据库发布前 `pg_dump -Fc` 保存到服务器私有备份目录并以 `pg_restore -l` 检查可读；环境配置另有只读备份。头像备份和数据库备份都在同一台主机，不属于异地容灾。
- 国际环境已单独开启 `GLOBAL_SAY_RING_LOCAL_AVATAR_WRITE_ENABLED=true` 并仅重建 `global-api`；容器运行时开关为 `true`、公网健康检查通过。自动部署定时器已恢复 active/enabled。此时服务器磁盘约余 2.7 GiB（96% 已用），未来发布前仍需扩容或实施明确保留策略。
- 后续 Say Ring 源码加入真实注销提示并重建 Android Debug/QA Release，均成功；QA Release 仍为调试证书。详情及新版 APK SHA-256 见 `SAY-RING-APP-STORE-REVIEW-20261001.md`。手机当前在其他应用，本轮未安装新版或执行真实头像上传。

## 待验收

1. 安卓手机当前在其他应用；等用户方便时，以其选定的照片在 Say Ring 登录账号里真实上传并保存。重新打开首页和资料页、重启 App/API 后读取同一头像；旧头像读取与原国际版 App 上传入口仍需单独回归。
2. 未取得真实上传/重启证据之前，不写“头像故障已修复”。现有 App Store 审核包尚未替换。

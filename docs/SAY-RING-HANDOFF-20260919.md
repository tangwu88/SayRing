# Say Ring 阶段性交接与离线恢复记录

## 交接范围

- 日期：2026-09-19（UTC+08:00）。
- App 工作区：`F:\xcodeplace\say-ring`，交接前代码提交 `3220e9a1e502276d960bcf3a84001f7aefa81ba0`。
- 服务端隔离工作区：`F:\xcodeplace\国内电商\say-ring-server-work`，来源策略提交 `38c97a6e6aa87c93f189e01ae17066725fa51b5e`。
- GitHub：`tangwu88/SayRing` 已现场回读为 `PRIVATE`，但仍是空仓库；本轮不推送、不部署。
- 本轮只整理文档和离线交接材料，没有修改业务源码、接口协议、健康算法或设备能力规则。

## 当前 Git 状态

### App

- `main` 工作树干净；远端没有任何 branch，不能把本地提交写成“已上线”或“已备份到 GitHub”。
- 本地历史保留商城迁移、Say Ring 三端身份、戒指路由、多来源健康回读和 Android 构建记录。
- 交接 Git Bundle 是远端为空时的完整恢复依据；接手人必须先验证 Bundle，再克隆到新目录。

### 服务端

- 分支：`codex/say-ring-source-policy`，提交 `38c97a6`。
- 该分支从 `74d85ed` 分出；2026-09-19 fetch 后，`origin/main` 为 `25a5856`。
- 当前分支相对最新主线为 `1` 个本地提交、落后 `15` 个主线提交。不得直接发布或直接合并旧分支；应在最新 `origin/main` 上审阅并三方移植该单提交，重新执行迁移和完整回归。
- Prisma 迁移从未在共享、测试或生产数据库执行。

## 2026-09-19 新鲜验证

### App 自动门禁

- `flutter analyze --no-pub`：通过，`No issues found`。
- `TZ=UTC flutter test --no-pub`：853/853 通过。
- `TZ=America/New_York flutter test --no-pub`：853/853 通过。
- Android `:app:testDebugUnitTest`：4 个 XML，16/16 通过，失败/错误/跳过均为 0。
- Android QA Release：构建成功，包名 `cn.saydian.ring`，显示名 `Say Ring`，版本 `0.1.21 (1004)`，minSdk 26、targetSdk 36。
- QA APK：68,879,452 字节；SHA-256 `B3C8BE39D7F5D2C50BC99AC49044E171D8E574D5258BE73ABF27F3F89949EC84`。
- APK Signature Scheme v2 验证通过；签名仍是 Android Debug 证书，证书 SHA-256 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`，仅供内部 QA，不得上架。
- 解包后的 arm64 `libapp.so` 未发现旧 `saidian.cc`/`saydian.cc`/`.com` 第一方 URL；发现 `https://app.saydian.cn`、国际商城和 Say Ring 更新路径。`vphband.com:9001` 是既有厂商表盘服务，继续按第三方边界处理。
- 源码仍保留国内兼容 API 中的旧域名映射；当前国际 Release 因树摇未包含这些 URL。后续修改必须继续用二进制审计验证，不能仅凭源码全文搜索或本轮结果永久断言。

### 服务端自动门禁

- `pnpm typecheck`：通过。
- `pnpm test`：API 764 项通过、4 项数据库集成按既有环境条件跳过；其余 workspace 测试通过。
- `pnpm build`：通过；保留既有 Sass `@import`/legacy API 和 Admin 大分块警告。
- 以上证明旧分支当前提交可编译、现有自动测试通过，不证明能无冲突套用到落后 15 个提交后的主线，也不证明数据库迁移、生产 API 或真实多设备数据已经验收。

## 当前真实边界

- 2026-09-19 交接时 ADB 没有在线设备，因此没有执行新一轮真机安装或戒指连接。
- 2026-09-13 曾在华为 PPA-LX3 安装并启动 Debug，核心请求到 `app.saydian.cn`；该证据不等于真实 YC/V/TK 戒指三轮连接、同步、断开和重连验收。
- 2026-09-19 现场 GET `https://app.saydian.cn/global/api/saydian-app/v2/support/app-update?product=say-ring` 仍返回 404；更新渠道未接通。
- 未在 macOS/Xcode 执行 iOS 编译、签名或真机测试。
- 未在 DevEco/Harmony 工具链执行 HAP 构建、签名或真机测试；宿主测试不能替代 HAP 验收。
- 真实 `YC`、`V`/`TK` 戒指尚未按供应商、平台、型号和固件完成三轮连接验收。
- `D` 前缀只分类为 Moyoung；当前提供的仓库是眼镜示例，不是已授权的戒指 SDK。取得准确戒指 SDK、字段文档、授权和 HarmonyOS 资料前不得开放连接或声称支持。
- 支付、推送、验证码真实投递、App Store/AppGallery、生产签名及下载更新仍需各渠道独立验收。

## 接手顺序

1. 先校验交接 ZIP 与内部 `SHA256SUMS.txt`。
2. 从 App Git Bundle 克隆到全英文新目录，阅读 `AGENTS.md`、本文件、`SAY-RING-IMPLEMENTATION-20260913.md`、`BUG-RETROSPECTIVE-20260829.md` 和 `REGRESSION-CHECKLIST.md`。
3. 重新执行 `gh auth status`，确认 active account 为 `tangwu88`；重新回读 `tangwu88/SayRing` 为 Private 后，才考虑首次 push。
4. 服务端从最新 `origin/main` 新建分支，不要把旧分支整体合并。先审阅补丁和 migration，再以 `git am --3way` 或人工移植方式应用 `38c97a6`，解决 15 个主线提交带来的冲突并重新执行全量检查。
5. 先修复/配置 Say Ring 更新清单 404，再制作可分发版本；QA APK 只是内部调试包。
6. 有真实戒指后，按供应商 × 平台 × 型号/固件记录扫描、握手、能力、同步、断线和三轮重连证据；未知名称继续 fail closed。
7. 每轮把原因、命令、失败、修复和剩余项写入新记录并提交 Git，不删除本记录中的失败边界。


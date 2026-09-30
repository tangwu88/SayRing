# Say Ring iOS Universal Link 配置记录

## 范围与基线

- 用户要求配置 Universal Link，并在本轮明确确认微信移动应用 AppID；不索取或保存 AppSecret。
- 修改前 SayRing 独立工作树干净，`git fetch --prune origin` / `git pull --ff-only origin main` 成功，基线为 `cbe84bd89a2aa8ca49ea0f15be6083924801ea30`；原始脏工作区未修改。
- 固定包名继续为 `cn.saydian.ring`。登录/API 仍在国际服务下，本轮不改变会员、短信、支付或设备测量逻辑。

## iOS 本机配置

- 仅在已被 Git 忽略的 `ios/Flutter/Local.xcconfig` 写入用户确认的微信 AppID、专属 HTTPS Universal Link 及其 host；真实构建参数和签名资料不提交 Git。
- URL 中的双斜杠使用 xcconfig 空变量展开，避免被当作注释截断。Debug/Profile/Release 均用 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration <配置> -destination generic/platform=iOS -showBuildSettings -json` 回读核实；Bundle ID 没有被本机配置覆盖。
- Profile/Release 继续使用 `Runner/Runner.entitlements`，关联域名由上述 host 展开。Debug 当前仍使用原来的空 `RunnerDebug.entitlements`，本轮未改共享签名能力，不能把 Debug 的参数展开成功写成 Universal Link 可回跳。
- `plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements ios/Runner/RunnerDebug.entitlements` 通过；`git check-ignore ios/Flutter/Local.xcconfig` 确认配置不会入库。
- 现有 Info.plist URL scheme、AppDelegate/SceneDelegate 微信回调代码没有改动；国际接口公开的微信 AppID 与用户提供值一致。未提交一次性授权码或发送验证码。

## 域名侧配置

- 相关服务端仓库为 `tangwu88/saydianserver`，修改前干净主线 `6896df3564cc3ddf48f3af49ec25c12816fc48f0` 与线上 revision 一致。
- 服务端提交 `449227c248d863b0665011f5d032314acb1a1826`：保留原 App 的 `/wechat/*`，单独追加 Say Ring 的国际前缀白名单；新增静态 200 回退页，禁用访问日志，不回显/转发授权参数，保留国际 API 路由和其他路径的拒绝行为。
- 服务端 `pnpm api:docs:check`、`pnpm tools:test`、`pnpm typecheck`、`pnpm test`、`pnpm build` 和 `git diff --check` 全部通过后提交推送。首轮工具测试因 macOS 缺少 `timeout` 中止；安装官方用户级工具并验证真实超时退出后重跑通过，未弱化部署门禁。
- [自动部署 CI](https://github.com/tangwu88/saydianserver/actions/runs/36687970963) 已启动；具体命令、首次失败和成功复验记录保存在服务端 `docs/implementation-log/2026-09-30-say-ring-universal-link.md`。
- 16:14 回读：CI 的全量类型/测试/构建步骤已通过，正在构建验证镜像，生产 revision 仍为变更前基线；专属链接此前读取仍为 HTTP 404、无重定向，Apple CDN 仍只有旧 App 关联。待自动部署完成后读取线上 revision、AASA、静态链接及 Apple CDN；代码推送不等于已上线。

## 尚未验收与限制

- 微信开放平台被浏览器站点访问策略阻止；没有通过其他浏览器、网络工具或账号接口绕过。需账号持有人在对应移动应用的 iOS 开发信息填写固定 Bundle ID 与本轮专属链接（末尾保留斜杠），保存后再进行真机联调。
- 当前选定的 iPhone 15 Plus 在 Apple 平台的上一轮回读为 Processing；本轮 `devicectl list devices` 又显示目标 unavailable。没有安装或启动其他手机。
- 本轮仅变更忽略的本机构建配置与文档，没有新的 Dart/Swift/Android 运行时代码；未重跑 Flutter/Android 全量构建，也未重新生成 iOS 安装包。旧包仍包含占位配置，不能拿旧包验证新链接。
- 磁盘可用空间约 0.5 GiB，未为本轮进行广泛缓存清理。新机有效描述文件、重新签名的 Profile 包、微信授权回跳、取消/拒绝/冷启动均待真实验收。
- 只读尝试 `swcutil help` 提示必须 root；未提升权限运行。关联文件结构与公开 HTTPS 回读独立验证，不能代替 iOS 系统关联结果。

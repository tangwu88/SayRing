# Say Ring

智能戒指伴侣 App，Android/iOS 包名固定为 `cn.saydian.ring`；当前 iOS 仅支持 iPhone。
本轮开发重点为 iOS，共享 Flutter 代码回归 Android；鸿蒙不在本轮范围。

## 先读这些

- [最新修改与测试记录](docs/CHANGE-TEST-LOG.md)
- [开发交接与离线导入](docs/SAY-RING-DEVELOPER-HANDOFF-20261005.md)
- [工作规则](AGENTS.md)及[回归清单](docs/REGRESSION-CHECKLIST.md)
- [既有页面模块与减包记录](docs/SAY-RING-CLIENT-CLEANUP-20261004.md)

## 当前产品边界

- 默认简体中文，保留多语言。主导航为健康、设备、我的；商城隐藏。
- 登录页保留手机号/邮箱入口和无需登录的本机模式；登录可用性依服务端真实配置。
- 第一方请求只用 `https://app.saydian.cn/global`，更新标识 `say-ring`；禁止跨产品或跨环境兜底。
- QRing（包括 R21）、CoolWear/LuckRing（HR01/HR05/K80/R7/R7Y/R7Pro）与既有 Yucheng/VEP 按严格规则路由。
- 名称只负责路由，功能依真实握手、平台及已实现的数据链路开放。未确认设备、数据或 OTA 不猜测开放。
- 健康记录使用加密本地存储；账号、本机模式和远程只读关爱数据隔离。未知值不补造成真实测量。
- 原型/国际健康 App 历史文档仅供追溯，不代表戒指 SDK、渠道或实物验收已通过。

## 开发入口

`lib/ui/pages.dart` / `lib/ui/pages/` 是当前功能页面入口。
`lib/ui/prototype_pages.dart` / `lib/ui/prototype/` 保留原型页面 API 和库私有成员关系。
新增实现放对应模块；共享组件在 `lib/ui/widgets/`，不要重新堆入兼容入口。

```sh
flutter pub get
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --reporter compact
TZ=Asia/Shanghai flutter test --no-pub --reporter compact
flutter run --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
```

构建必须显式传入版本和递增构建号；签名、平台依赖、原生测试及完整命令见[交接说明](docs/SAY-RING-DEVELOPER-HANDOFF-20261005.md)。
`pubspec.yaml` 的历史默认版本不代表当前发布。QA 包不是正式 Android 商店签名。

## 安全与验收

凭据、签名密钥、真实照片和健康数据不入 Git 或交接包；合作 SDK 只限授权开发。
保留绑定和数据的 iPhone 测试使用 `tool/drive_ios_preserving_data.mjs`，禁止默认卸载式 `flutter drive`。

主机测试不代替实物。真实距离重连、后台、各 CoolWear 型号、拍照及可信 OTA 仍按最新记录逐项验收。
已有 TestFlight/审核与本地新构建分开；本轮整理不会自动上传、改审核或安装到手机。

正式 Android 发行须遵循[生产发布门禁](docs/release/ANDROID-PRODUCTION-RELEASE.md)。
原国际基线、Veepoo/API 接入历史分别见[国际交接](docs/INTERNATIONAL-HANDOFF.md)、[SDK 说明](docs/veepoo-integration.md)、[API 缺口](docs/api-gap.md)。

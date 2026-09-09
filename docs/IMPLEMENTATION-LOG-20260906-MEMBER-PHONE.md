# 2026-09-06 会员资料注册手机号展示

## 开工基线与范围

- 基线：`e3ffd36785ab9275626654b7459bc00cd6ed7a92`；已执行远端更新，当前分支与上游无提交差异。
- 工作区另有同一资料页的鸿蒙资料/关爱整改；两组修改在资料页重叠，因此在保留双方功能的前提下合并验证，没有覆盖既有改动。
- 用户要求：iOS、Android、鸿蒙三版的会员资料显示注册时手机号。
- 数据来源：已登录账号的 `/api/v1/member/member/my` 返回 `mobile`；没有返回时显示“未获取”，不以登录名、设备信息或收货地址手机号冒充注册手机号。
- 修改范围：Flutter 共用资料页（覆盖 iOS/Android）、鸿蒙资料页与针对性测试；手机号只读展示，资料保存请求不携带 `mobile`。

## 实施记录

- Flutter 共用资料页已增加只读“注册手机号”信息块，覆盖 iOS 与 Android；资料刷新后会同步显示服务端 `mobile`，资料保存请求仍不携带该字段。
- 鸿蒙资料页已增加同样的只读信息块；未返回手机号时显示“未填写”，不会以昵称、登录名或设备标识替代。
- 资料入口说明同步收敛为“注册手机号和基础资料”。

## 验证结果

- `dart format`：Flutter 页面与定向测试均已格式化。
- `flutter analyze --no-pub`：通过，无诊断项。
- `flutter test --no-pub test/login_page_test.dart`：13 项通过。
- `node --test harmony-native/tests/inner-pages.test.mjs`：19 项通过；包含手机号只读展示及保存请求不携带 `mobile` 的断言。
- `TZ=UTC flutter test --no-pub`：403 项通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：403 项通过。
- 集成批次已修正 `SaydianApi.ets` 的 ArkTS 显式类型问题；鸿蒙 UTC/Asia/Shanghai 各 204 项完整测试通过，Debug HAP 与 Release APP 均编译通过，Debug 包已在 nova 14 覆盖安装并验证资料页显示。

## 构建环境备注

- DevEco 命令行的 `DEVECO_SDK_HOME` 应指向 `/Applications/DevEco-Studio.app/Contents/sdk`，而非其 `default` 子目录；项目原路径含中文，构建器拒绝该路径，因此只复制到临时英文目录进行验证，未移动或修改正式工程。

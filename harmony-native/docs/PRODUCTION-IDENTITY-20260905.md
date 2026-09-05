# HarmonyOS 生产应用身份记录

## 已确认

- 华为开发者主体：广州领科网络科技有限公司。
- AGC 应用：Saydian赛电。
- APP ID：`6917615560681044373`。
- 生产 bundleName：`cc.saidian.app.hm`。
- 所属项目：Saydian赛电。
- Push Kit：已在 AGC 保存开启。

## 包名决策

- `cc.saidian.app` 已被同账号 Android 应用占用，AGC 不允许 HarmonyOS 应用重用。
- `cc.saidian.app.harmony` 包含 AGC 保留词 `harmony`，表单校验不允许提交。
- 复用账号中已有的 `cc.saidian.app.hm`，并将本地工程对齐该身份。

## 仍未完成

- 生成并安全保管与该 APP ID 匹配的发布证书、Profile、私钥和密码。
- 在极光保存相同的 HarmonyOS 包名，并上传该 APP ID 的 Server key JSON。
- 在原生 HarmonyOS 真机验证签名安装、前台/后台/进程终止推送和覆盖升级保留数据。

证书、Profile、Server key、密码和私钥不得进入 Git、交接包、截图或日志。

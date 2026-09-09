# 鸿蒙离线运动记录与资料回读核验（r10）

## 已复现问题与范围

- P2：运动记录页在未连接手表时整页拦截；服务断开还会清空设备 snapshot，因此仅移动页面条件不能恢复已入库历史。预期：同账号离线仍可查看本机运动历史和详情，仅同步要求连接且设备支持。
- P1：个人资料保存只检查 POST 成功和同账号 GET 回读，没有比较实际提交字段；服务端忽略昵称、身高等字段仍提示已保存。预期：规范化后逐项核验，只比较提交字段，缺失值不能猜成 0，部分失败明确提示。
- 修改前已检查 Git 并 fetch/prune，基线 `03adffc`；保留主线程未提交的文档和配置，不拉取覆盖。已阅读 AGENTS、修改索引、复盘与回归清单。
- 本批限鸿蒙本地存储查询、服务及两个页面局部；不改真实账号/关系，不操作手机，不执行任何手表写入，不新增实时运动/GPS。

## 修改与验证

- 增加按 owner+sport 独立查询，不使用全局最近记录上限，不迁移或重新归属旧历史。页面/服务均拒绝账号变化后的迟到结果。
- 资料保存以发出的规范化字段为快照回读核验，未提交头像、手机号等字段不比较也不追加写入。
- 定向、双时区全量、Debug/Release 构建及签名结果待追加；先前 r9 真机结果独立保留，不等同 r10 已真机通过。

## 自动化与首轮编译

- 直接执行生产 AccountClient、WearableHealthStore（SQLite 适配）、VepWearableService：87/87；执行生产 Index 页面方法：10/10。覆盖忽略每个资料字段、相对头像/数值等价、缺失性别不转 0、账号切换、失败留存、离线详情与返回。
- 页面测试首次抽取方法时错误带入后续 ArkUI Builder，导致 Node 解析失败；仅修测试方法边界，失败保留 `/tmp/saydian-harmony-r10-page-fixture-parse-failure.log`。不放松生产页面逻辑。
- 全量 UTC 404/404、Asia/Shanghai 404/404；失败/跳过均 0，`git diff --check` 通过。
- 首轮 Debug 编译失败：Index 新建 `ApiError` 传入 `Error` 参数触发 ArkTS 名义类型检查（646 行）。补显式 `as Error`，不改变运行行为；原日志保留 `build-debug-r10-offline-profile.log`。再次全量/构建待追加。

## 最终锁源与产物

- 补类型声明后重新全量：UTC 404/404、Asia/Shanghai 404/404，失败/跳过 0，日志 `/tmp/saydian-harmony-r10-final-{utc,shanghai}.log`。
- 正确同签名暂存工程 `/tmp/saydian_harmony_build_20260906_0952`，未改变 signing；Debug 16.542 秒、Release 16.242 秒均成功。最终构建日志在 `/tmp/saydian-harmony-session.5ERCEO/build-{debug,release}-r10-offline-profile-final.log`。
- 两包官方 `verify-app` 成功；证书链与 r2 一致，内嵌 Profile 与已验证 r9 逐字一致。实核包名 `cc.saidian.app.hm`、`0.1.3(7)`，min API 12、target API 26；Debug/Release 各自 buildMode 与 debug 标志正确。
- Profile `type=debug`、登记设备数 2；证书及 Profile 有效期 2026-09-06 10:03:29 至 2027-09-06 10:03:29 中国时间。仍为开发签名，不是正式 AppGallery 发行包。
- 产物复制至 ignored `artifacts/three-platform-20260907/harmony/`，r9 两包保留；新增 r10 Debug/Release 两包及校验/README，不复制私钥、原始 Profile、设备 ID 或调试日志。
- r10 Debug SHA-256 `24b2ac94defa8fdc6c909a15f0cb5498ae7b05873431922c4d7b6d1bcbcc7029`；Release `cab657b4c976460566a794cbc5fcac7bc32adbce5bae0828c7677bbeb7935b4a`。两包 ZIP 完整性通过。
- 清理旧页面连接全拦截分支，复用已有记录详情、账号代次及头像 URL 规范化，未引入临时调试入口。没有操作手机/登录/手表，r10 真机及提交推送由主线程完成。

## 主线程 r10 真机补证

- 已使用官方验签同签 r10 覆盖并独立启动，原登录和个人资料保留。
- 断连进入运动页，真实出现“已有记录可离线查看”；同步按钮禁用、添加设备可见。本账号没有已归属运动记录，未制造非空样本，非空历史详情仍以自动化为证，待真实运动记录补验。
- 个人资料未修改任何字段，提交后真实显示“个人资料已保存”，昵称、生日、身高、体重原值保留；验证正常提交与新增回读核验路径，不等于每个字段实际变更或头像更换已验收。
- 本节为主线程实际结果转记；与下一批 r11 关爱权限收口分开，不改 r10 源码或包。

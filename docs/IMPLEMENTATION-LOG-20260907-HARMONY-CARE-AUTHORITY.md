# 鸿蒙成员健康单项权威结果（r11）

## 问题与边界

- P1：`AccountClient.careMetric` 在 typed 返回空、404/500 等情况下另查无 type 日总表；`careMetrics` 预读总表后也会补旧值。403 原本有门禁，但空或失败仍可能重现没有单项授权保证的数据。
- 单项成功记录保持真实值；200 空就是空，明确 403 才是未授权；404/500、超时/离线显示读取失败，不能改为成功或猜成未授权。后台本身错误不能用总表绕过。
- 先前 iOS 撤销 HRV 现场失败由主线程记录；本批仅以直接执行生产 AccountClient 的合成反例验证客户端路径，不伪装为取得现网原始响应。
- 修改前完成 status、remote、fetch/prune，当前起始 HEAD `3d330b1`。主线程正在整理提交 r10，明确不覆盖并行改动，不提交/推送本批。
- 本批只改鸿蒙 AccountClient 的关爱读取和测试，不修改服务器、API 地址、自有健康同步、活动独立接口、共享授权或手机。

## 预期与验证

- 删除无 type 日总表预读和全部回退；概览复用单项方法，仍按每批 3 项请求。
- 不支持/缺失单项接口的旧后台现在显示不可用；这是一致权限边界下的可用性代价，不表示服务器已修复。
- 直接生产方法反例、双时区全量与 Debug/Release 同签名构建待追加；r10 原包保留，r11 不操作手机。

## 修复与测试

- 删除无 type 日总表预读和两套回退，概览复用 `careMetric`，净减少生产重复代码；7 个 daily typed 与 ECG/身体成分/血液成分 3 个专用接口保持原 member/date 参数。
- 平台呈现边界按主线程确认：鸿蒙离线/超时为逐项 unavailable+空 records，Flutter 原先为整体读取失败；两者均不得补 ready/empty。401 保留登录失效抛出，403 才是 unauthorized。
- 第一轮正例夹具误把 HRV 字段写为 `HRV` 而非真实映射 `HRVData`，2 例失败；仅修测试数据，生产映射不改。原定向及双时区失败日志保留 `/tmp/saydian-harmony-r11-positive-fixture-failure.log`、`/tmp/saydian-harmony-r11-fixture-failure-{utc,shanghai}.log`。
- 使用修正后的同一套测试，在内存只读载入旧 `3d330b1` AccountClient：52 项中 15 项明确失败；包含空/404/500/离线被总表恢复或多余总表读取。旧源码未写回工作区，日志 `/tmp/saydian-harmony-r11-before-corrected-fixture.log`；最初夹具失败记录也保留。
- 最终关爱定向 52/52；完整 UTC 423/423、Asia/Shanghai 423/423；失败/跳过均 0，`git diff --check` 通过。日志 `/tmp/saydian-harmony-r11-care-final.log`、`/tmp/saydian-harmony-r11-final-{utc,shanghai}.log`。
- 200 空列表/空 chart、404/500、HTTP 与业务 403（含字符串）、401、离线/超时均有真实生产方法执行测试；正常 typed HRV/ECG 值仍 ready，单项仅一个健康请求、概览仅 10 个健康请求。

## r11 构建与交付

- 正确暂存工程 `/tmp/saydian_harmony_build_20260906_0952`，仅同步源/资源，不修改原签名；Debug 14.314 秒、Release 14.201 秒成功，没有新增编译失败。
- 两包官方 `verify-app` 均成功、ZIP 完整性通过；证书链与 r2 相同、内嵌 Profile 与 r9 逐字一致，2 个登记设备，仍为开发签名，不是 AppGallery 发行包。
- 直接从 HAP 读取包名 `cc.saidian.app.hm`、`0.1.3(7)`、min API 12、target API 26、phone/tablet；Debug/Release 的 buildMode 与 debug 标志均对应正确。
- Debug `/tmp/saydian-harmony-session.5ERCEO/Debug-r11-care-authority-development-signed.hap`，SHA-256 `65b723fb667d3bf9a4ca6a137fbcdfcf9dc8e4ac33e5051ee5e606c3e14b7968`。
- Release `/tmp/saydian-harmony-session.5ERCEO/Release-r11-care-authority-development-signed.hap`，SHA-256 `8efc84021f9671c8159744b270b2e31a6dc8b2b03cb4a152a72c17f9743e7fb1`。
- 已复制到 ignored `artifacts/three-platform-20260907/harmony/` 独立 r11 文件名，保留 r9/r10 四包，更新 SHA256SUMS/README-QA 与兼容签名边界文档。源码锁定，没有操作手机、共享开关或服务器；真机撤销/恢复复验和提交由主线程完成。

# 2026-09-06 鸿蒙账号隔离与健康云同步

## 开始记录

- 基线：主任务已同步 `c5a28e6`，本子任务开始时工作树干净。
- 首次常规 `git fetch --prune` 返回 Repository not found；改用已有仓库账号的独立认证后 fetch 成功，未改全局账号、未输出凭据。
- 已阅读 AGENTS、跨端问题复盘、回归清单及最近 Android／鸿蒙趋势 QA；原始素材保持只读。
- 原因：鸿蒙健康数据只按设备保存、未绑定账号，没有上传队列，因此换号可能看到旧设备记录，鸿蒙新测量也不能进入远程关爱。
- 修改范围：鸿蒙健康存储、设备服务、账号客户端、新增纯 TypeScript 归属／上传模型与队列测试。页面由并行页面任务接入，避免重叠。
- 预期：旧无归属数据库完整保留隔离；新记录限定当前账号与设备归属时间；成功确认后才移出上传队列；换号、断连、旧回调不得跨会话写入。
- 边界：不操作真机、不登录、不发送关爱邀请；真实后台回读、完整构建和真机验收由主任务统一执行。

## 验证记录

- 第一轮纯模型／账号／关爱定向测试：UTC 64/64 通过，含新增 10 项；`git diff --check` 通过。
- 实施中单个补丁同时删除／重建同一路径被工具拒绝，未修改文件；拆分为两次受控补丁后成功，未删除原始数据库或设备文件。
- 第二轮前再次 fetch 成功；保留已确认的并行页面、支付、图标等修改，未 pull 覆盖。
- 追加 SQLite 上传内容 CAS 与重新接管边界后，UTC、Asia/Shanghai 定向测试各 66/66 通过。
- 补跑设备／趋势回归首次 29/30：旧静态断言仍要求无账号索引名称和 since18 分批写入循环；改为验证 owner 复合索引、全部逐行事务写入及禁用 since18 API。真实 SQLite 行为由新模型测试覆盖，未放松加密／全量保存要求。
- 2026-09-07 00:11（中国时区）收尾：账号、关爱、owner 上传、健康趋势和设备定向回归 UTC／Asia/Shanghai 各 96/96 通过；差异检查通过，未调用真机或写服务端。
- 待补：主任务 ArkTS 编译、全量双时区与真机回归。
- 补充同账号数据库真正关闭／重开测试：UTC 定向 97/97 通过；已明确 owner 的旧记录、待上传队列仍可读，另一 owner 不可读。
- 主任务首次 CompileArkTS：两处数据库事务 `throw error` 被 `arkts-limited-throw` 拒绝；改为 `throw error as Error` 保留原错误与回滚语义，已交主任务重新编译。首次补丁夹带不存在的日志锚点被工具拒绝，未修改文件；随后分开补丁成功。
- 最终补跑 Asia/Shanghai 定向 97/97 通过，与 UTC 97/97 一致。真实 SQLite cold-restart 测试覆盖明确 owner 历史／待上传可读、其他 owner 不可读；已同步完整字段不会被旧回执覆盖，回执失败仍可重试。

## 2026-09-07 二次审查：测量迟到结果 P1

- 独立复盘发现：旧账号 cancelMeasurement 捕获旧 values 后 await stop，返回时未核会话，会覆盖新账号 measurement；旧 start Promise 和常驻 SDK push 也只核 metric/running。纯 helper 测试不足以覆盖真实服务竞态。
- fetch 成功后修复 VepWearableService：为每次测量捕获 owner／账号代次／连接代次／测量代次，SDK listener 使用对应闭包；每个 start/stop await 后重新核对，旧完成不得写值、落库或释放新操作锁。
- 账号切换立即失效旧监听，串行排空停止、SDK 断连状态和旧 start/stop Promise；失败保留门禁并允许手动重试。首次登录 SDK 未初始化时不强行发送不存在的断连指令。取消心电仍不保存完成记录。
- 给单位／闹钟 adapter 提供 runDeviceCommand 门禁；每个多步事务通过 assertCurrent 在 await 前后校验，只有原连接／操作可释放锁。无需 Index 新生命周期 hook。
- 同时修 P2：model 只读取 SDK 真实 modelName，不再把 deviceFullVersion 当型号；firmware 字段不变。
- 官方 HAR 只读检查：文件实际为 gzip tar，首次 unzip 失败后改 tar 读取声明；disconnect 返回 void，ConnectionState 为 UNINITIALIZED／READY／BINDING／CONNECTED／DISCONNECTING／DISCONNECTED，据此按真实状态确认断连，未猜不存在枚举。
- 新增 wearable-measurement-session.test.mjs 直接执行生产服务，mock 仅限平台／SDK；首轮 7/7 通过，追加首次未初始化登录回归。未操作真机／写服务端，原生编译交主任务。
- 最终测量／owner／账号／关爱／趋势／设备定向测试：UTC、Asia/Shanghai 各 105/105 通过，含 8 项真实生产服务异步竞态测试，无失败或跳过。

## 2026-09-07 整合构建接管

- 主任务追加授权本子任务构建，继续不安装或操控手机。只机械同步 entry/src、AppScope 到 `/tmp/saydian_harmony_build_20260906_0952`，保留该暂存工程已有赛电开发签名，不覆盖根 build-profile；未使用其他签名工程。
- 首次提前 Debug 编译／签名成功，40 秒，33 tasks；测量修复无 ArkTS 错误。沿用厂商资源重复、sourceMapsPath、may-throw 和旧页面 show API 警告，未关闭检查。
- 同期全量 UTC 281 项中 280 通过；唯一失败为 layout-contract 的 heading 锁条件精确字符串随并行设备设置锁变化而过时，已交页面负责人更新保留原支付锁及新设置锁。Shanghai 因串行前项失败未执行，不能记双时区全量通过。
- verify-app 首次拒绝 outCertChain 的 `.pem` 后缀，未触发签名写入；改 `.cer` 后验证成功。证书链第一张是 Huawei 根证书，不能误当应用签名；逐张比对前一已安装包导出链，三张指纹全部一致，开发证书仍为 `B8:3E:67:55:0F:43:77:81:AF:8D:BD:E2:99:47:5C:CB:D3:59:17:49:10:B1:C6:2D:D3:11:F3:DE:A9:20:C7:B9`。
- 提前包保存在 `/tmp/saydian-harmony-session.5ERCEO/Debug-measurement-development-signed.hap`，SHA-256 `5891decc8495d6737e7a8b158206b784986729989f689b60af4281851f777596`，已交主任务按需测量；仅开发签名，不是 AppGallery 发行版本。单位／闹钟页面仍在整合，最终双构建另行记录。
- 单位／闹钟首次整合锁定后，UTC、Asia/Shanghai 全量各 282/282 通过；Debug 28 秒、Release 26 秒构建成功，均经官方 verify-app 验证且导出证书链与前一已安装包字节一致。产物暂存同目录的 `Debug-final-development-signed.hap`（SHA-256 `54e6f82d6e45db75d702678cc52f76180d1289e28962c87de638d0dda976ab27`）与 `Release-final-development-signed.hap`（`6c146993fad666e3100704ffc8a6cf9f75567919f6a1e302bcbfea23a5818d0c`）。
- 主任务随即发现设备设置父页摘要需跟随子页保存刷新，页面负责人继续修复；上述包暂不安装，追加修改后重跑并另存 r2，不把该次构建冒称包含后续修复。磁盘剩余约 11 GiB，无清理其他构建、签名或设备数据。
- r2 页面锁定后同步重编：UTC、Asia/Shanghai 各 284/284 全量通过，0 失败、0 跳过；Debug 33 秒、Release 34 秒成功，均 33 tasks。差异检查通过。两个 r2 包均官方 verify-app 通过，证书链与前一手机包字节一致；提取 profile 与此前 verify-profile 成功的文件字节一致，`type=debug`、`bundle=cc.saidian.app.hm`、`appIdentifier=6918741466092469448`。
- 本轮可交真机的最终包位于 `/tmp/saydian-harmony-session.5ERCEO/Debug-r2-development-signed.hap`（SHA-256 `a8e597e9e8c6a5451f7d8b1f036e990fb260c96702cdc641eecded10373aa68e`）及 `Release-r2-development-signed.hap`（`b850d38df24b1ed7b1eb820c01ec479df1bfc70442e7c59806df4806720d9b5c`），包含测量账号隔离、单位／闹钟真实读写与父摘要回读、型号和列表响应修复。unsigned 包和失败／最终构建日志保留同目录；未覆盖旧包。
- 主任务已收到最终路径，安装和真机验收由主任务执行；本子任务未安装、未连接手表、未登录或写远端账号数据，未提交／推送。Release 构建成功但使用开发签名，不能称 AppGallery 正式发行通过。

## ECG 跨端波形验收阻断：单位与编码未公开确认

- 仓库锁定 HAR 与官方示例所带 HAR 的 SHA-256 均为 `60cdffa08076d7167e90736cd8ea433b62dbf562d295c5275acfc4bfcdd40bd2`。`EcgModels.d.ets` 的实时 waveform 只有 `samples`，历史只有逐秒 waveform／sampleFrequency，没有单位、gain、是否已校准或编码版本。
- `EcgWaveformDecoder.d.ets` 内部有 `convertToMvWithValue(value, ecgType, isDevice?)`，但不在公共 Index 导出；EcgService 的型号解析为 private，source map 没有 sourcesContent。仅凭转换方法名称不能证明公开回调已经转换，也不能对回调再次换算。
- [官方 API](https://github.com/HBandSDK/HarmonyOS_BLE_SDK/blob/main/docs/API.md) 指向 HAR 类型声明；[官方 ECG 示例](https://github.com/HBandSDK/HarmonyOS_BLE_SDK/blob/main/sdk-demo/entry/src/main/ets/pages/subPages/EcgPage.ets) 只展示心率、HRV、QT 和进度，不绘制或声明 mV 波形。因此本轮不新增 `rawVersion=2`，不改变原始样本。
- 当前 Flutter 远程 `_CareEcgRecordCard` 仅在 `rawVersion >= 2` 且真实信号可用时展示已校准波形；鸿蒙上传真实点但不造校准版本，因此这部分远程波形仍为未验收。需厂商明确实时／历史样本单位和设备编码，或另行设计明确未校准的三端原始波形契约与渲染，并验证服务端不会剥离字段。客户端上传 ACK 不代表远端字段一致，当前保留门禁，不改 Flutter。

## 新后端迁移契约风险（本次不放松确认）

- 当前 API_BASE 仍为 app.saidian.cc；邻近新服务端的 V1 acceptedIds 是服务端 legacy hash／UUID，而非客户端 record.id，daily 请求也未发送客户端 ID。切换新服务端前需要稳定 client_id 回显或明确的全接收契约；不能猜测 acceptedIds 不匹配也算成功。
- 新服务端 jrjk 忽略客户端 date 并按接收时刻保存、distance 单位为 meter；现有鸿蒙值为 km。不得在迁移前宣称活动源时间／单位已验收；需真实源数据回读和双方契约确认。

## 实施结果与验收边界

- 新建账号隔离表，原 `wearable_health_record`／`wearable_binding` 原样保留；没有把无归属历史自动归给升级后账号。
- 主动连接／冷启动恢复建立新的采集起点，只有同会话自动短重连可续用起点；此前未归属历史及混含前一佩戴者数据的当日累计活动不作为当前账号数据上传。已经明确 owner 的本机历史仍保留查询。
- 可见变化：升级后首次连接不会自动展示旧未归属库，也不会把手表上本次接管前的其他佩戴者记录展示为当前账号；同账号重启仍可读取已经明确归属并入库的记录，采集起点不作用于这些持久化查询。
- 账号生命周期集中观察：登录开始、成功、退出、失效均推进或核对会话；健康读取、队列及 SDK 异步返回核对账号与连接代次。
- 上传沿用原后台 `daily-date`、`jrjk`、`e-c-g`、`bodycomposition`、`bloodcomposition`；HRV／血压／睡眠等字段与 Flutter 兼容，固定中国时区，缺失字段不补零。
- 上传保留本机队列；显式部分拒绝／失败不标记成功，确认时按发送内容比较更新，完整版本的新记录不会被旧回执覆盖。
- 手表运动记录旧后台没有确认的上传契约，保留为本机记录，不伪称云同步成功。ECG 不自造校准版本，上传 SDK 原采样率与真实点。
- 云端旧接口是否保留成分记录原始时间、幂等键，以及三账号逐字段回读仍待主任务真机确认。网络回执成功不能替代远程数据一致性验收。

# 当前华为 R7 Ultra 与 LuckRing HRV 对照（2026-11-04）

## 范围和当前结论

用户确认同一只 R7 Ultra 在当前连接电脑的华为手机 LuckRing 可显示历史并手动测量。本轮继续核对原厂可见结果与真实 SDK 数据，不以之前 type62 ACK、超时或通用能力位判定有效 HRV，也不照搬未验证的数值或单位。

工作分支 codex/r7u-auto-history-20261104，起点 34fb300e5a36a406683a1ccf2c223d6dabb02505；运行源码 af1179548a0b98ca1b521ad0d9bfcc86cdaf61d9。开始时工作树干净，fetch origin 成功，自己远端同 SHA。检查共享集成分支到 e59c088 后，以保留原历史修复的 merge --no-commit 集成相关 HRV 窗口终态修复 4631594 及两个后续记录。仅 CHANGE-TEST-LOG.md 索引冲突，保留双方条目；没有覆盖历史同步实现、强推或推进 main。

## 本机原厂 APK 静态对照

- 只读取已安装 LuckRing 1.6.2（90）的公共可执行包，没有读取其账号数据库、密钥、用户年龄或历史记录。APK SHA-256 E9BCF0B10603CF6F9EF1A034A6050502CA291EF8690D9B1933EDE43532AFCBC5，与上轮引用的原包一致。私有反汇编和原始证据留在仓库外，不提交厂商源码。
- 原厂 CheckDataPresenter.sendStartCmd 的 HRV/压力入口均调用旧 send_k6_data_type_real_hrv。原厂 K6_DATA_TYPE_REAL_HRV.toCEDevData 直接确认 cmd=1、type=45。当前实际 AAR 的 sendHRVSwitch / sendStressSwitch 也落到 type45，而 sendRriHrvCmd 落到 type62；不能只凭方法名认定两者均为毫秒 HRV。
- 原厂 BluetoothHeartRVData 把 getHeartNums 原值保存到 HeartRvNumber，另调用 AppUtils.getRomHrv 写入 HeartRvRomNumber。getRomHrv 读取出生年月并按年龄分段返回 Random.nextInt(21)+基数，不使用 RRI 样本。此为静态代码路径证据，没有执行或修改原厂数据库。
- 原厂 CheckDataPresenter HRV(checkType=2)结果回调读取 getHeartLastData().getHeartRvRomNumber，首页当日 HRV 路径也读取该字段并标为毫秒。它说明这版 APK 存在生成显示值的路径；不能扩大成所有型号、所有版本和所有历史值都已证明相同，更不能仅以用户看见数值就认为已验证真实 RRI。
- 用户 SDK Guide 明确使用 sendRriHrvCmd，以及 RCVD_DATA_TYPE_RRI_HRV / k6_RRI_HRV_DATA。旧 iOS 指南同时保留旧 HRV 与 RRI，旧结构 heartNum 没有足够明确的毫秒指标契约。Say Ring 继续保留真实记录、原始指标来源与未知状态，不把 type45 压力/旧指标静默转成毫秒，不加入年龄或随机填充值。

## 手机操作与中断

- 手机仍为普通正式版 1.0.10（1242），已从设备拉取 base.apk 核验 SHA-256 0b0ed1cc44771e4d801b08d7f532d2f4ea69011427b171e61df9a456db66230b，与上轮正常 Release 相同，非临时诊断包。
- 初始首页实际可见今日心率和血氧各27个点；这仅为原自动同步任务继续到达的页面证据，不代替 HRV 验收。
- 准备查看设备基线时出现来电系统覆盖层，已立即停止触屏，没有回答/拒绝来电；后续只读确认通话结束，但屏幕锁定。已请求本人解锁。本轮尚未启动 LuckRing、HRV测量或改变戒指模式/监测频率，不能声称完成原厂实测。
- 保留账号、绑定、数据和原厂 App 可用状态；没有卸载、清数据、解绑、恢复出厂、启用全局蓝牙抓包、修改锁屏/常亮设置，或绕过安全确认。

## 已合入的已有修复

lib/services/app_controller.dart 与 lib/ui/pages/health.dart 合入共享分支已复现的窗口终态修复：同一真实180秒上限供界面和控制器共用；旧窗口失去操作归属后结束等待，不显示/停止新轮测量；显示单调等待时钟，不把时间当设备进度。相关三个回归在 test/ui_shell_test.dart。它处理界面收尾，不代表解决 type60/61 未返回。

## 本轮验证与未验收

验证执行结果随后追加。当前原厂真机对照尚因锁屏未执行，有效 HRV 生成、真实历史读取与具体固件协议契约均 OPEN。任何宿主测试、构建、协议 ACK 或原厂显示值都不替代真实 HRV 验收。Windows 无 Xcode，iOS Debug/Profile 本轮不能本机执行。没有发布下载页或商店。

## 实际续测和验证结果

- 用户解锁后，Say Ring 正常设备页确认原 R7 Ultra 已连接、无手动测量窗口。切换前没有完成全部监测设置读回；不把未主动更改设置等同全量设置保留验收。
- 普通停止 Say Ring 并打开 LuckRing 后，原厂首页显示暂无设备。没有代用户点击新绑定，要求用户自行连接同一只戒指且不得确认清空/初始化；用户回复已连接。之后原厂我的设备页实际显示 SD-RING-R7 Ultra 已连接，确认非替代型号。
- 原厂正常页面确实显示今日 HRV 历史，并继续有后续时间点；本轮没有读取原厂数据库来证明这些具体行的底层来源。与前述静态生成显示路径分开记录，不能称这些显示数值已经证明是真实 RRI。
- 16:21:59左右通过 HRV 的立即测量→佩戴说明→下一步开始一轮，确认实际检测中。随后截图明确是红叉失败及重试；原厂自身期间存在多次 connectGatt 重连尝试。本轮未捕获可解码的逐帧60/61结果，不能将没有日志当成没有空中数据，也不能断言该轮失败由固件、不支持或特定手机导致。
- 第二轮16:47:46左右同一正常入口再次进入检测中，后续采样只看到已返回首页并有较新的历史时间点，未捕获终态、手动成功值及其来源，因此该轮未验收，不冒充手动成功或再次完整超时。没有为证明通过而持续反复测量。
- 原厂日志仅限该应用UID，私有保存在仓库外；没有启用全局HCI记录。原厂正常连接日志存在其自己的混合配置发送，未把它解释为 Say Ring 本轮发送，更没有用默认值回写去恢复未知设置。原厂设置全量前后比对未完成。
- 正常退出检测后停止原厂进程并回到 Say Ring；LuckRing 仍为 enabled=0（系统默认可用）、未卸载/禁用/清数据。本轮原普通Release1242未替换、未解绑/清空戒指、未切账号。恢复后的连接状态另核对，不把切换前已连接当最终恢复通过。

### 本机可重复检查

- dart format --output=none --set-exit-if-changed lib test 通过；flutter analyze --no-pub 无问题。
- TZ=UTC 与 TZ=Asia/Shanghai 的 flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn 各2003项通过。
- node --test 的四个实际AAR/协议检查（coolwear_android_hrv_sdk、coolwear_android_hrv_protocol、coolwear_android_readonly_sdk、coolwear_history_sdk）15项通过、0跳过。
- 首次Node命令遗漏 ANDROID_HOME，导致只读SDK/历史SDK两项环境失败，并包含仅Mac原生接收测试的一项跳过；补齐实际Android36平台路径后，对可执行的四项文件全部重跑通过。失败日志保留，没有改生产源码掩盖环境错误。
- PowerShell 写索引第一次 -replace 拼接未加括号报错；只影响文档索引，后用显式字符串替换纠正，双方合并条目和新增记录保留。Windows rg 字面通配路径失败后按实际目录/文件读取，不视为SDK缺失。
- Android Debug1243、testDebugUnitTest（103项，失败/错误/跳过均0）、releaseRuntimeClasspath 与普通正式 Release1243 均成功。apksigner、生产Manifest/JPush、双ARM ABI、zipalign检查通过；正式证书保持原证书。ARM32旧原生库4KB边界仍按既有审计记录，不声称所有市场审核通过。
- 候选1.0.10（1243）正式APK SHA-256 EE8FD639EEF10C1EF6BC23B2DA7D9150ACCEED5C18C036B4DD62D9BF0143E8A7。它只包含已合入的窗口终态和原历史修复，不称为有效HRV修复包，本轮未安装或发布该候选。
- Windows 无 Xcode，iOS Debug/Profile 未本机构建；厂商原始回包、有效HRV、全量实际设置保留、后台部署和商店发布分别未验收。私有证据、真实健康值、SDK反汇编正文、账号资料、构件和证书未入Git。

## 下一步需要核实的原厂契约

针对 R7 Ultra 实际869固件，需要确认：是否实现type60实时RRI/type61历史、type62启动的前置条件和结束状态；若只实现旧42/45，原始heartNum的物理含义、单位/倍率、是否含真实RR间期及HRV算法来源；SDK最新对应版本和正常原厂样本。没有明确真实数据契约前，不把原厂生成的展示字段引入Say Ring，不将该型号一概标为不支持。

最终回读：Say Ring仍为普通1242、原UID，LuckRing为默认可用且已停止。手机随后自动息屏锁定，UI为空时已查明是锁屏，不作为崩溃证据；回到Say Ring后的最终蓝牙恢复尚未确认。最后fetch自己远端仍34fb300；共享分支新增9e9d520仅为另一台手机手势记录，本轮未再合入，未声称整个共享分支已最新。

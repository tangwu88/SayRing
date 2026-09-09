# 国际版 Flutter 多语言实施记录

## 基线与修改范围

- 工作区 `F:/xcodeplace/saydian-app-global`；修改前已阅读 AGENTS、CHANGE-TEST-LOG、最新 Android 微信 code 登录记录、BUG-RETROSPECTIVE 与 REGRESSION-CHECKLIST，并执行 Git 状态/远端/fetch/提交号检查。根代理已安全合并 App 基线；本分工保留同任务服务/API/原生并行改动，统一由根代理提交。
- 本分工修改 `lib/l10n`、`l10n.yaml`、`lib/app.dart`、显式 UI 文案、品牌组件、语言组件测试和 `flutter.generate`。不改健康原始数据、设备能力、账号归属或API业务键。
- 原因：国际 App 默认英文，提供 en、zh-Hans、zh-Hant、de、fr、es、ja、ko 手动选择与独立持久化；8种语言均维护实际译文，使用 Flutter 官方 gen-l10n/ARB。
- `GlobalLocaleController.instance` 为国际生产 API 提供当前语言；真实 global App 首次明确 en，国内兼容 App 保持中文。独立旧页面宿主未安装国际 delegate 时保留原中文；国际 App 和国际测试始终安装 delegate，不用这个兼容回退证明英文验收。
- `GlobalLanguageButton` 供国际登录页使用，“我的”新增语言入口。保存失败保持当前语言并提示；持久化读写串行，旧异步读取不能覆盖新选择。界面切换不清除登录和健康数据。
- 登录锁图替换为现有真实红色品牌mark与普通文本 Saydian，未生成或近似重画图标。

## 命令与发现

1. 首次 `flutter pub get` 取得根代理已添加的 phone_numbers_parser/country_picker；自动生成失败：官方 gen-l10n 要求 `zh` base locale。新增 `app_zh.arb` 作为 Hans/Hant 的简体结构回退；App 支持列表仍严格8种，不将 base zh 当第9种语言。
2. `flutter gen-l10n` 复跑通过；无缺失翻译提示。`dart format` 仅格式化本轮文件。
3. 首次定向 `flutter analyze --no-pub lib/app.dart lib/l10n lib/ui/pages.dart lib/ui/brand_assets.dart lib/ui/global_auth_page.dart`：唯一失败为根代理新登录页的 `package:html/parser.dart` 尚未完成依赖解析；本分工文件当时未报错，后续统一 pub get 再验。
4. 为避免手工漏掉 const 祖先，使用 Flutter SDK 自带 analyzer 只读解析显式 UI 构造参数，按已翻译 ARB key 生成候选补丁，再通过 apply_patch 修改源码。没有重写/遮蔽 Text 组件，没有运行时按中文猜翻译，没有转换API键、设备名或用户输入。首次临时工具使用 App 包解析失败（App 未依赖 analyzer），改为 SDK 自带 flutter_tools package_config；不新增生产 analyzer 依赖。
5. 根代理全量分析发现 `build/l10n-tools/*.dart` 被静态分析器扫描、缺少 analyzer 包。已将只读临时工具移出仓库至 `F:/xcodeplace/saidian-global-l10n-tools`，仓库内 build 只保留不提交的 JSON 映射；未通过屏蔽业务源码绕过检查。
6. 多轮 UI 接线后的定向分析发现 `pages.dart` 两处健康状态分支及一处百科初始化缺少花括号，已逐处修正；未改变原健康阈值或算法。
7. 最后盘点资源键发现 `view` 被新增批次重复声明。保留原有正式值，移除重复条目；测试新增顶层 ARB key 唯一性断言，防止 JSON 解码静默覆盖。最终每种语言为 **375 个消息键**，并非先前口头累加估计的376。

## 当前已接入范围

- 375 条实际8语译文覆盖国际账号基础/错误/验证码、导航、首页 greeting/AI 快捷入口、健康指标与状态、设备连接与能力目录、通用操作、设置语言入口、资料字段、部分订单/设备/健康内页；运动名称使用枚举显式映射，进度/暂停/开始等使用 ICU 插值。
- 首页健康状态改为私有枚举，再映射本地化状态名；原有阈值分支保持不变。状态徽章增加 Flexible/maxLines，避免较长翻译挤出同行数据。
- 国际登录/重置密码路由使用根代理 GlobalAuthPage，原国内账号页仅保留旧回归兼容。资料账号字段读取真实 emailMasked/phoneMasked，不生成或猜测国际手机号。国际 CarePage/Invitations 交给根代理 GlobalCarePage，不发起旧版关爱请求。
- `AppUpdateService` 国际入口使用 GlobalAppUpdateService；更新界面支持实际 App Store/TestFlight/Android 目标，TestFlight 使用独立8语按钮，不将 TestFlight 当APK下载。
- 国际百科新增 `GlobalArticleLibraryPage`：分类/文章 ID 保持 String，完整传递 UUID；国际入口不走国内 int 解析；语言变化重载国际内容；请求代际校验防止晚到响应覆盖当前选择。详情读取 contentHtml，保留失败和重试状态。
- 百科和商品图片经 GlobalEnvironment.media 解析，相对路径进入国际前缀，国内源不再兜底。非法路径只返回空资源交由现有错误态处理，不重新请求国内源。
- 国际健康分析只接受服务端 availableVersion 与 document(path/locale/version) 一致的已审资料：先读取文档、校验版本/语言/非空正文、以纯文本展示并去除 script/style/noscript/template，用户单独勾选后才传显式版本。文档缺失/变化禁止新分析和购买，历史报告保留；授权撤回继续可用。此处不自动翻译法律正文，也不把客户端自写文案当作已审授权。

## 验证结果

命令从 `F:/xcodeplace/saydian-app-global` 执行，Flutter/Dart 均使用 `D:/Dev/Flutter/3.44.9/bin` 下版本。

| 命令 | 结果与边界 |
| --- | --- |
| `flutter.bat gen-l10n` | 通过；375消息键 × 8语言，另有官方必需 zh base fallback。每批修改后重新生成，最终无缺译提示。 |
| `dart.bat format lib/app.dart lib/l10n lib/ui/pages.dart lib/ui/prototype_pages.dart lib/ui/shop_pages.dart lib/ui/health_reports_page.dart lib/ui/health_trend_page.dart lib/ui/watch_face_market_page.dart test/global_l10n_test.dart test/global_localized_pages_test.dart` | 分批执行并通过，只处理本轮文件；未运行全库格式化。 |
| `flutter.bat analyze --no-pub lib/app.dart lib/l10n lib/ui test/global_l10n_test.dart test/global_localized_pages_test.dart` | 最后一轮 `No issues found`。 |
| `flutter.bat test --no-pub test/global_l10n_test.dart test/global_localized_pages_test.dart` | 最后一轮 **15/15通过**；没有网络、真实账号、实际付款或真实手表操作。 |

- `global_l10n_test.dart` 11项：8语键集合和顶层键唯一性、真实不同登录译文、首次英文不跟随德语系统、持久化还原、旧读取与新选择竞态、保存失败不假成功、连续切换序列、中文脚本别名、语言选择器切换，以及390×844的1.0/1.5/2.0字号可滚动无异常。
- `global_localized_pages_test.dart` 4项：UUID百科分类和详情从未调用国内 int API；缺审核文档禁授权/生成并保留旧报告；展示真实批准正文后发送显式版本且不显示脚本内容；返回不同文档版本时不授权。
- 最后一项测试故意模拟版本变化，预期调试日志为 `FormatException: Reviewed analysis document changed`；测试结果通过，此日志不是未处理崩溃，也未将该技术信息展示给用户。
- 全量回归、Android/iOS编译、截图和真机验证由根代理统一记录；本分工未验证真实设备、App Store/TestFlight、短信供应商、付款或生产联调。

## 明确未完成项（不能标记全量8语验收）

- **语言基础设施和已列出的375键完成，不代表全App全部业务文案已翻译。** 冻结时对6个UI源文件的 AST 盘点仍有149种/149处直接静态中文构造参数：pages.dart 46、prototype_pages.dart 84、shop_pages.dart 1、health_trend_page.dart 4、health_reports_page.dart 12、watch_face_market_page.dart 2。此盘点计入保留的国内登录/关爱分支，但仍包含国际可到达的设备设置、健康预警/校准/心电、安全说明、报告方案、订单表单和资料引导，需要继续逐页收口。
- 上述 AST 数量仅统计显式 UI 构造器的单字符串参数；**不包括**三元表达式、插值、回调提示、模型派生状态、服务/原生错误、服务器正文，不能据此计算“全部完成比例”。首轮278种/297处是当时较早批次的快照，后续以本节冻结盘点为准。
- 尚未完成所有业务页面在375/390px、8语言、1.0/1.5/2.0字号的截图/阅读顺序验收；已通过的大字号结果仅覆盖语言选择器，不能外推全App。
- 远端文章、商品、健康报告、协议必须由国际服务按当前语言返回；客户端不把中文正文复制或截断冒充译文。语言资源完整不等于服务器8语内容完备。
- 本轮未经母语人工校对，不声称所有专业健康/设备术语已经达到发行级语言质量。

## 后续同事继续步骤

1. 先阅读 CHANGE-TEST-LOG、本记录和 REGRESSION-CHECKLIST，检查 Git 状态并安全更新远端，保留并行未提交改动。
2. 按上节分组补 ARB 与显式调用；不要翻译API键、手表名称、用户输入或医疗算法数据，不得将中文复制为其他语言冒充完成。
3. 每批先 `gen-l10n` 再分析/测试；检查顶层键唯一性，不把生成前的缺 getter 报错当成后端缺接口。
4. 如接口不支持当前语言，明确显示不可用，禁止回退国内服务或自行制造已审健康/协议文档；保留真实历史记录。
5. 根代理负责统一提交；本分工没有单独commit、push、部署或生成对外下载包。

## 第二轮：国际实际可达静态文案补缺与 UI 回归（2026-09-09）

### 基线、范围与结果

- 根代理要求继续原149处清单中实际可达的国际界面，不追国内旧登录/旧关爱，不改算法、数值、用户输入或服务内容。已重读更新后的 AGENTS 和 INTERNATIONAL-HANDOFF，执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin`、`git rev-parse HEAD`。HEAD为 `06bf2a632c43db5ba80fab3e0288670459d8b1fe`；工作树有同任务并行修改，仅fetch，未pull、覆盖或提交。
- 新增 **124 个消息键，最终499键 × 8语**。分批按“写ARB → gen-l10n → 显式UI调用”顺序，避免其他测试在无getter的中间态编译。长提示保留完整内容，不截断安全建议；医疗/设备算法与阈值未修改。
- 覆盖健康安全、预警开关/上下限字段、校准指引、ECG免责声明与波形说明、表盘/照片表盘/传输、设备显示/辅助评估/SOS、运动退出确认、单位/目标/资料、订单/售后表单、报告方案及付款等待说明。地区示例按语言使用实际城市名称，不改变用户已选城市或天气数据。
- 原149处清单减少为29处：pages.dart 9、prototype_pages.dart 18、health_reports_page.dart 2，其余三个文件0。剩余清单项为国内旧登录/注册/找回、旧百科分类、旧关爱与国内分析授权说明；国际对应入口已经走独立页面/已审文档。
- **这29处只是原有AST扫描口径的剩余数，不是全源码剩余中文总数。** 此检查器不穷尽函数式/嵌套UI、默认参数、列表记录、三元表达式和插值；人工复查仍发现国际可见中文，见下节，不宣称全App或所有国际静态文案完成。

### 发现与修复

1. **国际安全中心仍进入国内找回页（P1）**：SecurityCenterPage原回调直接构造PasswordRecoveryPage。按根代理授权仅将国际分支改为GlobalAuthPage(resetPassword:true)，国内流程保留。国际提示包含邮箱或手机号；新测试验证没有旧页面。
2. **国际客服展示国内联系方式（P1）**：原页固定国内400电话与微信号，无已验证国际support契约。国际入口改为普通语言的暂不可用与隐私提醒，不展示国内电话/微信，不编造国际联系人；国内页保留。新增测试验证国际页面没有旧号码/账号/微信按钮。
3. **6项旧ui_shell测试日期数据未初始化**：Dashboard改为按当前语言格式化日期后，独立旧中文宿主没有初始化intl日期符号。测试fixture增加`initializeDateFormatting('zh_Hans')`，没有改生产默认语言或放宽布局断言。原375px/P40/2倍字测试恢复通过。
4. **可选更新弹窗真实启动竞态（P1）**：首次语言delegate未完成Navigator挂载时，快速manifest返回，`_showOptionalUpdate`遇到null context直接返回，丢掉可选更新。现等待endOfFrame后再取context，并重新检查mounted、根强更gate完成状态及当前无强更。未改变强更判定/持久化/深链拦截逻辑。新增德语启动立即返回manifest测试，原解除强更测试改为验证真实本地化弹窗、更新操作与release notes，不依赖已替换的中文固定标题。
5. **ARB动作键与询问键冲突**：新“使用”误用原“使用这个表盘？”键useWatchFace，唯一性测试正确失败。将动作改为独立useSelectedWatchFace，保留原确认问句；重新gen并通过键唯一性/语种集合测试。
6. **新大字号测试的滚动夹具错误**：首版16项新测试未区分页面Scroll与输入框Scroll，且在scroll后的新布局提交前点击，产生Too many elements/离屏点按；第二版仍有4个西文2倍字离屏。修正为指定页面滚动容器、滚至真实Switch、pumpAndSettle后点击，并额外断言hitTestable。未隐藏控件、缩小字号、忽略异常或移除布局断言。最终8语×1/2倍字全部通过。
7. 初次局部apply_patch因格式化后的行形状或补丁hunk先后顺序不匹配被拒绝；按当前源码精确位置重新生成补丁，无强制替换、无用户代码丢失。

### 本轮命令与验收

| 命令 | 真实结果 |
| --- | --- |
| `flutter.bat gen-l10n` | 每个ARB批次后执行；最终499键，8语无缺译警告；最后简中找回说明修正为邮箱或手机号后再生成一次。 |
| `dart.bat format lib/app.dart lib/ui/pages.dart lib/ui/prototype_pages.dart lib/ui/shop_pages.dart lib/ui/health_reports_page.dart lib/ui/health_trend_page.dart lib/ui/watch_face_market_page.dart test/ui_shell_test.dart test/app_update_gate_test.dart test/global_localized_pages_test.dart` | 分批通过；不涉及根代理API/服务文件。 |
| `flutter.bat analyze --no-pub lib/app.dart lib/l10n lib/ui test/ui_shell_test.dart test/app_update_gate_test.dart test/global_l10n_test.dart test/global_localized_pages_test.dart` | 最后一轮No issues found。期间根代理指出app.dart等待frame后if缺花括号，已修正。 |
| `flutter.bat test --no-pub test/ui_shell_test.dart test/app_update_gate_test.dart test/global_l10n_test.dart test/global_localized_pages_test.dart` | 最后一轮 **86/86通过**，包括原7个UI失败、保留的严格强更gate/布局测试及新增国际路径/语言测试。 |
| `flutter.bat test --no-pub test/global_l10n_test.dart` | 最后简中资源修正后单独复跑 **11/11通过**。 |
| `git diff --check -- lib/app.dart lib/l10n lib/ui test/global_l10n_test.dart test/global_localized_pages_test.dart test/ui_shell_test.dart test/app_update_gate_test.dart` | 通过，仅Git的LF→CRLF提示；没有空白错误。 |

新增18项localised page测试：国际客服边界、国际安全重置路由，以及健康预警页8语×1.0/2.0字体缩放、375×812滚动与开关命中、120默认阈值保留、安全长文案存在；另新增1项德语快速可选更新启动竞态测试。既有15项本分工测试继续通过。本轮未执行真实手机/手表、真实付款/验证码、母语校对或截图验收。

### 国际界面仍可见的未覆盖文本（下一轮优先）

- **健康预警动态提示**：空态“暂无健康预警”、保存失败回调、预警级别映射及“来源”拼接；服务端已提供标题/正文必须按返回语言展示，不翻译用户原始内容。
- **设备设置动态内容**：正在读取/传输的功能名与百分比、查找手表状态、相机错误/状态、消息权限、天气反馈、闹钟/联系人/世界时钟空态、日期/重复周期选项、屏幕亮度和灵敏度插值、固件能力防御提示。这些不在原149条直接参数清单中，仍需逐页显式ARB接线。
- **健康详情与报告**：列表/record里的ECG子指标名称、来源标签、校准保存状态、风险/疲劳解释及报告图片动态文字；报告概览标题/有效天数/次数/会员期限/生成动作/支付状态、缺失数据与安全默认文案。包括少量原扫描器遗漏的静态构造内容，不能只依赖该工具验收。
- **运动、个人与商城**：轨迹/定位状态、结束回调、时长单位与摘要、资料/退出等动态操作提示、订单状态与金额拼接、地址/商品缺省说明。国际商城接口/价格/支付的可用性由根代理服务契约控制，本轮翻译不构成交易能力完成。
- **共享服务层**：AppController、原生桥接和模型派生中文，以及服务端文章、AI历史、商品、报告/PDF、已审协议的实际多语言内容，均不属于本轮静态替换的完成范围。

本分工已再次冻结；由根代理统一全量回归、构建、交付与Git提交，以上失败历史保留供后续复盘。

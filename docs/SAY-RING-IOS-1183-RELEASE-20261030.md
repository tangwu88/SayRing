# iOS 1.0.7（1183）发行续办

用户已收到1182的真实验证结果，包括R21原首次初始化缺确认/重连未恢复、R12新扫描没有可用候选、R7 Ultra握手未完成、iPhone离线及Mac再次锁屏，随后明确要求“先构建新版本 上传和提交审核”。本轮据此先构建1183并推进苹果发行；不把既有未通过项记成通过，不再将1182真机门禁当作用户新指示之前的暂停条件。原手机/戒指数据、初始化保护、地区、现行协议和权限边界均保留。

## 基线和计划

独立Say Ring开发分支，status/remote/fetch成功，干净HEAD与origin均0a3292d88a9f1496818a08dfc73d39ca42e66faa。已读AGENTS、handoff、1182及最近Windows记录、复盘和回归清单。相对已全绿CI的680ae3b，运行源码没有变化；本轮仅发行构建号从1182改为1183，不修改SDK、连接算法、数据/权限规则或健康提醒功能。

公开苹果页实际核实Say Ring/AppID6816549943，TestFlight最高仍1175，1174缺合规证明。先保留旧提交，待正确1183处理可选后再替换。Mac目前解锁，启动仅在当前任务期间的临时唤醒保持，结束时撤销，不修改安全锁屏设置。Xcode原1182分发准备已取消，避免误传旧归档。

使用正常lib/main.dart和现有生产第一方配置重编；Bundle必须cn.saydian.ring、Team W7SXQ4A226、无QA定义。本机既有工具链部署目标覆盖15单独记录，仓库默认兼容目标的Debug/Profile/Release及RunnerTests编译已在源680ae3b的CI41033828840通过。既有双时区各1670项Flutter、Node142/1条件跳过、Harmony双时区各540及Python35等证据保留原执行来源，不因文档/构建号重复测试而冒称重跑。

新归档与签名、实际IPA/上传结果、TestFlight处理/合规/群组及App Store构建替换/资料保存/正式提交依次追加。审核说明须明确HRV为同设备个人恢复参考、皮温不是核心体温、仅新的有效完成测量可比较，预览不生成真实事件；1183当前未获新的iPhone实测，前轮通过与本轮失败分别披露。构建成功、上传、提交和苹果批准/上架是不同结果。

## 1183归档完成

固定源23e4dbc5f64e022ec2660e54e541bf1bbcb194cc，逐项核对782个运行输入与1182相同，工作树干净；iOS构建独占，无其他iOS编译。新执行`flutter build ios --release --config-only --no-codesign --no-pub --target=lib/main.dart --build-name=1.0.7 --build-number=1183`及现有第一方/商城配置，30.3秒通过。随后独立`xcodebuild ... -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/ios-1183-release-20261030/SayRing-1.0.7-1183.xcarchive ... archive`33.4秒成功，没有改名旧包。配置阶段现有SPM/部分SDK模拟器arm64提示保留，不把真实设备归档混称模拟器验收。

实际新归档核实cn.saydian.ring、1.0.7（1183）、显示名Say Ring、W7SXQ4A226及正常main/无QA定义，`codesign --verify --deep --strict`通过。Release App.framework SHA256 fa1be4f09a1fced5e0822ad8032fd986b5febc05a72b17cfe2e1abd9f818c2a8；提示音资产SHA256仍a6afc964076ca00309ed3e780a983a479a7f1d1c3776d69639f569f5623b2c78，无Critical Alerts entitlement。当前为开发签名的正确Release归档，仍需正式分发重签，不冒充已导出的App Store IPA。

Xcode打开新归档后，只读取右侧所选归档详情表，确认1183/cn.saydian.ring/W7，避免仅在所有历史行中找到1183却上传另一个选择。选择Distribute App→Custom→App Store Connect→Upload，未使用TestFlight Internal Only。原生“Next”实际阻断：Uploading failed to use accounts，要求原Xuewu Tang账户的App Store Connect访问权限。Manage Accounts打开的Xcode Apple Accounts实际列表为空；已点击Sign In并把原生账号登录窗口置前，要求用户在窗口完成原账户和验证码。不读密码/验证码，不查找或新建API凭据、不导出密钥、不更改账号权限或协议。原生信息比此前命令行No Accounts更具体；未将网页已登录当作Xcode已认证。

原生UI探查一次使用错误层级table1导致索引错误；按实际右侧scroll area内嵌层级读取后正确。另一次读取checkbox的AppleScript拼写错误仅影响查询，更正为实际顶层控件后继续。所有动作均依据新鲜UI状态或本窗口截图，未盲点上传。截图和原始构建/账号UI证据仅留ignored私有目录。

## 审核资料就绪、待原生认证

浏览器独立核实Say Ring1.0.7仍等待审核且挂1175；原有账户、联系人、自动发布/立即更新、地区及评分保留。只备份现有公开文案和审核备注，不读取登录密码。新描述、推广文本、关键词、新增内容与3483字符真实审核说明已在本机准备，TestFlight测试说明也就绪；披露1183未做新iPhone验收、旧R21初始化/重连和R7历史限制，预览不等于真实测量或医学验证。新文案未保存到旧1175提交，避免让其对应不包含的新功能。

原1175记录已核对加密问卷依据：SQLCipher/Flutter内置标准加密同时使用系统加密，唯一法国未供应；本轮尚未出现1183的实际合规表，不猜批准代码或改变地域/加密声明。待1183真正处理可选后再按实际表单核实并替换1175。不撤回旧提交来掩盖未上传新包，不把“归档成功”标为TestFlight或审核提交成功。

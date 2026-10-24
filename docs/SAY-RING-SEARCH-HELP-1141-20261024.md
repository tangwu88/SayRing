# 2026-10-24 添加设备搜索帮助 1141

## 基线、需求与范围

用户提供参考截图，要求优化“添加设备→搜索”的找不到设备提示。P2体验缺口：已有部分搜索结果时缺少通用排查帮助；单纯照搬截图的忽略设备操作，容易让首次添加或仍绑定的用户误操作。

开始时工作树干净，HEAD ca07106fb546c8f28ca4e7eded419eaf3fe66707；git status/remote、fetch origin --prune及pull --ff-only成功（Already up to date）。已复核AGENTS、国际交接、回归清单、复盘及1140实际验证记录。新分支codex/device-search-help-1141-20261024，保持Public，只推本仓库开发分支，不推广未完成原戒指完整验收的main。

## 实现

- lib/ui/pages/devices.dart：搜索页底部常驻“找不到戒指，怎么办？”入口，不依赖是否有搜索结果、商城是否开放；扫描中同样可用，正在连接/查找可恢复设备时保持busy门禁。用户主动点击后出现随系统字号缩放、可滚动的图标分步对话框，底部确定按钮独立可达。
- 说明包括充电唤醒和靠近、蓝牙/附近设备权限（系统需要定位时再按提示）、其他手机或戒指App占用，以及已有绑定先尝试重连。只有已解绑、需要重新添加且仍搜不到时，才说明iPhone“忽略此设备”或安卓“取消配对”；首次添加直接在App搜索。不自动弹窗、不打开系统设置、不解绑、不取消配对、不重置设备、不自动选取搜索结果。
- 9份ARB及生成资源补齐中/繁/英/德/法/西/日/韩说明；更新原搜索空态过宽的“先断开本机系统蓝牙”文案，改为权限/唤醒与其他手机或App占用提示。iPhone和安卓系统操作分别展示，前端新增文字不含供应商名称。保留商城入口、原搜索/权限恢复流程、历史和热量1140修复。
- test/device_scan_prerequisites_test.dart：332dp/200%大字、iOS/Android、有/无结果、关闭帮助保留结果且不重扫、不打开设置、不连接任何设备；扫描结果在帮助打开期间返回，关闭后仍可选。均为合成样本。
- integration_test/ios_device_search_help_test.dart：真实App打开搜索与帮助、核对iOS说明、关闭返回、原owner和记忆目标不变；同二进制串接1140真实历史热量/睡眠导航回归，不包含原戒指未具备现场条件的完整同步用例。

## 过程与失败保留

1. 最初测试补丁误将import置于文件末尾，dart format及测试编译失败；移到文件顶部后重试，不改业务逻辑掩盖编译问题。
2. 第二轮15项通过、4项失败：手动debugDefaultTargetPlatformOverride直到addTearDown才恢复，触发Flutter测试框架基础变量不变式。改用官方TargetPlatformVariant管理每个测试平台；第三轮19/19通过。断言包括真实UI交互和可访问性，不将此失败误说成SDK连接故障。
3. 第一轮完整检查格式通过，analyze发现2项info并退出1：多余foundation import和if缺大括号。移除多余import、补大括号后重新执行全套检查；失败日志保留在Git外，不覆盖。复制私有测试脚本时格式参数曾重复指向同一文件，已整理去重，不影响已检查文件的结果。
4. 已私有备份XR本App数据容器。全量、构建、验签、实物和普通版恢复结果待完成后续记；未把宿主页面测试写成原戒指实际连接或同步通过。

## 发布边界

本轮为已授权的搜索帮助优化；账号/设备绑定、首次初始化策略、历史数据、SDK路由及能力门禁均不修改。原R7 Pro/HR05完整连接、活动增长和有效睡眠同步验收仍待用户回到手机旁；此前先实物通过再上传TestFlight及送审的条件保持。未操作App Store Connect、审核构建、协议或销售地区。

## 本轮宿主检查完成

所有源码/翻译/测试修改在原生编译前完成，flutter gen-l10n成功。修正后私有run-host.py完整执行：pub get --offline --enforce-lockfile成功0.5秒；格式门禁1.0秒；analyze零问题12.0秒；UTC全量1470/1470（34.0秒）、Asia/Shanghai全量1470/1470（38.7秒）。Node工具139项中138通过、1项Windows专属跳过，Harmony两时区各518/518，Python发布工具35/35；这些是合成/宿主边界，不是生产发布或真实戒指接受测试。

Android Debug成功11.3秒，显式SAIDIAN_ALLOW_QA_RELEASE=true内部QA Release成功46.9秒；不交付/发布QA包。原生单测成功，读取本轮14份JUnit XML共60项，0失败/错误/跳过。没有改动原签名、生产推送或服务器配置。已知微信SDK iOS 26+ Apple Silicon模拟器arm64提示保留，本轮使用真实iPhone而非声称该模拟器已可用。

## iOS构建、真机与恢复回执

串行配置/开发签名xcodebuild全部成功：Debug配置33.3秒、编译12.0秒；普通Profile配置24.9秒、编译30.4秒；测试Profile配置20.1秒、编译23.6秒。显式1.0.6(1141)、cn.saydian.ring、团队W7SXQ4A226；普通入口lib/main.dart，测试入口ios_device_search_help_test.dart，复用现有DerivedData且无并发iOS编译或源代码修改。

两份Profile均strict/deep codesign验证通过，embedded profile包括XR、get-task-allow与完整application-identifier正确，geolocator未含requestAlwaysAuthorization。App.framework SHA256：普通9f4a2cec6832c4545814d921ea9798f1d5dfd799c94f0a44990afefa718466cc；测试2f0d0d13afdee646e5f89729e13a24b56c5ee292bd3a2d33d1c5b5b6cae99da5。

经保数据wrapper、明确已验签Profile、keep-app-running驱动XR：driver40.6秒exit 0，两项实物测试通过。帮助打开/关闭、iOS专用说明、返回仍为搜索页、原owner/记忆目标不变均true；实际截图人工核对标题、四个图标步骤、条件性忽略说明和确定按钮正常，无新增供应商品牌。搜索过程仍能显示结果，没有点击结果或执行重新绑定。

同一1141测试二进制串接真实历史回归：138条旧热量均pending=true，原payload读回一致；真实日期趋势不再误画千卡，睡眠最近/按日期切换通过。原绑定目标仍未连接、没有其最新睡眠样本，不能称新睡眠/完整同步通过。延用1140测试中的截图标签，不将标签号当成本次安装版本；本次版本由签名包及设备清单独立核对。

测试后私有备份0.8秒、原位恢复普通Profile 5.4秒、启动0.3秒，均exit 0。随后仅对本App冷启动，4秒后截图人工核对首页正常；设备清单读回cn.saydian.ring / 1.0.6(1141)。未卸载、清数据、解绑或恢复出厂。9份ARB新增6条帮助完整、无供应商品牌文字检查通过，git diff --check通过。

截图、日志、容器、元数据和App仅保存在Git忽略的build/ios-1141-20261024私有目录，不上传Git。本轮仅开发分支同步；不替换审核构建、不上传TestFlight，保持用户要求的完整原戒指验收条件。

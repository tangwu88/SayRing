# Say Ring 商店展示与搜索资料补充

## 授权及当前版本

2026-10-20用户圈选App Store Connect“标题和搜索结果”空素材位，要求补充信息以帮助用户了解、搜索Say Ring。实读当前App为6816549943、`cn.saydian.ring`、iOS1.0.4（1120）“可分发”；仅修改Say Ring简体中文推广文本并新建一份独立创意素材审核。没有换二进制、撤回旧审核、改变购买/健康开关、销售地区、价格或其他App。

现有名称`Say Ring`，副标题`智能戒指活动与睡眠记录`。名称、副标题及版本页关键词均disabled；App信息页面明确要求新版本才能修改名称。原关键词`赛电,智能戒指,睡眠,步数,活动,运动,蓝牙,`保留。不为本次素材创建空新版本或把未发布的阅读/购买功能宣传成现网功能。

## 已保存的推广文本

原文为“智能戒指、震动戒指、闹钟戒指、睡眠戒指，赛电，让健康生活更轻松”。替换为以下101字符（剩余69），在编辑弹窗保存并从版本页逐字读回一致：

Say Ring 赛电智能戒指伴侣，连接兼容戒指，按日期查看步数、活动与睡眠记录，了解每天的变化。支持查看设备电量与信息，部分机型可使用手势控制和遥控拍照。无需登录也可连接戒指；功能以设备实际能力为准。

[保存文本](APP-STORE-PROMOTIONAL-TEXT-20261020.txt)。推广文本用于说明功能，按[Apple搜索说明](https://developer.apple.com/app-store/search/)不影响搜索排名，不能把堆砌词语当成关键词索引。另存[下一版搜索词草稿](APP-STORE-KEYWORDS-NEXT-DRAFT-20261020.txt)，尚未写入ASC，不声称已生效。

## 创意素材

- 原素材库有7个历史App截图；浏览已批准的标题候选为0个，没有修改或删除旧截图和历史审核。
- 使用内置image_gen（非CLI）生成新的品牌图，文案为`Say Ring`、`赛电智能戒指`、`记录活动，了解睡眠`，以日夜/通用戒指意象表达活动和睡眠，不含医疗、精度、AI、支付、奖项、价格或其他平台承诺，也不伪造App界面和健康数值。
- 图像原始返回1672×941无alphaPNG；仅以macOS sips机械重采样为Apple要求的5244×2950无alphaPNG，不改变文案/图形，不把上采样宣称为原生5K生成。
- 最终文件保存在忽略目录`build/appstore-assets-20261020/say-ring-activity-sleep-zh-Hans-universal.png`，9,288,733bytes，SHA-256`f32607150879846476a30ae0d682400e5cf9c6f84a17f6793d8e4c8d9f425f88`。原生成图和提示词保留本机；交付前已查看最终图及苹果页面预览，文字可读。不是具体戒指型号/临床性能证明。
- Apple上传处理成功，UI读回5244×2950，“通用素材”，适用于“搜索结果”和“产品页面顶部区域”。素材ID`ffc00019-64c4-8c37-8014-53aa7b995c1c`，名称`Say Ring｜活动与睡眠｜简体中文｜2026-10`。
- 先保存素材名称，再“添加以供审核”，草稿仅包含本次1个图像素材、与最新iOS版一起评审；点击最终“提交以供审核”后，页面确认“已提交1个项目”。独立审核ID`ac19ce26-f4e6-45e3-8c58-6ac6e1e3f906`，提交北京时间2026-10-20上午9:02。
- [审核详情](https://appstoreconnect.apple.com/apps/6816549943/distribution/reviewsubmissions/details/ac19ce26-f4e6-45e3-8c58-6ac6e1e3f906)实际读回整体和单项目均“等待审核”。**不是已获批或已发布**。获批后仍需在版本页“浏览素材”分别选择标题/搜索结果、检查裁剪预览并Publish；当前该位置只接受已批准素材，不能提前关联。

依据：[Apple素材管理](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets)、[规格](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)、[独立素材审核](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-assets-from-asset-library)、[最佳实践](https://developer.apple.com/app-store/asset-best-practices/)。这种创意素材面向iOS/iPadOS27+；旧系统继续用既有截图，不承诺搜索名次或索引效果。

## 实际失败与边界

浏览器初次Playwright导航未改变URL，读取新状态后用可见AX链接打开；没有盲目坐标重试。一次上传入口探路时尝试空文件列表关闭chooser，运行时明确要求至少一个文件，未写文件或上传内容；之后重新进入可见入口、监听filechooser，仅选最终图一次，上传成功。没有读取浏览器cookie、用隐藏页面API或导出审核凭据。

本轮为内容/素材更新，无运行源码变更，不重复全量编译。此前适老阅读运行源码已发布Git提交`503ea25`，完整回归与双端编译见[阅读记录](SAY-RING-ARTICLE-READER-20261020.md)。该新阅读界面尚未上传AppStore，未出现在本次宣传图。

页面证据仅存本机忽略目录`../SayRing/build/mall-download-20261020/`：`appstore-promo-updated.png`、`appstore-creative-prepared.png`、`appstore-creative-review-submitted.png`，已实际查看截图。既有下载页仍是核验过的正式1016标签纠正状态；新1121Android仅QA验证，缺原签名/生产推送材料，原生收款缺App微信/支付宝配置，均不伪报上线。

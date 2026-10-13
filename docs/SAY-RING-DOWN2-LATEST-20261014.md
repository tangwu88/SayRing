# Say Ring 下载页更新与 1064 公开测试审核

## 范围与基线

- 用户要求同步 https://app.saydian.cn/down2 下载地址到最新版本，并完成后台登录。确认新构建仍等待苹果审核后，用户明确选择“先指向已上架 App Store 1.0（1062）”；Android 保留已核验的正式 1016。
- 修改前工作树干净；`git fetch --prune origin`、`git pull --ff-only origin main` 确认已最新。客户端基线 `080eb4d9ef560790e768d627b2d102bf9ada7981`，树 `1d8bab703d36c38be30463b7363514a6c8aa5742`，main 与既有 1064 审核分支均一致。
- 服务端仓库只读查看下载清单、产品分流和后台表单实现，保留其已有未跟踪同事记录。没有修改或部署服务端代码；通过现有后台“客服与更新 → Say Ring App 更新”保存生产配置 `say_ring_app_update`。
- 本轮只修改下载发布元数据、公开测试分发元数据及本仓库交接记录。App 源码、版本构建、签名和活动/睡眠范围均未变化。

## 可安装版本核验

- 更新前 Say Ring 公共清单：Android `1.0.0 (1016)` / available / direct；iPhone `0.1.2 (1059)` / available / 旧 TestFlight 链接 `https://testflight.apple.com/join/6GDgq9CS`；HarmonyOS `0.1.2 (1)` / coming_soon。旧发布时间 `2026-10-05T02:06:06.355Z`。
- 实时 App Store Connect 已发布版本页面确认 iOS `1.0` 可分发，关联构建 `1062`；新 `1.0.1 (1064)` 的 App Store 送审状态仍为“正在等待审核”。此前已实际上传、完成合规及于 2026-10-13 22:08 送审，详见 [1064 发布记录](SAY-RING-IOS-WELLNESS-MERGE-1064-20261013.md)。
- 苹果公开目录 `https://itunes.apple.com/lookup?id=6816549943&country=cn` 返回 Say Ring / `cn.saydian.ring` / version `1.0`，当前版本发布时间 `2026-10-12T17:59:34Z`，官方地址 `https://apps.apple.com/cn/app/say-ring/id6816549943?uo=4`。保存前后均核对真实目录；没有把等待审核的 1064 标为当前可安装版本。

## Android 正式包检查

- 保留生产清单中正式 1016 安装包：`/global/api/saydian-app/v2/support/app-package/say-ring-android-1791526039480-75639bff.apk`，69,323,534 字节，SHA-256 `f67194877b1d3b186f5bdedd9f96a7db4f88f8a46e2d1686c5b8375f43425b2e`。
- 公开 URL 完整下载成功，HTTP 200、APK MIME、文件长度、ETag 和附件文件名一致。不是仅检查 HEAD 或部分字节。下载副本保存于忽略目录 `build/down2-update-20261014/current-android-1016.apk`，完整大小和 SHA-256 与清单一致。
- Android SDK 36.0.0 `apksigner verify --verbose --print-certs` 通过；正式 RSA 4096 证书摘要 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。`aapt2 dump badging` 确认 `cn.saydian.ring` / `1.0.0` / `1016` / minSDK 26 / targetSDK 36 / 两种 ARM ABI。
- 本机没有 `android/key.properties`；现有本机 QA Release 构建为 1006 且使用调试签名，不能替换正式 1016。未上传 QA 包、降低版本或创建新密钥。正式 1016 的历史构建来源见 [2026-10-08 记录](SAY-RING-HOME-HEALTH-CARDS-20261008.md)。

## 1064 公开 TestFlight 审核

- 在既有公开外部组 `SayRing public`（`92b43a70-f0cb-4732-b998-282f7776c98a`）添加正确的 `1.0.1 (1064)`；构建 ID `1324af6b-1b73-480b-ae98-fae5cd2cf0ca` 与实际上传包一致。1063 未选择。
- 填写中英文测试说明，覆盖活动、睡眠、绑定和重连，以及 R8/R21/R22 → QRing、R7/K80/HR01/HR05 → LuckRing 路由；能力仍须真实握手，未知值不伪造，不开放生理测量、医疗风险、评分或 AI 分析。未声称本轮已完成戒指或手机实物验收。
- 关闭自动通知测试员选项，点击最终“提交以供审核”。服务器返回既有组 0 位测试员、2 个构建：1064“正在等待审核”、1059“正在测试”。这是实际公开测试送审；尚未获准外部分发。
- 既有公开组链接 `https://testflight.apple.com/join/k9Uye5C6` 保持启用。没有删除 1059、新建组或发送测试邀请；下载页当前使用已上架 App Store，避免入口仍安装旧 TestFlight 构建。

## 后台保存及公开回读

- 在后台登录确认后，只编辑 `say_ring_app_update`。iPhone 设置为 `1.0 (1062)` / available / app_store / 上述官方苹果地址。点击“设为现在”，再点击“保存”。
- 新发布时间 `2026-10-13T16:59:10.595Z`，即北京时间 **2026-10-14 00:59:10.595**。
- 公开 GET `https://app.saydian.cn/global/api/saydian-app/v2/support/app-update?product=say-ring` 返回 HTTP 200；断言版本、构建号、available 状态、`app_store` 类型、官方 URL 和发布时间均通过。Android 和 HarmonyOS 完整 release 对象与保存前完全一致。
- 同时对比 `?product=saydian-global` 与不带 product 的旧 App 下载清单：完整 `data` 均保持一致，HTTP 200。比对排除请求包装字段；没有修改其他产品的下载资料。
- `/down2` 重新加载显示发布于 `2026/10/14 00:59`、Android `1.0.0（1016）` / `69.3 MB`、iPhone `1.0（1062）` / “前往安装” / “通过 App Store 安装”。实际 iPhone 链接与已核验苹果官方地址一致；Android 链接与完整验证包一致。页面截图分别核对 Android 和 iPhone 卡片。
- 保留页面现有内部测试说明、隐私政策、用户协议及客服链接。下载页标识未做本任务范围之外的设计或文案改动。

## 失败、修正与证据

- 后台初次导航停在登录页，用户完成原生浏览器登录后继续保存；没有读取、请求或记录密码、验证码、浏览器凭据。
- 公共旧产品清单最初误用 `product=saidian`，HTTP 404。根据服务端真实产品分流改为不带 product 的既有公开接口，保存前后对比成功；未改后端来迁就错误参数。
- 源码首次搜索误用旧目录名；改用实际 `apps/admin-web` / `apps/download-web` 目录。一次 zsh 未匹配 glob 改为 `rg` 文件路径搜索，不改变仓库内容。
- 后台下拉选项没有出现在 AX 文本树中；按当前截图中的真实 App Store 选项点击，重新读取表单确认类型，再保存。整数 AX Value 存在浮点舍入，Android 字节数 Details 和公共清单均为 69323534，未将舍入值重新写入。
- JSON 前后快照、完整 APK、AX 页面证据、App Store 目录回读及截图均在忽略目录 `build/down2-update-20261014/`；没有二进制或个人账号、健康数据进入 Git。
- 本轮未修改 App 代码，没有重新构建、重签或重复执行完整 App 测试；基线已完成的分析、双时区各 1245 Flutter 测试和各平台构建见 1064 记录。本轮实际验证为下载接口、完整包签名与版本、公开页面和其他产品配置回归，以及文档 diff 检查。
- 1064 苹果 App Store 与外部 TestFlight 审核仍待批准。当前用户暂时无法连接 iPhone，未安装或恢复真机调试；下载检查不等于手机/戒指功能验收。

## Git 交付

- 本次仅提交本记录和修改/测试索引，保留原有源码与所有同事工作。使用 GitHub Git Data API 发布与本地已验证内容完全一致的树；更新 main 与既有 1064 审核分支时使用预期 HEAD 校验，不强推。
- 最终同步结果以远端 ref、fetch 后树 SHA、工作树状态及本次 Git 回执为准。站点配置已通过生产后台实际保存，不依赖文档提交触发部署。

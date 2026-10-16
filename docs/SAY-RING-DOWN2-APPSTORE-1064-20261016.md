# Say Ring 下载页同步已上架 iOS 1.0.1

## 范围与基线

- 用户要求更新 https://app.saydian.cn/down2。本轮确认后，用户选择“先更新 iPhone，Android 稍后”，并完成后台登录。
- 修改前工作树干净；fetch 和 `git pull --ff-only origin main` 从 `6c18ff5` 快进至 `54eff170e8c43975ca284c36d545261680f44eeb`，树 `2b7157e7ff91e81b12381fa2f9e74c40b64ed32c`。阅读交接、复盘、回归及最新正式包/下载发布记录。
- 本轮通过已登录管理后台保存 Say Ring 下载元数据，只提交本记录及索引；未改 App 或服务端源码，未部署、重构建、安装手机或操作戒指。

## 已上架版本依据

- 苹果公开目录 `https://itunes.apple.com/lookup?id=6816549943&country=cn` 在保存前后均返回 HTTP 200：Say Ring / `cn.saydian.ring` / version `1.0.1`，官方地址 `https://apps.apple.com/cn/app/say-ring/id6816549943?uo=4`。
- 苹果目录的当前版本发布时间为 `2026-10-14T16:50:50Z`，北京时间 **2026-10-15 00:50:50**。此前记录的等待审核状态是历史状态，当前 1.0.1 已在公开商店目录发布。
- 下载清单构建号使用此前实际上传并选中送审的 **1064**；构建 ID `1324af6b-1b73-480b-ae98-fae5cd2cf0ca`、送审 ID `1dec14c5-2df3-48ca-8f9d-dad0345575b8`，见 [1064 发布记录](SAY-RING-IOS-WELLNESS-MERGE-1064-20261013.md)。公开苹果目录只提供版本名；本轮 App Store Connect 会话过期，没有重新读取其私有构建详情，也没有变更苹果发布设置或重新提交。
- 公开 TestFlight 页面导航超时，未读取到当前状态；没有据此声称外部测试获批。下载入口沿用已核验的 App Store 官方地址。

## 后台保存

- 后台会话已过期。用户完成登录后，在新建的已登录后台标签页继续；没有读取、复制或记录密码、验证码、浏览器会话或签名材料。
- 打开“客服与更新 → Say Ring App 更新”，确认设置 key `say_ring_app_update`、公开开关开启、原 iPhone 为 `1.0 (1062)` / available / app_store。
- 仅将 iPhone 版本改为 `1.0.1`、构建改为 `1064`，保持 available / app_store / 官方 URL。点击“设为现在”及最终“保存”，后台返回“已保存”。
- 新清单发布时间 **`2026-10-16T03:12:53.915Z`**（北京时间 11:12:53.915）；后台行更新时间 `2026-10-16T03:12:58.472Z`。

## 公开核验

- 公共 GET `https://app.saydian.cn/global/api/saydian-app/v2/support/app-update?product=say-ring` 返回 HTTP 200。Python 将保存前完整清单复制后只替换 iPhone 版本/构建和发布时间，与保存后完整 `data` 相等；没有额外字段变化。
- iPhone 回读 `cn.saydian.ring` / `1.0.1 (1064)` / available / app_store / 上述苹果地址。Android 完整 release、HarmonyOS 完整 release、schemaVersion、audience 和 realm 均保持原值。
- Health 的 `?product=saydian-global` 与不带 product 的旧 App 清单分别保存前后回读 HTTP 200，完整 `data` 均相等；未修改其他产品。
- `/down2` 重新加载显示“发布于 2026/10/16 11:12”、iPhone `1.0.1（1064）`、“可下载”、“前往安装”、“通过 App Store 安装”；按钮实际 URL 与苹果目录的官方地址一致。截图已检查版本卡片及页面上下文。
- Android 仍为 `1.0.0 (1016)` / 69,323,534 字节 / SHA-256 `f67194877b1d3b186f5bdedd9f96a7db4f88f8a46e2d1686c5b8375f43425b2e`。本轮保留 URL 的 HEAD 可用性/长度检查与先前完整包验证分开记录，不重复声称本轮重新完整下载验签。

## Android 1066 延后

- 最新 Git 的 [正式包记录](SAY-RING-FORMAL-PACKAGES-20261015.md) 记载 Windows 产物 `E:\SayRing-market-artifacts-20261015\formal-1066\SayRing-1.0.0-1066-release.apk`，69,816,719 字节，SHA-256 `BAE37667D09ADA688B88F6F89D2264D127FD7B854E5B9A29BA72F8B63BFF0A70`。
- 本机 workspace/Downloads 未找到该文件；现有挂载 Windows 磁盘是只读本地卷，未获得对应新产物路径。一次范围过宽的文件名搜索没有定位产物，主动中止；没有读取无关个人文件、重新打包或使用其他签名替代。
- 用户明确选择先更新 iPhone、Android 稍后，所以保持已发布 1016，不把不存在的 1066 URL 写入生产清单，也不发布鸿蒙待开放包。待获得可读取的正式包后再独立核验并发布。

## 检查与交付边界

- 原浏览器插件缓存路径已更新，旧路径不存在；发现当前已安装运行组件后恢复浏览器连接。管理后台第一次原标签页登录返回 `Please sign in again.`；发现用户实际已登录的新标签页后继续，未反复索要凭据或绕过鉴权。
- 保存前后 JSON、苹果目录、页面 AX 及公开页面截图保存在忽略目录 `build/down2-update-20261016/`；仅公开发布信息进入 Git。早期未发布准备稿与最终回读分开保留。
- 本轮只改配置及文档；未重复执行 App 全量测试或构建。实际检查为苹果公开目录、后台保存、公开产品清单差异、页面内容/链接、原安装包可用性及文档 diff 检查。历史构建、正式签名和实物结果仍以各轮记录为准。
- 页面现有内部测试说明及支持链接保持原样。下载页可用不等于完成新一轮 iPhone 安装、活动/睡眠或全部型号戒指验收。
- 交付使用 GitHub Git Data API 发布与本地验证一致的树，更新远端 main 时核对预期 HEAD，不强推；最终提交号、fetch 和干净工作树以本次 Git 回执为准。

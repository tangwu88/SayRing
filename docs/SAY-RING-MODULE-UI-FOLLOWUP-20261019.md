# 2026-10-19 百科/商城真机续验

## 范围与起点

仅 Say Ring 既有百科/商城的两个公开一致显示开关。按用户续做要求恢复原 iPhone 15 Pro Max / 1118 页面控制，不卸载、重装、清数据、切账号、解绑、发起新测量或改变其它配置，不动审核和前端 main。

已阅读项目边界及上轮 1118 记录，`git fetch --prune origin` 后 `git pull --ff-only origin codex/macos-update-20260930` 为 Already up to date。起点 `34d5a9f68c916798f8bdbcf3ebdfe60529c23786`，工作区干净；运行源码仍为已验 `8d29336`，本轮不改客户端源码或构建。

## 连接与授权恢复

新的私有证据目录权限 0700、位于 Git 忽略的 `.build`。`pymobiledevice3 usbmux list` 实际发现原目标 USB；只读应用查询确认 `cn.saydian.ring` / 1.0.2 (1118)。CoreDevice `lockState` 回读 passcodeRequired=false、unlockedSinceBoot=true，不再沿用上轮离线/要求解锁的旧状态。

原端口转发仍指向同一精确设备，但 WDA `/status` 返回 socket reset。首次按构建内 productBundleIdentifier 查询 runner 未匹配；只读应用枚举找到真实签名包名 `cn.saydian.ring.qa.xctrunner`，只使用已安装的 Say Ring 专用组件，未安装新组件。

`pymobiledevice3 developer dvt xcuitest --native --udid <精确原设备> --output-log <私有文件> cn.saydian.ring.qa.xctrunner` 首次 runnerReady，但未开始测试；原生日志明确 enabling automation mode 等待 60 秒超时。不是 App 崩溃或页面测试失败，不能算 WDA 就绪。

告知需在手机完成 XCTest 系统验证、不得发送密码。核对本次失败 host 的命令、设备、私有日志路径及组件身份后，仅中断该 host，不终止 Say Ring；同一组件只重触发一次，没有切换身份或绕过系统授权。

第二次实际 `/status` HTTP200 / ready=true / iOS26.6，未发生相同授权超时。创建没有 bundleId、没有自动启动/终止行为的新 WDA 会话；手机未锁，Say Ring 起初后台状态2，实际焦点为系统桌面，而非其它人使用中的 App。

再次以 auto 焦点确认系统桌面/未锁，才正规激活已安装的 `cn.saydian.ring`。新焦点、状态4、PID47184 与原应用一致；没有重新启动或安装包、停止目标 App、修改账号/绑定、输入或读取密码。

## 真实双关闭基线

首先实际截图并视觉确认 Say Ring 设备页，不用 `/status` 或隐藏语义节点冒充页面。随后唯一可见底部“健康”标签真实触摸，取首页截图并再次视觉核对：健康百科、商城两个入口均不显示；其它已授权卡片仍显示。

原设备页有正常连接/读取表现，但本轮只观察，不把它记作新的 SDK 握手、三轮重连或新测量通过；不发送手动测量、同步、解绑、设备设置命令。页面恢复过程没有对本机健康记录做编辑或删除。

完成后恢复并回读 WDA `defaultActiveApplication=auto`，不占用其它 App 前台。照片、昵称、账号/设备连接标识和健康值截图只保留本机私有证据，不进入 Git、不发送给服务端作为公开素材。

按服务端证据引用请求，在同一首页、不切页/点击的前提，只读找到导航容器，使用 WDA 原生 `element.screenshot` 取得局部证据；不是裁剪旧图或 AI 重绘。北京时间 00:23:54 的原生截图经视觉复核仅含“远程关爱/运动”导航，无账号、健康值或设备标识；矩形边界和图片 SHA-256 均有私有记录。服务端只收到该安全局部图的本机路径/时间/哈希，全图仍不导出，自动焦点已恢复。

## 当前后台与正向待验

本轮独立 HTTPS 回读 root/global readiness 均 200 / dcc9d2a / ready；Say Ring/iOS 契约为 schema1、300秒、health_library=false / mall=false。hideAi=false、sleepAiEnabled=false 等非目标配置未由客户端改动。

服务端任务的官方后台浏览器页面控制此时超时，尚不能协调真实开关保存。其反馈已按原授权通道恢复但未成功；没有执行任何生产写入，双关闭保持。客户端不自行改数据库、读取浏览器凭据或通过其它系统工具绕过浏览器访问限制。

因此当前阻断已从“手机未连接/要求系统验证”变为“后台浏览器控制待恢复”。本轮手机就绪及双关闭首页基线通过；true/false、false/true、真实分类/正文和商品目录/详情读取、打开页撤销、相互独立及最终恢复双关闭的正向真机验收均未执行，不能标记整体开关联验完成。

## 交接

- 本轮只补真机证据与验证记录，未改 App、配置协议、权限上限或原有数据，无需为此重建/重装。
- 后台控制恢复后，先核对精确设备/1118/真实焦点，再与原服务端任务协调逐项开关，不扩大购买/支付、健康采样或上传权限；最终恢复 false/false，重新读取确认。
- 不重复首次失败的授权尝试，不无限弹系统验证；后续截图仍要实际视觉确认，不能复用旧截图或将服务端 HTTP 测试冒认真机通过。

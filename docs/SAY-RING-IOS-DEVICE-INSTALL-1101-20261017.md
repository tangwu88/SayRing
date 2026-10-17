# iPhone 15 Pro Max 安装 1.0.2（1101）

## 授权与安装来源

- 用户在 Android 正式包准备期间要求“先安装苹果版到连接的 iPhone 15 Pro Max”。本轮仅处理该手机的 Say Ring，Android 正式包与下载页请求保留，等待原签名目录可读取。
- 修改前 main/origin/main 均 `7adc5cedaf828234b8e366a6be244fe4b2858512`，工作树干净，fetch / ff-only 核对成功；阅读 AGENTS、交接、近期发布记录与保数据约定。
- 使用此前送审的同一份 `SayRing-1.0.2-1101.xcarchive` 中正常 main 的 Runner.app。它已经具备原团队 `W7SXQ4A226` 的有效 Apple Development 真机签名，Profile 包含指定手机，有效期至 2027-10-13；不是从 App Store 分发 IPA 直接安装，也没有临时换 Bundle 或重新编译产品代码。
- 严格深验签通过，实际身份 `cn.saydian.ring / 1.0.2 / 1101 / iOS 15.0 / iPhone`，`get-task-allow=true`。编译配置为 **Release / AOT**，可脱离 Flutter 调试器独立启动；签名类型不应误标成 App Store 分发签名。

## 保数据覆盖与核验

- CoreDevice 确认指定 iPhone 15 Pro Max 已连接；同机安装列表原为 Say Ring **1.0.1（1100）**，应用数据容器可访问。设备上其他产品和另一台 iPhone XR 没有安装或改动。
- 安装前只针对该应用精确查询进程，未发现正在运行的旧实例。通过 `devicectl device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring --source .` 备份当前容器，**44 文件 / 24,623,946 字节**；副本、逐文件哈希和设备标识保存在忽略的 0700 私有目录。
- 执行 `devicectl device install app` 覆盖安装，不卸载、清库或解绑。安装返回成功，安装列表再次回读 **1.0.2（1101）**。
- 在正常启动前再次复制容器并比较哈希。安装后 42 文件，差异仅为 iOS `Library/SplashBoard/Snapshots/` 的 4 个旧快照消失和 2 个新快照出现，其他既有文件没有内容变化；Documents、数据库及持久化设置哈希一致。没有把系统快照变化说成“全部文件逐字相同”，也未为消除差异回写用户数据。
- 安装、版本回读及安装后容器检查合计 **6.6 秒**，各命令退出码均 0。
- 通过 `devicectl device process launch cn.saydian.ring` 正常前台启动，不使用测试入口或 start-stopped。**启动后 66.3 秒原进程仍存活**，CoreDevice 截图可见正常首页、原登录资料和既有活动/睡眠记录，不再停留在启动准备界面。
- 截图和实际健康值仅私有保存，不进入公开 Git。本次是覆盖安装和启动验收，没有重新执行所有戒指模式、睡眠采集或 AI 供应商生成测试；不把安装成功视为商店审核已通过。

## 交付

- 本轮不修改产品源码、签名身份或商店审核；沿用同源码此前已通过的完整回归，不为记录重复测试/构建。仅提交本文、Android 准备记录及索引；交付使用已授权 GitHub 连接发布同一 Git tree，租约核对主线，不强推，并以 fetch 回读为准。
- 私有安装回执：`build/ios-device-release-1101-20261017/install-verification.json`。应用保持正常 Release 运行，未附加或依赖 Flutter Debug 会话。

# Say Ring 1.0.13（1295）TestFlight 内部测试

2026-11-10，Asia/Shanghai。交付对象为 Say Ring（App ID 6816549943，cn.saydian.ring），仅使用既有内部组「Say Ring 真机验证」。本次不提交外部 Beta 或正式 App Store 审核。

## 构建和上传

- 归档前对干净的当前分支执行 `git fetch --prune origin codex/u19-system-language-20261110` 和 `git merge --ff-only FETCH_HEAD`：已是最新；源码 6308a64649a047897aeb1d6a428033d519c83b92。运行源码 SHA256 为 cacdc9e290df98489e15a2297decfe30e415ac1cf6f76d4967f1f85f3558bfac，与已验证的 1295 一致。原回归记录见[戒指分流及血压等待修复](SAY-RING-U19-BP-RING-BOUNDARY-1295-20261110.md)：两个时区各 2321 项通过。
- 私有构建目录 build/ios-testflight-1295-20261110-bldtozqp。执行其中的 `python3 build-archive.py`：正常入口 lib/main.dart；1.0.13 / 1295；Release 配置 15.78 秒、归档 49.20 秒，均退出 0。核验 arm64、AOT、开发签名、包名和团队 W7SXQ4A226；Xcode Archives 中的保护副本重新验签，临时 Flutter 配置已恢复。未改产品源码，未在手机安装或发起测量。
- 本机无发行私钥，直接使用 Xcode Organizer 的 App Store Connect 分发。首次按 bundle ID 打开 Xcode 因两套 Xcode 重名未选定；改用归档所用的 /Applications/Xcode.app。明确选择 21:52 创建的 1295，详情同时显示 cn.saydian.ring 和 1.0.13 (1295)，没有上传旧归档。
- `python3 record-organizer-payload.py` 与 `python3 verify-packaged-ipa.py` 核对本次实际上传 IPA：39,405,070 字节，SHA256 c63f1d957ef20757241355c2907f2c4cf9f8774c3b017ec6ddcacbfc9090aae8。严格发行签名、生产推送、App Store 描述文件、正常 AOT、arm64 通过。22:00 Xcode 显示 Uploaded，构建号 1295；15 个供应商框架缺少 dSYM 的警告没有阻止接收，对应框架崩溃栈的符号化仍受限。
- 首次刷新网页后的控件等待早于页面加载完成而超时；随后读取实际构建上传列表，看到 1.0.13（1295）「正在处理」。此时尚未分配本版，未重复上传。正式页只读基线为 1.0.12（1275）可分发、手动发布。出口合规依据：与 1294 比较 iOS 原生源/Pods 和依赖清单无变化，仍用 SQLCipher 4.10.0；现网 174 个地区可供应，法国未供应。本次不修改地区、账号和测试成员权限。

## 内部测试交付

- 苹果完成处理后，1.0.13（1295）构建 ID 为 c635a54d-1779-46b3-84af-793bf0a74aee。按实际标准加密和法国未供应状态保存该构建的出口合规信息。保存控件在选择后由按钮变为文字；首次按按钮定位没有提交，随后使用实际文字控件保存。页面尚未刷新时点击添加组再次出现问卷；取消空白问卷、重新加载后，已不再要求合规。没有重复申报或更改地区。
- 中文、英文「测试内容」分别保存，重新载入后逐字读回一致：请验证 R8/R8 Pro、R21/R22、R7 系列及 HR05 保留原戒指界面；仅 U19 打开手表界面；U19 血压完成后应取得新读数，或明确结束等待。自动化回归和本轮分发不算真实手表新结果、本机保存、云端同步已通过。
- 在构建详情仅勾选「Say Ring 真机验证」（内部），不选两个外部组。保存后构建详情显示群组 (1)，成员 3，独立测试员 0。组内的构建标签与侧栏同名；使用明确的组内导航重新打开，未误操作其他组或测试员。
- 实际组列表显示「内部群组 ∙ 3 个测试员 ∙ 19 个构建版本」，1.0.13（1295）为「正在测试，90 天后过期」。成员可从 TestFlight → Say Ring → 更新。上述状态不等于任何成员已安装或完成实测。本次没有更改 1294、外部测试或正式版 1.0.12（1275），没有提交正式审核。
- 私有记录：archive-proof.json、packaged-ipa-proof.json、archive-to-ipa-identity.json、upload-result.json、internal-delivery-proof.json、testflight-1295-internal.jpg。归档及苹果上传 IPA 的 Runner 与 Dart AOT UUID 相同。Git 只记录交付事实，不提交 IPA、归档、账号页面或本地签名材料。

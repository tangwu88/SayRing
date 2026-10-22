# R21 iOS历史同步能力修复

2026-10-22用户提供R21_D47C已连接但按钮显示“此戒指历史同步暂未开放”的截图，确认设备为Mac在线的iPhone 15 Pro Max。问题P1：实际集成的历史同步被误判为不支持，用户无法点击同步。基线9981151d38d26e2b8673d8a6d27e7c2aba8a47d5，工作树干净，已fetch并阅读项目约定、交接、回归和最新1129交付记录。

先排查首次绑定初始化保护；保数据读取该机容器后没有初始化待确认回执，不能将本例归因为未完成初始化。确认已安装1.0.5(1129)。随后实际Foundation编译复现：@(![self factoryInitializationPending])生成NSNumber int（CFBoolean=0），而@YES或显式BOOL生成CFBoolean。Flutter标准编解码会将前者传成数字1，Dart DeviceCapabilities严格布尔判断因此为false。

修改范围仅iOS QRingWearableBridge.m该能力字段，使用真实@YES/@NO，保留初始化未确认时false、原生历史读取保护、所有者/目标隔离和不重复恢复出厂。Dart不放宽为数字真值；Android使用Java Boolean，不受此iOS装箱问题影响。新增执行实际生产表达式的Foundation回归覆盖正常与初始化待确认两种状态，并做R21保数据同步实测。失败、构建、安装、同步和Git/发布结果继续据实追加。

Foundation回归先运行旧表达式，3项中1项因CFBoolean断言失败、2项原保护测试通过；修正表达式后3/3通过（0.98秒），证明未将待初始化开放。首轮Analyzer对新增真机测试报多余dart:async和未使用models导入，已移除；UTC全量1411通过23秒，上海及最终分析继续执行。真机容器备份成功并置于权限700的忽略目录，无清理、解绑或重置。

## 实际门禁与R21真机

最终Analyzer零问题11.4秒，上海全量1411通过30秒，Node135项中134通过/1Windows限定跳过，Python发行35通过。Android Debug19.1秒、显式QA Release编译检查65.5秒、双ARM限定原生JUnit5.0秒成功（54项）；该QA产物不作为正式包发布，公开Android1129保持原签名与原文件，iOS类型修复不改变Android实现。

iOS Debug配置19.1秒/签名构建30.9秒成功；普通Profile配置18.0秒/签名42.9秒、专项配置18.5秒/签名25.4秒成功。冻结普通App.framework SHA256 b5324fb660d712cd8650696c1ff424dc9a44df77e6995b6f3ad94978b86e6f6a，专项d9f592bf0bc9b0e15e0a6aabac457a632763afe22ee126e2991d0548affbc90f。两者严格验签、cn.saydian.ring/1.0.5/1130、团队及15 Pro Max设备许可通过。

使用preserving wrapper与明确专项Profile执行真实R21：测试前备份1.4秒、drive41.4秒、结束备份1.3秒、普通1130原位恢复3.1秒、正常启动0.3秒均退出0。四个实际断言组通过：原R21绑定保留；原生经Flutter通道返回真正bool true且Dart能力true；同步按钮可点击并无“暂未开放”；一次真实历史同步SDK完整回执成功、同账号同戒指、同步结束且无错误。截图已保存核验。未解绑、未清空或恢复出厂；不将该结果推广为睡眠传感器数值校准。

Release配置19.3秒/归档31.9秒成功，2026-10-22 18:17创建的确切1130已核验包名/团队/签名并在Xcode打开；发行导出0.7秒退出70，仍No Accounts/缺发行私钥。已请求原生窗口手动上传1130，未重试账号刷新或上传其它归档。后续Git、CI、TestFlight和App Store替换回执继续追加；不把已归档当成已上传。

## Git与苹果替换进度（18:31）

修复源码及实测记录已推送公开仓库当前分支codex/qring-visual-refresh-20261021，源码提交de650ff4cc722c52edee1b4b33dbcbe51186132b；fetch/ff-only和clean工作树核验成功，git fsck --full退出0（仅历史悬空对象）。远端mobile-ci #257 / run39762458378的quality及UTC/上海Harmony契约已成功；iOS、Android构建仍运行，不将其写成全绿。CI链接：https://github.com/tangwu88/SayRing/actions/runs/39762458378 。

在用户此前替换旧构建的授权范围内，已取消1129的App Store提交34637700-34e9-4a62-a634-c36d0ce9abb3；等待处理后读取到“被开发者拒绝”，再移除1129构建选择并保存。再次加载确认1.0.5“准备提交”、无1129选中、保存按钮禁用；1130修复发布说明及审核备注已保存，原功能披露和登录信息保留。公开稳定1.0.4(1120)未改动；1129独立Beta审核仍等待，未过期旧构建、未添加测试员或发送通知。

截至本次交付，App Store Connect仍未出现1130，原生Xcode手动上传问题待用户回执，因此1130尚未选择到TestFlight或提交苹果审核；不能把已归档、手机已装或已保存文案等同已上传/已送审。待上传处理完成、CI最终结果核验后再选择1130并完成审核。法国仍沿用用户已授权暂停供应的状态，未接受新法律协议。

补查ios/Runner其余字段，无其它@(!...)装箱表达式；Dart严格bool解析与首次绑定保护均不放宽。Android公开1129、Harmony配置及下载页稳定iOS入口均保持本轮原值。手机已安装普通主入口1130，专项测试已结束。

记录追加首个Python heredoc命令因非UTF-8输入解析失败，未写入文件；改用apply_patch完成，未影响构建或测试结果。

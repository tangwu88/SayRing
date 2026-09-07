# Android r6 真机覆盖预检与连接阻断（2026-09-07）

## 范围

- 用户重新连接 Android 手机后，仅接管指定 P40，目标是使用已验合格的 r6 QA Release 同签覆盖，不卸载、不清数据、不使用降级绕过。
- r6 QA Release：`Saydian-Android-QA-Release-JPush-0.1.19-build23-20260907-r6.apk`，64661988 字节，SHA-256 `b419c738d219c940544392a0013aa8c3d703b075c2a12fce19b38386eaf025aa`；本次不重新构建、修改源码/签名、上传或执行 Git 操作。
- 不操作 iOS、Harmony、Chrome；不发邀请、推送或支付，不更改账号共享，不连接 ET488 或抢占 Harmony 正在测试的 W9S。

## 已完成的只读核验

| 项目 | 直接证据 |
| --- | --- |
| 初始连接 | 指定设备最初为 `device`（已授权），机型 ELS_AN00；不是把之前的 unauthorized 当作当前状态 |
| 当前安装版本 | `cc.saidian.app / 0.1.19(23) / minSdk26 / targetSdk36`；当前包 debuggable=true |
| 安装时间 | firstInstall `2026-08-30 18:52:53`，lastUpdate `2026-09-07 05:58:20` |
| 现装包身份 | 直接读取手机当前 `base.apk` SHA-256 为 `e8284f2fa34a84d354eefea3320b9f0b19955e4d0b43864679ed641e91b1359f`，确为 r5 Debug，不是 r6 |
| 官方验签 | 将现装 APK 只读复制到本机受限临时目录，再运行官方 `apksigner verify --verbose --print-certs`；V2=true，证书 SHA-256 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`，与 r6 QA Release 一致 |
| 重连安全预检 | 只读已装 Debug 应用的 `saidian_wearable_connection`，`last_device_id`、`last_device_name` 非空；只输出存在布尔，未记录 MAC 或原始名称 |

Android 原生 `restoreConnection` 会使用非空保存目标恢复连接。为遵守不抢占手表的约束，不能在目标尚未辨明时直接启动新版；没有通过修改 prefs、权限或全局蓝牙开关规避检查。

## USB 断续与停止点

- 在读取保存目标分类前，指定设备短暂消失，命令返回 `device not found`；随后设备列表曾恢复为已授权，但 transport 已从 75 变为 77，说明连接发生重新枚举。
- 后续相关只读读取再次失败，设备列表为空。最后 **08:39:46 CST** 的 `get-state` 仍为 `device not found`。按主线程限定停止重试，没有无限轮询、重启 ADB、重置调试密钥或系统安全设置。
- 一次诊断管道在设备命令失败后仍解析了空输入；该输出不能作为“没有保存目标”的证据。随后改为先检查命令退出状态，失败时只返回 readable=false；真实有效预检仍是保存目标存在、分类未取得。
- 主线程允许在连接稳定时先同签 `-r` 安装且不自动启动；本轮连接在安装前已再次消失，**没有执行安装命令**，也没有出现或处理安装 PIN 确认。

## 当前结论与待验

- 已通过：当前 r5 的真实包哈希、官方证书、版本与时间核对；r6 与当前包同签。
- 未完成：r6 覆盖安装、安装后真实 base.apk 哈希、独立启动、登录保留、首页/远程关爱/消息页读取和通知点击。不能写安装或真机通过。
- 未取得保存设备的可靠型号分类；下一次稳定连接后先只读确认，再由主线程安排安全启动条件。ET488 不自动重连，W9S 若由 Harmony 占用则不抢连，不清原绑定。
- 原账号、共享授权、登录、健康记录和绑定均未修改。本机诊断 APK 仅在 `/tmp/saydian-android-r6-live.WiMTDA` 受限目录，不进入 Git 或交付清单。

后续实际安装与页面结果在正常恢复连接后追加；不覆盖本节失败记录。

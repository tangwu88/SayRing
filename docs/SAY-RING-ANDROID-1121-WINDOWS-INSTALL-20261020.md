# Windows 同步代码与 Android 1121 安装

## 用户授权和范围

2026-10-20，用户要求同步最新代码并安装手机，明确允许直接卸载旧版本。已告知卸载会清除本机登录、设置和未同步数据。仅处理 Say Ring `cn.saydian.ring`，不删除其它 App、服务器账号或云端数据，不修改业务源码、供应商或后台配置。

## Git 同步

- 原打包工作树 `E:\SayRing-market-release-20261005` 位于正式1111分支 `d54bdfa`，工作树干净。
- `git status --short --branch`、`git remote -v`、`git worktree list --porcelain` 后，使用进程级HTTP/1.1和本机代理执行 `git fetch origin --prune` 成功。
- 保留原1111分支和全部历史，不将其两个独立提交硬合并进新开发分支；用 `git switch --track -c codex/native-mall-android-1121-20261020 origin/codex/native-mall-android-1121-20261020` 切到最新1121分支。
- 同步后 HEAD 为 `9371bb0c2a09a73caae9dd3a4dc91d05d1d810c4`，与对应远端比较0/0。另一个 `E:\SayRing` 工作树及其用户文档改动未触碰，main未提升。

## 安装前检查

- ADB仅一个已授权在线设备，型号JAD-AL00；系统读回当前用户0、Awake、deviceLocked=0。具体设备序列号不写Git。
- 精确包列表确认旧 `cn.saydian.ring` 存在；独立国际版 `cn.saydian.app.global` 不在卸载范围。
- 先读取产品`say-ring`公开更新清单，确认global realm、Android包名、1121构建与既定SHA-256；完整下载、官方签名及版本检查成功前不卸载旧版。
- 本轮使用已发布且与最新运行源码一致的正式1121，不重新构建、不回退1111旧包、不把Debug或QA包当正式包。

## 实际结果与待验

1. 使用公开产品清单确认目标后，`curl.exe --fail --silent --show-error --proto '=https' --connect-timeout 20 --max-time 240 --output <Git外APK路径> <同源不可变地址>`完整下载成功；没有自动跟随重定向。文件71,832,499bytes，SHA-256 `61834ff3058d056ead83e1f55358d25e11d3c56ee86dac7f4e259c8fe85f4fe3`与公开清单和正式构建记录一致。
2. 本机JDK17下运行build-tools36 `apksigner verify --verbose --print-certs`退出0、v2签名通过，原证书SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。`aapt dump badging`实际包名`cn.saydian.ring`、1.0.5/1121、min26/target36、双ARM且非debuggable；`zipalign -c -P 16 4`通过。
3. 精确设备执行`adb uninstall cn.saydian.ring`返回Success，随后包列表确认旧包消失，才执行`adb install <已验证APK>`。旧App本地数据按用户授权清除，没有声称可恢复，也未解绑系统蓝牙或删除云端数据。
4. 安装期间系统前台为华为InstallDistActivity，已请用户本人确认安装和可能的身份验证；没有代输密码、关闭安全检查或绕过验证。原安装进程随后返回`Performing Streamed Install / Success`，未取消/重发并发安装。
5. 安装后`dumpsys package cn.saydian.ring`实际回读versionCode1121、versionName1.0.5、无debuggable标志，首次安装和更新时间均为手机北京时间2026-10-20 10:58:24。`am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity`返回Status ok，已运行的对应Activity接收启动；`pidof`返回真实进程。另一独立国际版包仍在。
6. 收尾再次fetch成功，提交前源分支与远端0/0；`E:\SayRing`原main和用户文档改动保持原样。仅新增实施文档和索引，不修改运行源码；`git diff --check`通过。不重复原1121构建的完整静态/双时区测试，不把已有软件回归当本轮手机功能验收。

未进行真实登录/验证码、戒指连接/健康采样、支付或页面全量调试；未改后台、下载清单、鸿蒙包或市场审核状态。原1111分支的双端验签工具仍由独立分支保留，没有无需求混入本次已发布1121源码。下载的正式APK只存`E:\SayRing-market-artifacts-20261020\install-1121`，不入Git。

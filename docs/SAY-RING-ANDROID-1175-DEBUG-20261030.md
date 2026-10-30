# Android 1175安装与真机调试

用户在iOS1175送审期间追加要求：最新安卓版本也安装到连接的安卓手机，开启真机调试。生产运行代码与本轮1175能力显隐候选一致；本地已对齐已发布等价提交d840ec949d8e48eb7a262ecae8b3e39a4491eb1d，工作树仅有本轮发行记录修改。没有改动生产源码、签名配置或原SDK。

## 构建与身份

- 连接设备为华为PPA LX3。开始时原安装1.0.7（1167）、UID 10139，普通设备页显示R12已连接及真实电量。原APK私下拉回验签，证书SHA256为81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。原正式包不可导出完整容器；原APK备份不等于健康数据库备份。
- 1175正式APK此前已独立构建/核验，见健康提醒1175记录。本次为了真正接入Flutter/DevTools，另用生产环境配置和`lib/main.dart`编译Debug，保持cn.saydian.ring/1.0.7/1175及双ARM，再在私有目录使用原发行密钥签名；不修改仓库Debug签名规则，不发布调试APK。
- 首次签名失败exit2：同一个单行密码文件同时传给store/key两个参数，apksigner按顺序读取第二行时EOF。按该工具帮助，移除重复key-pass参数，复用同一keystore密码后签名成功；保留失败日志，不输出密码或将其置于命令行。
- 最终私有Debug APK 189,577,422字节，SHA256 504821f09979e2a5852823b4091c82ba35d69891785465b24ba468b09f100486。原证书、签名验证、ZIP16KB对齐、包名/1175、debuggable和278个生产输入指纹均核对。手机实际安装APK拉回后的SHA与此完全一致。

## 安装及原数据边界

第一次只执行`adb install -r`。宿主尝试incremental，手机不支持后回退streamed，安装器显示风险提示，终态为INSTALL_FAILED_ABORTED / User rejected permissions。用户随后要求“重新安装”。重新发起前的系统查询已找不到旧package（包括-u列表）及/data/user/0/cn.saydian.ring；本轮没有执行uninstall、pm clear、删除目录或其他手机容器导入。不能推断旧包/目录消失原因，也不能称原本地数据已保留。

按用户重新安装要求执行`adb install --no-incremental -r`，对当前可见“继续安装”按钮正常点击后返回Success。新包UID 10140、安装时间已更新，证明本轮属于新安装，不能登记原位覆盖验收。已向用户说明旧本地目录不存在的事实；没有以当前新容器备份冒充原数据恢复，也未做跨账号/跨手机数据合并。

安装后启动普通入口；当前停在未勾选协议/年龄项的登录页。现有新容器在实际调试前通过run-as私下备份成功（104,346,112字节）。本次未自动登录、重新绑定或重置戒指；1167开始时的R12连接不能算1175的硬件验收。旧本地记录未恢复，云端恢复及本轮戒指/健康功能验证尚未执行。

## 调试实证

仅使用`flutter attach --debug -d <实际设备> --app-id cn.saydian.ring --target=lib/main.dart --dart-define-from-file=<本机生产配置>`附加已经验证的现有安装，不使用可能卸载的drive流程。VM与DevTools实际连接成功，页面显示arm64 Android / Flutter native debug build；一次普通热重载8个库，2311毫秒成功。USB调试会话保持，现有DevTools标签已指向这台安卓手机。

私有APK、完整容器、界面树、手机截图、签名和配置均位于忽略的build/reminder-visibility-1175-20261030/android-device-debug；不提交Git、不切换公开下载页。与此并行的iOS1175上传/TestFlight/App Store状态独立见[1175发行与显隐记录](SAY-RING-REMINDER-VISIBILITY-1175-20261030.md)。

# 邮箱验证码自动注册及安卓紧凑登录1308

## 范围与基线

- 用户要求邮箱验证码验证后自动注册并登录；安卓登录尽量一屏，验证码获取移到输入框内右侧，模式切换移到原获取位置。完成后原签名覆盖安装。
- fetch后本地与同名origin均为01a8df1f18138a7784f6c06044bb9f205ea72e36，工作区干净；保留当前codex/u19s-android-connect-20261111分支。服务端在原隔离工作区从最新main c7bd29f另建专项分支，无覆盖其他工作区。
- 修改lib/domain/global_account.dart、lib/ui/global_code_login_page.dart及对应回归；后端修改实际自动注册限制并公开emailAutoRegistration能力。保留协议及14岁本人确认、6位验证码/冷却/身份归一与现有账户，未向真实邮箱短信发送验证码。原密码默认、原注册页、iOS布局顺序和全部功能保留。
- 安卓把品牌与急症求助放同一行，正常字宽时登录标题与手机号/邮箱选项同一行，减小输入内边距；大字号分行并可滚动。安卓验证码按钮内置右侧，密码登录切换在输入下方。

## 验证记录

- 电脑目前未检测到手机，已请用户连接；完成安装前不声称已安装。
- 初次只读搜索含不存在路径和Windows字面glob失败，随后按实际文件目录定位。
- 定向/双时区全量/构建验签、Git、真实手机页面与安装待后续追加。

## 定向反馈与修正

- 首轮定向：英文标题与渠道同排导致溢出，现仅正常字号中文合并标题行，英文/大字号保留分行；两项大字号夹具依赖ListView屏外惰性节点，改为按实际方向滚到控件后输入/操作。重跑90项全部通过，覆盖邮箱登录、严格能力、原密码/微信/协议/6位自动填充。
- 截图临时夹具最初调用未带ui前缀、截图Future处于假时钟、一次字体路径转义失败，修正临时夹具后可渲染；Windows宿主部分按钮字形仍是测试方框，故只作为几何检查，不宣称真实字体或实机截图通过。临时测试已移到Git外部并移除，未将字体或图像提交。
- 补充代码复查发现提取按钮后iOS的右对齐包装丢失，已恢复；中止初次UTC全量后按最终源码重新执行全部门禁，保留原日志不覆盖。服务端定向70项及全部根级门禁通过，源码d090de9已快进main，CI/生产仍在进行。
- 同步更新AGENTS.md的已批准邮箱验证码流程边界，避免旧“邮箱必须独立密码注册”指导覆盖本次用户要求。默认密码登录、注册入口与已有无密码账号找回流程保持；渠道能力只按严格布尔读取。
- UTC最终全量2432项通过；账号接口辅助Node78项通过。后续时区/构建以外部逐阶段日志为准。

## 最终构建与交付检查

- 最终format、静态分析均通过；UTC/Asia-Shanghai各2432项完整Flutter测试通过；Debug构建通过，Android原生25套件134项测试无失败/错误/跳过。账号辅助Node78项通过。定向90项通过。
- 原正式签名Release构建、apksigner v2、non-debuggable、包名/版本、正常Main入口及生产manifest/JPush、双ARM ABI、ZIP16KiB对齐和QRing复制30项门禁全部通过。pubspec/lock、原生Android/iOS/鸿蒙源码与基线无差异，临时android/key.properties已移除。沿用两个旧32位厂商库的4KiB ELF LOAD限制，不当作全部市场验收。
- APK：`E:/SayRing-auth-1308-20261116/SayRing-1.0.14-1308-release.apk`，74519917字节，SHA256 `2ef2893ee1a62c658ca235abddcac01197aa0fccd8db8c93acdf9596ab1b0029`。包名cn.saydian.ring，1.0.14（1308），正式证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。
- Windows本轮没有Xcode，本机不宣称iOS Debug/Profile编译通过；推送后由现有macOS CI分别检查，非签名iPhone验收。没有改下载清单、上传APK或商店提交。
- 服务端运行时代码d090de9、[CI/双区部署43826724525](https://github.com/tangwu88/saydianserver/actions/runs/43826724525)全部成功，root/global readiness均同revision，公开Say Ring能力emailAutoRegistration=true/smsAutoRegistration=true。未向真实邮箱或手机号发送验证码，无新增生产测试账号。
- 用户重新接入的当前华为仍为同一设备，安装前读回1307；物理1228×2700/density540，约364dp宽，与360dp紧凑回归相近。已发起`adb install -r`保留数据覆盖，当前华为风险确认待本人完成，未卸载/退出账号/改绑定/清记录。实际安装回执另记。
- 提交前第一次fetch网络Empty reply失败，改用本机现有代理仅对本命令重试后成功；HEAD和同名origin均仍01a8df1，未覆盖远端。仅显式提交本轮AGENTS、页面、能力解析、测试及记录。

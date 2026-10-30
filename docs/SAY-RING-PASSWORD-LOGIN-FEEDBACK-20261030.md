# 2026-10-30 密码登录长度反馈修复

## 原因、范围和基线

用户反馈密码位数不符合要求时登录页提示“此功能暂时无法使用”。GlobalCodeLoginPage只拦空密码；GlobalAuthPage只在注册/重置时检查长度，登录不检查；两个页面均未识别服务端的invalid_password，最终落到服务不可用文案。

修改前status/remote核对当前独立仓库tangwu88/SayRing，工作区干净、本地7c91f8c。已阅读AGENTS、国际交接、变更索引、最新华为ELS记录、跨模块回归及复盘。fetch --prune一次低速超时，两次定向fetch连接重置；随后显式使用本机既有HTTP代理定向fetch成功，发现仅一项文档更新8683ac2，工作区干净时merge --ff-only成功到该基线。未覆盖、强推或修改main。

只修改两个Flutter国际登录页面与对应两个测试文件。对照现有服务端GlobalAuthService.password：最少8个UTF-16代码单元、最多72个UTF-8字节，与注册/重置现行规则一致；不修改服务端密码政策、账号、认证协议、验证码或授权。用户提示复用已有本地化passwordRequirement，不显示原始服务端内容，不裁剪密码来通过校验。

## 实现

- 主登录的手机号/邮箱密码模式在提交前检查长度，空密码继续提示输入密码；不合法长度不会调用登录接口。
- 备用登录表单也应用原注册/重置已有的长度校验。
- 两个入口的invalid_password精确映射到已本地化密码要求。invalid_credentials仍使用账号/密码不正确提示，真正网络和服务故障保持原有分类，不把任意400错误误标为密码错误。
- 验证码登录、成功导航、法律/年龄确认和所有健康/设备业务保持原流程；没有真实登录、短信、付款、设备指令或手机卸载/安装。本机手机仍为用户刚要求恢复的1163，本源码修复尚不能视作已在该旧包生效。

## 回归与执行记录

新增24个页面回归案例，使用合成手机号/邮箱和Fake控制器，不向真实通道请求验证码。覆盖手机号/邮箱空密码、7位、73位、中文UTF-8超限、8/72边界合法请求、服务端invalid_password和503；备用入口覆盖本地拦截和服务端同类错误。断言不合法输入不调用登录、不显示笼统功能不可用、不泄露私有错误详情；原验证码、同意及导航用例继续运行。

定向`flutter test --no-pub --concurrency=1 test/global_code_login_page_test.dart test/global_auth_page_test.dart --reporter=expanded`共49项通过。首次analyze在新增测试的一行if缺少花括号报info；已补花括号，重跑`flutter analyze --no-pub`零问题。首次文件搜索用了不存在的global_auth_api.dart，后核对真实global_api_client.dart及服务器现行代码；未据错误路径修改接口。

双时区全量测试、跨端构建、CI与Git回执完成后续记。Windows不具备本机iOS构建条件，远端相同源码CI回执与本机运行结果分别记录。构建日志放Git外E盘私有目录，不提交凭据、APK或用户数据。

UTC全量`flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`1636项通过（3分20秒）；Asia/Shanghai同命令正在运行。提交前再次定向fetch成功，远端仍8683ac2、无分叉，git diff --check通过。先推送已完成本机静态/全量验证的本轮显式源码、测试与日志，以触发同源mobile-ci的Android Debug/Release、iOS Debug/Profile/Release及其他平台检查；当前不冒称跨端构建已通过，结果待真实回执续记。未在Windows伪造iOS构建，也不使用旧1177构建替代新代码。

## 最终验证和Git回执

Asia/Shanghai全量1636项通过（3分30秒），本机两个时区均完成。源码及回归提交50714ac5db3d68d6ccbb9191080235647c2d591e已推送既有开发分支。[mobile-ci 41018077456](https://github.com/tangwu88/SayRing/actions/runs/41018077456)实际最终completed/success：quality、两个时区Harmony contracts、android及ios五项全部通过。Android任务包括Debug/Release、原生单测和SDK不可变缓存回归；iOS任务包括无签名Debug/Profile/Release与RunnerTests编译。这里只确认CI构建，不将CI的QA签名构建当作新正式发行包或真机验收。

收尾再次fetch发现同事已保留50714ac并合并两项同步提示修复/记录，当前工作区干净，安全fast-forward至b332aacc2f0676e6a792c972445cdbb0a9e60b8e；本轮四个登录源码/测试文件相对50714ac差异为空。并行任务的设备处理及发行产物属于其冻结输入，不冒称含本密码修复。实际查询合并基线[mobile-ci 41018686933](https://github.com/tangwu88/SayRing/actions/runs/41018686933)，五项也全部completed/success；合并后宿主1638项双时区结果引用同事已提交记录，不描述为本机重新执行。之后仅提交本验证回执，不修改运行代码、后台配置或手机1163。

验证回执checkpoint为9dc3c90。首次推送被并行新提交拒绝；重新fetch发现e565975仅追加另一份设备验收文档，安全merge保留双方，无冲突，不强推。最终运行源码仍与已通过五项CI的b332aac一致；仅文档继续提交。

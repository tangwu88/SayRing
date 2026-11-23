# Say Ring 1316 健康提醒阈值检查

日期：2026-11-23。用户询问能否按设定的上限、下限弹出预警。本轮检查已有功能，不增加监测算法或发布新包。

## 检查基线

- 分支 `codex/say-ring-support-sleep-20261114`，开始提交 `493f7b08a18a8e529e70f41dba0c46ec0bfa0aa6`，工作区干净。已执行状态、远端和 fetch 核验，当前分支与其 upstream 均为该提交。另一个分支的新提交没有混入本轮 1316 检查。
- `lib`、`ios`、`android`、`pubspec.yaml`、`pubspec.lock` 与最终 1316 运行源码 `043d35105b271ef4c05add57697c7beb9ab2cd7e` 完全一致。本轮仅补检查记录与索引；既有全量回归及构建证据见 [1316 发行记录](SAY-RING-CODE-SYNC-IOS-1315-20261122.md)，不将此前的结果标为今天重新执行。

## 结论与触发范围

| 指标 | 当前比较方式 | 边界行为 |
|---|---|---|
| 心率偏高 | 新测量值 > 用户上限 | 等于上限不触发 |
| 心率偏低 | 新测量值 < 用户下限 | 等于下限不触发 |
| 血氧偏低 | 新测量值 <= 用户下限 | 等于下限也触发，界面显示“≤” |
| HRV | 相对该设备及固件的本人参考值，下降达到用户设置百分比 | 必须先保存适用的个人参考 |
| 皮温 | 比适用的本人参考值升高达到设置幅度 | 使用真实皮温字段，不能把普通体温字段替代成皮温 |
| 血压 | 未接入当前个人读数提醒引擎 | U19 血压结果或历史同步不会触发这套阈值弹窗 |

- 所有指标比较开关默认关闭，需会员开启并保存。设置保存在当前账号本机的加密存储；页面只显示当前设备确实支持并获准手动测量的项目。
- 实际触发入口为 `_saveWearableRecord` 完成本次 App 手动测量，再以 `live: shouldStopMeasurement` 调用提醒引擎。只接受当前设备、真实 wearable/appMeasurement、device_reported 质量、正确单位及不超过 90 秒且非未来的读数。纯历史、同步导入、手表独立测量后补读、未知质量、旧设备或跨账号数据不触发。
- 事件成功保存后，控制器设置 `activeHealthWarningAlert`；`lib/app.dart` 的应用级浮层显示全屏红色提醒，因此无需停留在健康提醒页。关闭提醒会记录知晓并收起，不代表测量恢复。
- 本机未读消息及 iOS 本地通知通道均已接入。系统通知需相应权限，宿主模拟请求成功不代表目标手机已经展示横幅；权限拒绝时仍可显示 App 内提醒和未读消息。已支持的戒指可按既有开关联动一次振动，不以 SDK 接受替代实物振动验收。
- 现有自动监测引擎没有生产规则和可靠场景输入；个人阈值也不修改设备采样频率。本轮不能认定锁屏、后台挂起、退出 App 或断连时具备连续预警能力。

## 本轮验证

在原工作区运行：

```sh
TZ=Asia/Shanghai "$HOME/develop/flutter/bin/flutter" test --no-pub --reporter expanded --concurrency=3 \
  test/reading_reminder_test.dart \
  test/heart_rate_reminder_engine_test.dart \
  test/health_reminder_v3_test.dart \
  test/hrv_temperature_reminder_test.dart \
  test/health_reminder_notifications_test.dart \
  test/health_reminder_haptics_test.dart \
  test/health_reminder_sound_test.dart \
  test/health_reminder_layout_test.dart \
  test/health_reminder_store_test.dart
```

- 退出码 0，115 项通过。包括心率严格上/下限、血氧含等号边界、自定义设置、关闭开关、历史/过期/错误来源不触发、真实控制器的新手测事件与未读消息、重复事件去重、通知权限拒绝、声音生命周期、账号隔离及本机持久化。
- 宿主合成读数仅用于已有测试隔离环境，未写入真实账号或健康记录。原始日志 `/private/tmp/sayring-health-alert-audit-20261123.qmYwjW/reminders-test.log`。
- 文档检索时使用不存在的 `docs/*ALERT*` 通配符导致一次 zsh 检索退出，随后以 `rg --files docs` 定位真实文档。该检索失败不属于产品错误；115 项测试没有失败项。
- 本轮没有修改运行代码、构建配置、阈值设置、系统通知权限或设备设置。未新增编译或安装；没有将此前构建和界面检查冒充本轮真实异常测量验收。
- 尚待实物证据：真实设备的一次新测量越界、目标手机前台弹窗、锁屏通知展示及支持戒指的实际振动。若目标是佩戴期间连续后台自动预警，应另行补齐真实实时数据、原生后台触发与对应型号验收，不能仅改界面或阈值宣称实现。

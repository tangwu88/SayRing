# 自定义心率/血氧数值提醒与全局红色反馈（2026-10-30）

用户追加：心率过高/过低、血氧异常均提供参考阈值和自定义，触发时全App红色与动画，提醒页减少文字、采用图形数字。本分支从已核验aac8483独立工作目录开始，保持R7历史SDK对照目录不变；两项任务最终合并验收，不互相冒用实物证据。

## 授权范围及数据边界

本次新增由会员明确开启的个人数值提醒，默认三项关闭；与V3的经审核临床监测规则分开，不启用旧默认规则。仅处理当前账号/已连接目标、新近完成且原生已校验的真实手动测量；历史补同步、缓存、过期/未来/未知质量/错误单位、跨账号及非本设备读数不触发。没有连续实时/活动情境合同的SDK不能被宣称持续或静息自动监测，不扩大iOS既有读取/手动测量租约或上传范围，不预测/排除疾病，不自动联系他人。

设置保存于原加密数据库的owner隔离metadata，不迁移或覆盖健康表、设备监测频率及其他设置。心率数值起始参考120/40来自常见可穿戴默认，血氧92来自指夹式血氧仪居家说明，均非戒指临床验证结论；不同健康状态、海拔、运动及睡眠需个人或医嘱调整。红色表示超出个人设定，不等于诊断；提供复测和用户主动求助。动画慢速、可关闭，支持减少动态效果；知晓不表示恢复健康。演示预览始终明确标注、不写事件/健康记录、不发通知。

## 参考材料

- Apple《Heart Rate and Calorimetry Activity on Apple Watch》(2024-11)：默认高120、低40，原产品还要求静止等多个条件，本产品不复制或声称满足这些条件。https://www.apple.com.cn/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf
- AHA成人静息常见60–100，睡眠/运动员低于60可能正常；不以这些范围诊断。https://www.heart.org/en/health-topics/arrhythmia/about-arrhythmia/bradycardia--slow-heart-rate
- MedlinePlus《Pulse Oximetry》：指夹式血氧读数≤92应联系专业人员；测量存在误差并受个体/环境影响，不能当作消费戒指医疗准确性证明。https://medlineplus.gov/lab-tests/pulse-oximetry/
- FDA《Pulse Oximeter Basics》：一般健康用途产品不用于决定医疗干预，读数须结合症状，严重不适不等待戒指。https://www.fda.gov/consumers/consumer-updates/pulse-oximeter-basics

## 实施/验证记录

新增个人阈值模型/来源与新鲜度校验、owner设置持久化、血氧事件类型/单位、本机事件与原通用通知链路、可知晓的全局红色柔和动画及三张紧凑数字卡。原急症求助、症状记录、历史、导出和通知设置入口保留；详细说明折叠。第一次补丁使用了旧存储类定位，未应用；改为EncryptedHealthStore和MemoryHealthStore分别扩展。首次分析发现一处num/double、未用import及新代码括号风格提示，逐项修正，保留原检查输出。

本轮尚在实施，构建/测试/实物结果继续据实补充。

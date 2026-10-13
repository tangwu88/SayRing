# Say Ring 1059 TestFlight 公开测试

## 范围与基线

- 2026-10-05，用户要求添加最新苹果构建到 TestFlight，并申请公开测试。仅操作 Say Ring（6816549943 / cn.saydian.ring），不改已有 App Store 审核、不操作其他应用。
- 开始时分支 codex/macos-update-20260930，HEAD 205b7f1aaa6087a8ceac04f69fe1a310ae02ff2a，工作树干净；fetch / ff-only pull 确认已最新。
- 使用既有正式 1.0.0 (1059)，没有改运行时代码、重新构建、覆盖安装或清空设备数据。正式包签名、产物 SHA-256 及构建门禁见 [1059 上传记录](SAY-RING-APPSTORE-UPLOAD-1059-20261005.md)。

## 操作与实际结果

- App Store Connect 上传表显示 1059“完成”。官方 API builds 返回 processingState=VALID，构建 ID cd8b2392-fe3b-4f90-a006-758c0fdaf55b。
- 为 1059 补齐出口合规：沿用用户此前明确批准的“标准加密算法、非专有算法；不在法国分发”。未选择“不属于上述算法”，未改变销售地区。保存后 usesNonExemptEncryption=false；该字段不等同于没有任何加密。
- 使用已存在、原本 0 构建的外部组 SayRing public（92b43a70-f0cb-4732-b998-282f7776c98a），没有新建重复群组或移除旧构建、旧测试员。
- 选择精确 1059，填写简体中文、英语测试重点，保留“自动通知测试员”选中，点击“提交以供审核”。内容明确实际设备测试范围、重连修复、固件入口仅展示版本/支持状态及日常健康参考用途；不宣称所有实物验收通过。
- 提交后 UI 直接显示 1.0.0 (1059)“已批准”。官方 buildBetaDetail 返回 externalBuildState=BETA_APPROVED、autoNotifyEnabled=true；betaAppReviewSubmissions 返回 betaReviewState=APPROVED、submittedDate=null。因此只确认苹果已批准外部测试，不推断是否经历人工审核或虚构审核时长。
- 公开组启用“向所有人开放”的公共链接，未设置额外人数上限；API 确认 publicLinkEnabled=true、publicLinkLimitEnabled=false。
- 新公开地址：<https://testflight.apple.com/join/k9Uye5C6>。页面标题“加入 Beta 版‘Say Ring’”，显示“查看 Say Ring Beta 版”及“在 TestFlight 中查看”。没有以另一个应用或旧链接冒充此组。
- 10:19 CST，组 builds 精确回读只有 1059，processingState=VALID / usesNonExemptEncryption=false。不新增邮件邀请、不改变开发团队访问权限或审核账号。

## 页面、接口与检查

- 浏览器已核对构建上传、合规问卷、外部组、双语测试说明、公开链接与公开邀请页；批准状态和已开启链接有 UI 与官方 API 双重证据。
- CUA 的 setValue 修改富文本容器失败（容器无 settable value），没有提交错误内容；改用聚焦全选和 typeText 替换，回读确认最终双语内容后才提交。
- 私有证据：`.build/1059-testflight-public-approved-proof.png`、`.build/1059-testflight-public-link-proof.png`。截图、私有 API 辅助文件及签名包不提交 Git。
- 本轮只修改分发元数据和交付记录，未重新运行 Flutter 全量测试、原生测试或重建。之前同运行时代码的检查结果引用上传/重连记录，不把元数据成功等同于新的真机验收。
- 依据苹果 [外部测试说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)：向外部组添加构建、填写测试内容、提交审核并配置公开链接。已完成请求，不添加未经要求的未来监控任务。

## 验收边界

- 已完成：最新 1059 可用构建、外部测试批准、公开链接可见。公开测试批准不是 App Store 上架批准。
- 未执行：通过公开链接在实际 iPhone 的 TestFlight 接受邀请并安装。没有代表用户接受 TestFlight 条款、安装到未知设备或修改其现有 App。
- 真实远离/后台/HR01 原缺回调现场、QRing 实物快门与 OTA 固件适配等既有待验项保留，不以外部测试批准抹除。
- 下载页 `/down2` 的既有苹果链接与其他组、其他产品元数据保持不动；本轮新公开链接直接交付用户。

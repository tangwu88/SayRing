# 首页设计 QA

## 2026-09-07 追加：鸿蒙表盘中心 r3（独立验收范围）

- 本轮 source：`/tmp/saydian-ios-dials-reference-current/watchfaces.png`，当前iOS生产页面离线9表盘/第三项当前/无图片，361×804逻辑尺寸；不是账号或手表实测数据。
- 本轮 implementation-before：`/tmp/saydian-dials-before.jpeg`，W9S真机1084×2412物理、约361×804vp；两图已在同一轮并列查看。系统状态栏不属于App内容比较。
- P2：鸿蒙每项独立大卡+全宽按钮，iOS为单卡片紧凑行+左预览+右使用/绿勾。r3已按源结构调整，保留系统字号、48vp操作、无图真实空态及回读确认。
- 本轮 final result: blocked。原因：源码与定向测试已完成，改后Harmony真机截图及切换/恢复仍待主线程统一构建安装。下方旧首页通过记录不能代替本轮表盘验收。

### 追加复验：r5 真机与 r11 回读

- 已同时查看上述 iOS 源参考与 `/tmp/saydian-dials-r5.jpeg`：同为约 361×804 逻辑尺寸、已安装 9 项/第三项当前/无图片的状态。前者为真实生产页面离线夹具，后者为 nova 14 + W9S 真机；不混写数据来源。
- 单一紧凑列表、左预览/右操作、行间隔、当前使用标记已按源对齐；鸿蒙合并重复顶部介绍并显示实际设备名，保留 48vp 操作区域。无真实图片时的文字空态不是伪造表盘图。
- 真机切换 3→1 后当前项即时更新，随后 1→3 并回读恢复。r11 最终包再次读取，首屏 6 项、SDK 总数 9、当前 3；未恢复旧选中态错误。
- 本项结果：已安装表盘列表与切换/恢复有界通过。鸿蒙没有正式在线目录/照片表盘桥接和真实预览资源，仍属功能缺口；不能将本项扩大为整个表盘商城或五层页面通过。

## 对比目标

- source visual truth path: `C:\Users\admin\AppData\Local\Temp\codex-clipboard-f746bcd5-fa88-432c-a816-a8dcaf4ac6fe.png`
- implementation screenshot path: `E:\saydian\赛电app\docs\saidian-home-device-20260818.png`
- side-by-side comparison: `E:\saydian\赛电app\docs\home-visual-comparison-20260818.png`
- state: 已登录首页；仓库内基线截图不包含真实健康数据。2026-08-19 的最新真机截图仅作为本地验收证据，不提交在线仓库。
- implementation device: Huawei JAD-AL00，Android 12。
- source pixels: 853 × 1844；按 iOS 2× 设计稿理解，约 426.5 × 922 逻辑像素。
- implementation pixels: 1228 × 2700；540 dpi，约 364 × 800 逻辑像素。
- density normalization: 对比图仅将真机截图缩放到 853 × 1844 后并排，未将不同逻辑宽度误当成 1:1 像素差异。

## Full-view comparison evidence

完整并排图确认以下结构与参考图一致：

- 顶部品牌 Logo、问候语、状态副标题和通知入口。
- 红金暖色 AI 健康管家主卡，左侧医生插画、右侧说明和“马上提问”。
- 远程关爱、健康百科、健康预警、赛电商城四入口。
- 健康数据标题、日期、全部数据入口。
- 血压、心率、血氧、体温 2 × 2 健康卡。
- 底部仅保留健康、设备、我的三栏导航。

真机逻辑宽度比参考图窄约 15%，首屏只露出第一排健康卡；第二排通过自然滚动可见。这是设备尺寸差异，不是截断或溢出。

## Focused region comparison evidence

重点检查了顶部、AI 主卡、四功能入口、健康标题和底部导航：

- Fonts and typography: 真机使用 Android 中文系统字体，参考图接近 iOS 中文系统字体；字号层级、粗细和可读性一致，真机略粗略大，符合既定适老化要求。未发现截断或不可读文字。
- Spacing and layout rhythm: 横向边距、圆角、卡片分区和区块顺序一致；较窄真机上的纵向密度更高，但 1.5×/2× 系统字体回归无 RenderFlex 溢出。
- Colors and visual tokens: 主红、暖白、金色描边、绿色状态和蓝色趋势色与参考方向一致；品牌红与成功/预警语义色保持分离。
- Image quality and asset fidelity: 首页使用真实赛电 Logo；AI 医生为项目专用生成位图，裁切清晰，无占位图、字符图或代码绘图。
- Copy and content: 问候语、AI 文案、按钮、四入口、健康数据与三栏导航均与参考图一致。日期与账号按真机实时数据显示。

## Findings

- [P3] 参考图与真机使用不同系统字体和逻辑宽度。
  - Evidence: 参考图约 426.5 逻辑像素宽，真机约 364；Android 字体比参考图更粗。
  - Impact: 只影响首屏可见健康卡数量，不影响结构、滚动或操作。
  - Follow-up: 如后续指定统一字体文件或固定目标机型，再做逐像素微调。

- [P3] 四个功能图标使用 Material 图标库中的最近匹配图标。
  - Evidence: 入口含义、颜色和层级一致，但图标造型不是参考图中的定制 3D 图标。
  - Impact: 不影响识别和使用。
  - Follow-up: 客户提供正式图标素材后可直接替换。

## Comparison history

- Iteration 1: 参考图与真机首页完成同图并排检查；未发现可执行的 P0、P1 或 P2 差异，因此无需视觉返工。
- Iteration 2: 根据真机反馈进一步缩小 AI 健康管家、健康数据卡和健康提示，维持适老化字号与点击区域。
- Iteration 3: 2026-08-19 根据“医生只显示一个头”的真机反馈，移除顶部高度裁切，改为 160 dp 固定展示区和居中缩放。初次 1.46 倍裁切已显示白大褂，但头发过于贴近卡片顶部（P2）；随后调整为 1.34 倍，完整显示头发、脸部、肩部和胸前白大褂。
- Post-fix evidence: `E:\saydian\tmp\design-qa-ai-card-0819\comparison-top-sections.png` 和 `E:\saydian\tmp\design-qa-ai-card-0819\comparison-ai-card.png`。最终真机截图为 `E:\saydian\tmp\design-qa-ai-card-0819\implementation-home-final.png`。

### AI 医生比例复验参数

- 当前参考图: `C:\Users\admin\AppData\Local\Temp\codex-clipboard-ae4b724a-fc19-42cc-ac1f-d32a97129fef.png`，860 × 899 px。
- 最终真机截图: 1228 × 2700 px，540 dpi；逻辑视口约 364 × 800 dp。
- 聚焦参考裁切: `(25, 241)–(844, 625)`。
- 聚焦实现裁切: `(54, 432)–(1174, 974)`。
- 参考裁切以 aspect-fill 归一化到实现裁切的 1120 × 542 px 后，同图并排检查。
- 结论: 医生占卡片左侧约三分之一，底部与卡片对齐，头部到胸前白大褂完整可见；不再是头像式裁切。当前红色边框和较大 Android 字体属于既有主题与适老化要求，不属于本次比例问题。

## Primary interactions checked

- AI 健康管家“马上提问”。
- 远程关爱、健康百科、健康预警、赛电商城。
- 全部数据二级页和运动入口。
- 健康、设备、我的三栏导航。
- 设备搜索页商城入口、我的页添加设备/AI 提问、退出登录。
- Release 启动日志未发现 Flutter 运行时异常。

## Implementation checklist

- [x] 首页视觉层级与参考图一致。
- [x] 旧健康页保留为全部数据二级页。
- [x] AI 和运动管家不再占用底部导航。
- [x] 三栏导航和适老化字体无溢出。
- [x] 真机截图与参考图完成同图比较。
- [x] AI 医生按参考图显示完整头肩和胸前白大褂。

## Iteration 4 - AI card edge and background continuity

- Trigger: the character still appeared too far left, both left rounded corners were incomplete, and the character-side background visibly split from the text-side background.
- Fix: moved the character 18 dp to the right, replaced the split gradient with one uniform warm background (`#FDF7F3`), and painted the rounded border in the foreground so the image can never cover the two left corners.
- True-device screenshot: `E:\saydian\tmp\design-qa-ai-card-0819\implementation-home-020-final.png`.
- Focused side-by-side comparison: `E:\saydian\tmp\design-qa-ai-card-0819\comparison-ai-card-020.png`.
- Full top-section comparison: `E:\saydian\tmp\design-qa-ai-card-0819\comparison-top-sections-020.png`.
- Result: all four rounded corners are continuous; the character has clear left breathing room and remains separated from the text; no vertical color seam remains. No actionable P0, P1, or P2 visual mismatch was found.

final result: passed

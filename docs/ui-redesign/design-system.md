# Hermes 设计系统规范 v2.0

> 本文档由代码注释反向整理，规范以 `lib/theme/hermes_tokens.dart` 为准。
> token 唯一来源：`lib/theme/hermes_tokens.dart`；主题构建：`lib/theme/hermes_theme.dart`；
> 组件实现：`lib/widgets/h/`。

## §1 概述与原则

### Liquid Glass 可选风格（实现中）

Classic 与 Liquid 是独立于四套配色和明暗模式的视觉维度；不可通过
全局修改历史 `HermesGlassCard` 将内容卡片变成模糊背景。

- 材质只应用于导航、输入外壳、操作组与弹层；消息、代码、Diff、终端
  保持稳定实色阅读表面，禁止逐消息添加 BackdropFilter。
- GlassSurface 管理裁剪和背景采样；嵌套玻璃复用上层材质，通常仅裁剪，
  不重复模糊、着色、高光和阴影；子层要求不透明降级时单独提供实色表面。
- GlassActionGroup 的按钮共享材质；GlassButton 实际点击区域至少 44×44，
  使用标准键盘焦点、语义和禁用反馈。
- 应用减少透明度、应用／系统高对比均切换为不透明材质。iOS 原生
  AppDelegate 与 AppearanceStore 已接入系统减少透明度查询、变更通知和
  回到前台刷新；真机验收仍待完成。Web 不使用该原生桥接，不得将原生
  接入宣称为 Safari 自动跟随系统减少透明度。
- 减少动画时控件状态转换取消时间动画；不以动画延迟流式文字呈现。
- `HermesGlassMotion` 集中定义 Liquid 按压反馈 120ms、展开 240ms 与
  easeOutCubic 曲线；发送按钮与共享 GlassButton 使用相同按压规则，
  Classic 发送按钮保留原 100ms 线性行为。不同动效类别不强制同一时长。
- ScrollEdgeScrim 不接收指针事件、不增加模糊，保护滚动边缘的可读性。
- Liquid 的共享模糊、透明度、高光、阴影与反馈时长集中在
  `HermesGlassTokens`；深色及不透明降级不投影，以边框区分层级。
  Classic 的既有 token 保持不变。
- `HermesGlassRole` 将导航、输入／浮动控件、菜单／弹层分为 navigation、
  control、overlay，由 `HermesGlassRecipe` 解析默认轮廓与材质。显式 radius
  可覆盖轮廓以支持平直顶栏；角色优先于兼容用的 thick。首轮迁移保留
  原有厚材质浓度和模糊，overlay 默认使用 sheetRadius；尚未完成按角色
  光学校准，不得将三个配置入口描述为三种已验收的光学效果。
- 性能验收记录代表设备的滚动、流式输出和弹层帧耗时，以 60Hz 约
  16.7ms 帧预算为目标；widget 测试通过不等于性能验收通过。

实现范围与剩余验收项见 `liquid-implementation.md`。

- **Token 唯一来源**：全部视觉值（色彩/字体/间距/圆角/阴影）以 token 定义于
  `lib/theme/hermes_tokens.dart`，页面禁止硬编码。
- **禁止硬编码颜色**：文本/边框/背景不要写 `Colors.white/black`，也不要直接引用
  `HermesText`/`HermesBackground` 常量（它们仅是默认主题 Graphite 的快照，保留仅为
  兼容旧调用点）。一律使用 `HermesPalette.of(context)` 或 `ColorScheme.onSurface` 系，
  保证「四主题 × 明暗 × 高对比」全部成立（`hermes_theme.dart` 文件头约定）。
- **深色模式分层用边框而非阴影**：浅色主题用柔和扩散阴影；深色主题不使用投影
  （`hermesShadow()` 返回空列表），层级用 1px 边框表达。
- **主题感知**：`HermesPalette` 作为 `ThemeExtension` 注册进 `ThemeData`，组件经
  `HermesPalette.of(context)` 读取当前主题真实色板；lerp 实现支持主题切换交叉淡化。
- **产品行为默认值**（`HermesPolicy`）：网络超时、轮询间隔、分页大小等也集中在 token
  文件中；安全上限仍由服务端持有。

## §2 品牌视觉

品牌视觉重塑后的品牌色定义于 `HermesBrand`：

- `signalBlue` `#2F6BFF` —— 品牌主色 Signal Blue（Graphite 浅色 accent 派生）。
- `signalBlueDark` `#6E97FF` —— 深色底上的品牌主色。

第三方服务品牌色集中在 `HermesProviderBrand`（AWS/GCP/Azure/OpenAI/Anthropic/GitHub/
Jira/Slack/Telegram/Discord/WhatsApp/WeChat/iMessage/Signal/飞书/钉钉等），供凭据与
消息渠道 UI 共用，不属于主题色板、不随主题切换。

## §3 色彩系统

四套精选主题（`HermesAccents`）：graphite / indigo / moss / dune，每套携带明/暗两套
完整 `HermesPalette`。`HermesAccent.light/dark/lightHover/darkHover` 仅为兼容旧调用点
保留的便捷访问器，真实色值即调色板内字段。

### §3.1 调色板与 token 映射

`HermesPalette` 是「一套主题 × 一种亮度」的完整色板，共 16 个字段。与旧 WebUI CSS
变量的对应关系：

| CSS 变量 | Dart token |
| --- | --- |
| `--bg` / `--surface` / `--elevated` | `HermesPalette.bg / surface / elevated` |
| `--border` / `--border-strong` | `HermesPalette.border / borderStrong` |
| `--text` … `--text-4` | `HermesPalette.text / text2 / text3 / text4` |
| `--accent` 四态 | `HermesPalette.accent / accentHover / accentBg / accentStrong` |
| `--code-bg` | `HermesPalette.codeBg` |
| `--bubble-user` | `HermesPalette.bubbleUser / bubbleUserText` |
| `--success` … `--purple` | `HermesSemantic`（浅色值）+ `HermesSemanticDark` |
| 主题集合 | `HermesAccents`（4 套：graphite/indigo/moss/dune） |
| `--radius-sm` … `full` | `HermesRadius` |
| `--shadow-sm/md/lg` | `hermesShadow()`（dark 不使用投影，用边框分层） |

`HermesPalette.of(context)` 未注册扩展时回退 Graphite（按当前亮度取明/暗）。

### §3.2 Graphite 石墨（默认）

中性灰 + 信号蓝。中性色整体带冷蓝灰倾向（bg/surface/border/text/codeBg 同一走向），
呈现刻意的「冷炭」质感，是四套中最克制的一套。浅色 accent `#2F6BFF`，深色 accent
`#6E97FF`。完整 16 字段色值见 `HermesAccents.graphite`。

### §3.3 Indigo 靛蓝

紫调中性色 + 靛蓝 accent。浅色 accent `#5B54E6`，深色 accent `#9B94FF`。完整色值见
`HermesAccents.indigo`。

### §3.4 Moss 苔绿

绿调中性色 + 苔绿 accent。浅色 accent `#2E7D52`，深色 accent `#5FA87F`。完整色值见
`HermesAccents.moss`。

### §3.5 Dune 暖沙

WebUI 奶油金皮肤的正式继任者：暖调中性色 + 烧橙 accent。浅色 accent `#C05621`，
深色 accent `#E8935A`。完整色值见 `HermesAccents.dune`。

### §3.6 语义色（四主题共享）

`HermesSemantic`（浅色值）/ `HermesSemanticDark`（深色值），用
`hermesSemantic(context, light, dark)` 按当前亮度解析：

| 语义 | 浅色 | 深色 |
| --- | --- | --- |
| success（green） | `#1F9254` | `#4CC38A` |
| warning（orange） | `#C77700` | `#F5A623` |
| error（red） | `#D64545` | `#F26D6D` |
| info（blue） | `#2B6CB0` | `#63A6E8` |
| neutral（gray） | `#64748B` | `#94A3B8` |
| purple | `#7C3AED` | `#A78BFA` |

语义色做底色时统一用 10%（light）/ 18%（dark）透明度叠加（状态 chip、计划卡高亮、
命令面板选中态等）。Agent 状态语义映射：等待审批并入 `--warning`（orange）；idle/
stopped→gray，thinking/planning/running/completed→green，waiting/paused/approval→
orange，failed→red（`HermesAgentStatus.color`）。工具状态映射见 `HermesToolStatus.color`。

### §3.7 高对比模式

`buildHermesTheme(highContrast: true)`：

- 一级文字拉满纯黑（浅色）/ 纯白（深色），二级文字 `#1F232B` / `#EFF2F6`；
- 边框升级为 `borderStrong` 且加粗至 1.5px；
- accent 不变；
- 高对比开关经 `HermesA11y` ThemeExtension 下发（`HermesA11y.highContrastOf`），
  组件层据此调整：浅透明度语义底（§3.6 的 10%/18% 等）经 `hermesTintAlpha()`
  ×1.8（封顶 0.6）；纯色块上的文字（如 `HermesBadge`）用
  `hermesContrastForeground()` 取黑/白中对比度更高者；骨架屏呼吸块底色透明度
  同步提升、边框升级 borderStrong 1.5px；`HermesProgressBar` 轨道底色升级
  borderStrong。浅色模式投影保留（边框已承担层级，投影仅作深度修饰）。

外观偏好（明暗模式 / 主题配色 / 高对比）由 `AppearanceStore` 持久化（见 §8）。

## §4 排版

### §4.1 字体栈

`HermesFonts` 三条栈：

- `--font-ui`（`HermesFonts.ui`）：Segoe UI, Inter, PingFang SC, Hiragino Sans GB,
  Microsoft YaHei, Noto Sans CJK SC, sans-serif。
- `--font-conv`（`HermesFonts.conversation`）：会话消息流专用，继承 `--font-ui`。
- `--font-mono`（`HermesFonts.mono`）：Consolas, JetBrains Mono, Fira Code,
  Cascadia Code, DejaVu Sans Mono, Liberation Mono, SF Mono, Menlo, monospace。

### §4.2 字阶

Liquid 手机分组列表使用 `HermesLiquidTypography` 的独立阅读档位：
视口小于 600 时标题 17 / 行高 1.3，辅助说明 14 / 行高 1.4，标题允许
自然换行。Classic 与 600 及以上视口保留原有列表密度；这不是全局正文
字号迁移。大字缩放继续交由 TextScaler，不能通过固定行高裁掉内容。
共享 HermesListRow 的说明仍保留普通字号最多两行、大字完整换行策略。


`HermesType` 裸 `TextStyle` **只含字号/字重/行高——不含颜色**。优先用
`Theme.of(context).textTheme.xxx`（主题已注入 onSurface 色）；直接用裸 token 必须
`.copyWith(color: ...)`。

| 档位 | 字号 / 字重 / 行高 |
| --- | --- |
| `display` | 32 / w700 / 1.25（字距 -0.5） |
| `largeTitle` | 24 / w700 / 1.3 |
| `title` | 18 / w600 / 1.35 |
| `headline` | 16 / w600 / 1.4 |
| `body` | 15 / regular / 1.6 |
| `callout` | 14 / regular / 1.55 |
| `subheadline` | 13 / w500 / 1.45 |
| `footnote` | 12 / regular / 1.4 |
| `caption` | 11 / w500 / 1.35 |
| `messageBody` | 14 / 1.75，对话字体栈（消息正文） |
| `code` | 13 / 1.6，`--font-mono` 栈 |

代码块/行内代码基于 `HermesType.code` `copyWith` 改字号，不要写 `'monospace'`
字面量。便捷方法：`HermesType.onSurface(base, theme)` /
`HermesType.onSurfaceVariant(base, theme)`。

## §5 间距、圆角、阴影与动效

### §5.1 间距（8 基准栅格）

`HermesSpacing`：`xxs 4 / xs 8 / sm 12 / md 16 / lg 20 / xl 24 / xxl 32 / xxxl 40 /
xxxxl 48`。

### §5.2 圆角

`HermesRadius`：

| token | 值 | 用途 |
| --- | --- | --- |
| `smallCard`（r-sm） | 6 | 小卡片、骨架块、Kbd |
| `card` | 15 | 移动端卡片/分组圆角 |
| `largeCard` | 15 | 移动端独立大表面 |
| `sheet`（r-sheet） | 20 | 底部弹层顶角、Hero 卡 |
| `dialog`（r-xl） | 16 | Dialog / 弹出菜单 / 下拉弹层 |
| `bubble`（r-bubble） | 14 | 消息气泡（用户气泡右下 4px 小角） |
| `composerCard`（r-xl） | 16 | Composer 容器/大卡片 |
| `composer` | 24 | 旧输入 pill，保留兼容 |
| `capsule`（r-pill） | 999 | 胶囊 |

`DropdownButtonFormField` 的弹层没有 ThemeData 挂钩，调用点需显式使用
`hermesDropdownColor(context)`（elevated 底）与 `hermesDropdownBorderRadius`（r-xl），
与其余弹出表面保持一致。

### §5.3 阴影

`hermesShadow(context, tier)` 三档（`HermesShadowTier.sm/md/lg`），均为
`rgba(16,20,26,…)` 的柔和扩散阴影：

- `sm`：alpha .06，blur 2，offset (0,1)；
- `md`：alpha .08，blur 12，offset (0,4)；
- `lg`：alpha .12，blur 32，offset (0,12)。

**深色主题不使用投影**（返回空列表），层级用 1px 边框表达。

### §5.4 动效

`HermesMotion`：`instant 100ms / fast 120ms / standard 180ms / deliberate 220ms /
toast 2400ms`（toast 为自动消失时长）。

- **组件显隐**：160–200ms（如 toast 进场 200ms，缓动 `Cubic(0.2, 0, 0, 1)`）。
- **Ghost hover**：叠 6% 黑（浅色）/ 白（深色）底。
- **流式输出**：正文末尾光标（8×16 竖条，r 1.5）以 530ms 周期淡入淡出闪烁；流式
  结束随 pending 复位消失。
- 呼吸类动效（状态点、骨架块、计划卡进行中步骤）统一 1200ms 周期。
- 系统「减弱动态效果」开启时全部静态呈现，见 §9。

## §6 组件规范

### §6.1 按钮与图标按钮

- **Icon Button**（`HermesIconButton`）：34×34 触控目标，无底无边，r-sm，icon 18px
  text-3 色；hover 6% 黑/白底；disabled 38% 透明度。
- **按压反馈**：pressed 缩放 0.97；禁用态 35% 透明度（Composer 发送按钮等）。
- WebUI 对齐的 AppBar 图标按钮：34×34 触控目标、16px muted 图标 0.75 透明度。

### §6.2 输入框

`InputDecorationTheme`：填充 `codeBg` 底，r-md（实现取 12），1px border；聚焦时
border 变为 accent 1.5px，光晕由 `focusColor` 承担；错误态 border 用 error 色。

### §6.3 卡片与 Hero 卡

- **基础卡片**（`hermesCardDecoration` / `HermesGlassCard`）：surface 底 + 1px border +
  shadow-sm（dark 仅 border）。`tint` 覆盖底色；`strong` 使用 `--border-strong`。
  全部颜色读当前主题调色板，随主题切换。旧的半透明毛玻璃外观已移除（ADR 0004）。
- **Hero 卡**（`HermesHeroCard`）：accent 渐变底（`accentBg → surface`，左上→右下），
  普通文字色，r-sheet 20，shadow-md；右上角装饰圆。用于首页 active-agent hero 与
  Insights 头条指标。

### §6.4 状态 Chip

`HermesStatusChip` / `HermesAgentStatusView` / `HermesToolStatusView`：pill 高 24、
r-pill、文字 11px 字重 600；语义色文字 + 语义色 10%（light）/ 18%（dark）透明度底；
左侧 6px 圆点；运行中加 1200ms 呼吸动效（减弱动态效果时静态圆点）。

### §6.5 消息气泡

- **用户气泡**：`bubbleUser` 实底 + `bubbleUserText` 字，r-bubble 14 且**右下 4px
  小角**；最大宽 78%（手机）/ 720px（桌面，宽度 ≥840）；气泡间距 20。编辑态布局与
  用户气泡一致。
- **Assistant 气泡**：surface 底 + 1px border + shadow-sm，r-bubble 14 且**左下 5px
  小角**；最大宽 90%（窄屏 <600）/ 720px（宽屏）；宽屏时左侧留 40px 头像槽位，
  角色头（`_RoleHeader`，Hermes 翼标头像 + 连接名，`msg-role`）置于气泡外上方。
- **消息内代码块**：`codeBg` 底 + r-sm + mono 13px。
- 行内操作 footer（复制 / 复制为 Markdown / 重新生成）为桌面平权行为。

### §6.6 Composer

- 容器：r-xl 16、surface 底 + 1px border；聚焦时 border = accent + shadow-md。
- 模型/会话等选择器 pill：高 28、文字 12px、r-pill。
- 交互细节沿用 §6.1（pressed 缩放 0.97、disabled 35% 透明度）与 §5.4（ghost hover）。

### §6.7 工具卡

`HermesToolCard`：折叠态高 40 的标题行（图标 + 名称 + 状态 + 复制 + 展开/折叠）；
折叠时一行关键参数摘要；展开后结构化参数（键值对）+ 格式化结果；超长内容进全量
详情弹层。转录流中所有工具卡默认折叠（含运行中），运行状态由标题行的 spinner/状态
chip 表达。

### §6.8 计划卡

`HermesPlanCard`：步骤状态图标 —— ✓ success / ● accent 呼吸（1200ms，减弱动态效果
时静态）/ ○ text-4 / ✕ error；进行中步骤行用 `accentBg` 底高亮。移动端保持平铺，
点击步骤不再展开，长按复制整份清单。

### §6.9 页面状态（空态 / 错误态 / 加载态）与状态反馈

统一的空/错/加载组件（`hermes_states.dart`）：

- **空态**（`HermesEmptyState`）：64px 线性图标 text-4 + title 标题 + callout 描述 +
  可选 Primary 按钮，垂直居中。图标尺寸/颜色可经 `iconSize`/`iconColor` 覆写，
  自定义行动区（如 starter prompt chips）经 `actions` 参数追加在内置按钮之后。
- **错误态**（`HermesErrorState`）：error 图标 + 标题 + 描述 + 重试（Secondary）+
  可选替代操作。
- **加载态**（`HermesLoadingState`）：骨架屏优先于 spinner —— surface 底上叠加 6%
  呼吸块（浅色叠黑 6%，深色叠白 6%）；确定性进度走 3px accent 细条
  （`HermesProgressBar`，见 §6.15）。

页面状态机：`HermesViewState`（initializing/loading/ready/empty/processing/error/
offline/disabled/success）是每个页面数据加载生命周期映射到的单一枚举，经
`HermesStateView` 统一渲染，使所有页面共享同一套状态外观。全局 UI 状态枚举另有
`HermesUiState`（initial/loading/loaded/empty/processing/success/error/offline/
disabled）。

错误归类：`hermesErrorMessage()` 把异常文本归并为三类用户可读文案 —— 含 401/403 →
认证失败；含 SocketException/WebSocket/Timeout → 网络失败；其余 → 操作失败（可传
fallback）。`showHermesErrorSnackBar()` 附带错误触觉反馈与可选重试。

### §6.10 Toast

`HermesToast`：elevated 底 + 语义色左竖条 3px + callout 文案，r-md；位置为底部居中
（手机）/ 右下（桌面，宽度 ≥840）；2400ms 自动消失；显隐动效按 §5.4（160–200ms）。
类型：success / error / info，各配语义色图标与触觉反馈。

### §6.11 侧边导航

XL 档侧边导航：可折叠 64↔240 宽，激活条目 `accentBg` 底 + 左 3px accent 竖条；
底部固定设置入口与连接状态。

### §6.12 Popover

弹出层统一 elevated 底 + shadow-md：命令面板桌面档叠黑 54% 遮罩、顶部居中、最大宽
640、圆角取 largeCard 15；菜单/下拉弹层为 r-xl 圆角 + 1px border。Flutter 默认的
tonal surface 与卡片/对话框色板不一致且圆角偏小，`hermes_theme.dart` 已统一
`popupMenuTheme` / `dropdownMenuTheme` / `menuTheme`；`DropdownButtonFormField`
需调用点显式接入（见 §5.2）。

### §6.15 小组件

- **进度条**（`HermesProgressBar`）：确定性进度，3px accent 轨道、border 色底、
  r-pill；不定进度用 `HermesLoadingState` / `HermesLoadingPill`。
- **数字角标**（`HermesBadge`）：min 16px 圆/胶囊，error 底白字 11px；count > 99
  显示 `99+`；`dot` 模式渲染 8px 纯色圆点（无数字）。
- **快捷键标签**（`HermesKbd`）：mono 11px + surface 底 + border 边框 + r-sm。
- **Tooltip**：r-sm、elevated 底。

## §7 布局与断点

### §7.1 断点与内容宽度

`HermesBreakpoints`：`compact 430 / phone 600 / navigation 840 / tablet 960 /
desktop 1200`。导航断点 840：在有足够空间放 rail 且不挤压主内容前，保持手机式导航
与紧凑 AppBar；600–959 为 medium 窗口档，仅使用 rail 或双栏布局。

`HermesLayout` 共享内容宽度：`contentNarrow 720 / content 760 / contentWide 960 /
workspace 1120 / workspaceWide 1200 / dialog 520 / preview 640`。

### §7.2 窗口分档与 XL 三栏工作台

`hermesWindowClass(width)`：<600 compact，600–959 medium，≥960 expanded。

- **XL 档**（宽度 ≥1200）：类 IDE 三栏工作台 —— 顶栏 + 可折叠侧边导航（§6.11）+
  主区 + 底部状态栏，叠加命令面板；侧边导航的折叠状态持久化（键
  `hm_xl_nav_expanded`）。
- **Tablet 档**（840–1199）：NavigationRail + 主区 + 可选 ContextRail。
- 聊天三栏（会话 rail + 对话 + 上下文 rail）仅当对话区保有可用宽度时启用：
  `hermesCanUseThreePaneChat()` 要求宽度 ≥960 且扣除 220 会话栏 + 280 上下文栏后
  剩余 ≥480。

## §8 主题迁移与例外

外观偏好（明暗模式 / 主题配色 / 高对比 / 触觉反馈 / 屏幕常亮）由 `AppearanceStore`
持久化；4 套精选主题各含明/暗变体，存储的是 themeId。

### §8.1 例外清单（刻意隔离）

以下领域**刻意不使用**本设计系统的 token，属于受控例外：

- **终端配色**（`HermesTerminalVisuals`，`lib/widgets/terminal/terminal_visuals.dart`）：
  独立的明/暗终端调色板（含 high-contrast-dark 预设），与终端行为（PTY、键盘、会话
  生命周期）隔离，使主题切换不影响终端会话。
- **ANSI 色**（`lib/chat/content/ansi_text.dart`）：终端输出的 ANSI 转义颜色按终端
  语义渲染，不映射到语义色 token。
- **代码高亮主题**（`lib/chat/content/code_highlighter.dart`）：使用 highlight.js 语法
  配 Atom One Dark/Light 样式（桌面 Shiki 平权），属于内容渲染层，不随四主题换肤。

### §8.2 旧 accent ID 迁移映射

旧 8 个 accent id 在读取时经 `HermesAccents.byId` 一次性映射到新 themeId：

| 旧 id | 新 themeId |
| --- | --- |
| webui | dune |
| ocean / sky / ink | graphite |
| violet | indigo |
| forest | moss |
| sunset / cream | dune |

未匹配的旧值回落默认主题 Graphite；`HermesAccents.matchId` 用于区分「无匹配」与
「恰好显式匹配到 graphite」。

## §9 动效无障碍（Reduce Motion）

系统「减弱动态效果」开启（`MediaQuery.disableAnimationsOf(context)`）时，所有循环/
呼吸类动效必须静态呈现：状态 chip 圆点、骨架呼吸块、流式光标、计划卡 ● 呼吸图标、
打字点等均退化为静态；结构性动画（如 XL 侧边导航折叠）时长降为 0。新增动效一律
遵循本节约。

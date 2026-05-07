# 阅读控制器优化文档

> 面向：Qread Flutter 阅读器开发
> 范围：只处理控制器层，不改分页/章节/缓存/TTS 引擎本身
> 基线代码：`lib/pages/reader/reader_page.dart`、`lib/pages/reader/reader_state.dart`、`lib/pages/reader/widgets/controller_overlay.dart`

---

## 一、这轮优化的边界

当前阅读器已经不是早期那种“所有逻辑都堆在一个页面里”的状态了。现在的结构大致是：

- `reader_page.dart`：阅读流程编排、章节打开、预取、TTS/自动翻页触发
- `reader_state.dart`：阅读状态、排版结果、预排版缓存、控制器显示状态
- `paged_reader.dart` / `scroll_reader.dart`：正文渲染
- `controller_overlay.dart`：控制器 UI

所以这一轮不要再碰：

- 章节切换逻辑
- 分页引擎
- 段落拆分
- 缓存与预取
- TTS 实际朗读逻辑

只改控制器表现层，以及它和 `reader_page.dart` 之间的数据接口。

---

## 二、当前实现的真实现状

`ControllerOverlay` 已经独立出来了，这是对的，但它现在还是一个“大组件”：

1. 顶部栏只放了返回、书签、更多
2. 书名、章节、来源、刷新、换源都还塞在底部大卡片里
3. 普通模式 / TTS / 自动翻页三套 UI 都写在同一个文件的三个私有方法里
4. 构造参数过多，已经接近“页面级组件”的复杂度
5. 视觉上仍然更像“调试控制面板”，不像轻阅读原版那种轻、薄、悬浮的控制器

这意味着当前问题已经不是“有没有控制器”，而是：

- 层级不对
- 信息摆放不对
- 状态组织还不够干净
- 设计语言还没向轻阅读原版靠齐

---

## 三、当前代码里值得立刻注意的点

### 3.1 `ControllerOverlay` 参数过重

现在 `ControllerOverlay` 直接收一长串字段和回调，后续继续加“更多”、“听书抽屉”、“自动翻页沉浸模式”时会继续失控。

尤其是这几个点已经暴露出收口需求：

- `provider` 被传入 `ControllerOverlay`，但控制器内部并没有真正使用
- `onShowChangeType` 还是旧的 PopupMenu 残留接口
- `onShowBookmarks`、`onSwitchSource`、`onApplyReplaceRules` 已经在向“更多面板”收拢，但还没完成

### 3.2 主题切换和净化规则语义耦合

当前普通控制器里第三个按钮：

- 图标/文案是通过 `useReplaceRule` 判断
- 点击行为却是 `onToggleTheme`

这两个语义不是一回事。

结论：

- “深色/浅色”按钮应只由当前阅读主题决定
- “刷新净化规则”应独立存在，不要拿净化开关去驱动主题图标

### 3.3 控制器层次还没拆开

当前普通控制器本质还是一个底部整块卡片，里面塞了：

- 书籍信息
- 三个主按钮
- 章节滑杆
- 底部入口

这和目标形态差得比较远。目标应该是四层：

1. 顶部信息栏
2. 中间悬浮胶囊
3. 进度条行
4. 底部功能栏

---

## 四、目标形态

这轮的 UI 目标，不是照搬 Legado，而是：

- 吸收 Legado 在阅读控制器上的功能组织
- 贴近轻阅读原版的控制器层次和观感
- 保留 Qread 当前正文区域的简洁感

推荐目标结构：

```text
ControllerOverlay
├── TopInfoBar
├── FloatingCapsule
├── ProgressStrip
└── BottomActionBar
```

对应视觉分工：

### 4.1 `TopInfoBar`

负责展示：

- 返回
- 书名
- 章节名
- 来源名
- 刷新
- 更多

建议：

- 半透明暗底
- 高度控制紧凑，不做卡片
- 三行信息不要再放到底部

### 4.2 `FloatingCapsule`

这是整个控制器的识别点，建议做成白底悬浮胶囊。

普通模式：

- 自动翻页
- 朗读
- 深浅色切换

TTS 模式：

- 停止
- 暂停/继续
- 下一段或下一章

自动翻页模式：

- 减速
- 当前秒数
- 加速
- 停止

注意：模式切换时只换胶囊内部，不换整套底部结构。

### 4.3 `ProgressStrip`

只负责：

- 上一章
- 章节滑杆
- 下一章

这一行单独存在，不和底部功能栏混在一起。

### 4.4 `BottomActionBar`

只保留两个入口：

- 目录
- 设置

书签、换源、净化入口不要再常驻底部。

---

## 五、推荐的状态收口方式

### 5.1 新增胶囊模式枚举

建议在 `reader_state.dart` 增加：

```dart
enum ControllerCapsuleMode { normal, tts, autoPage }
```

再加一个 getter：

```dart
ControllerCapsuleMode get capsuleMode {
  if (autoPageRunning) return ControllerCapsuleMode.autoPage;
  if (ttsReading || ttsParagraphIndex >= 0) {
    return ControllerCapsuleMode.tts;
  }
  return ControllerCapsuleMode.normal;
}
```

作用：

- `ControllerOverlay` 不再自己判断三套状态
- 避免 `ttsReading` / `ttsState` / `autoPageRunning` 多头判断继续扩散

### 5.2 不要继续扩张 Overlay 构造函数

建议增加两个对象：

```dart
class ReaderControllerViewData {
  final String bookName;
  final String chapterTitle;
  final String sourceName;
  final bool hasBookmark;
  final bool replaceRuleEnabled;
  final String themeName;
  final ControllerCapsuleMode capsuleMode;
  final TtsState ttsState;
  final double ttsRate;
  final double autoPageInterval;
  final int chapterIndex;
  final int totalChapters;
  final double? chapterSliderValue;
}

class ReaderControllerCallbacks {
  final VoidCallback onBack;
  final VoidCallback onShowMore;
  final VoidCallback onRefresh;
  final VoidCallback onToggleBookmark;
  final VoidCallback onStartAutoPage;
  final VoidCallback onStartTts;
  final VoidCallback onToggleTheme;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onChapterSliderChanged;
  final ValueChanged<double> onChapterSliderEnd;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowSettings;
  final VoidCallback onStopTts;
  final VoidCallback onPauseTts;
  final VoidCallback onResumeTts;
  final VoidCallback onShowTtsTimer;
  final VoidCallback onShowTtsSettings;
  final VoidCallback onStopAutoPage;
  final VoidCallback onDecreaseAutoPageInterval;
  final VoidCallback onIncreaseAutoPageInterval;
}
```

这样控制器层只关心：

- 我现在该显示什么
- 用户点了哪个入口

而不是继续背着 20 多个松散参数。

---

## 六、更多面板的收纳原则

顶部 `PopupMenuButton` 可以废掉，改成“更多”入口，然后统一弹底部面板。

建议收进去的入口：

- 书签
- 换源
- 净化规则
- 书籍信息（后续可加）
- 分享（后续可加）

不建议常驻主控制器的入口：

- 书签
- 换源
- 各类调试功能

主控制器只放高频动作。

---

## 七、视觉规范建议

这部分是为了“像轻阅读”，不是为了“像一个功能很多的工具面板”。

### 7.1 形态

- 顶部栏：窄、薄、贴边
- 胶囊：白底、强圆角、轻阴影
- 底部栏：不再是大黑卡片
- 控件半径尽量控制在 `8px` 或胶囊类 `40px`

### 7.2 配色

建议不要再在控制器里散落写死颜色，至少补出这几类 token：

- `overlayBackground`
- `overlayText`
- `overlaySubText`
- `accent`
- `divider`

当前 `ReaderTheme` 只有正文主题色，不足以支撑这轮控制器打磨。

建议把控制器所需 token 也纳入 `reader_theme.dart`，否则深浅色主题切换时，控制器颜色会继续写死。

### 7.3 动画

建议只做轻动画：

- 顶部栏：`AnimatedSlide + AnimatedOpacity`
- 底部栏：`AnimatedSlide + AnimatedOpacity`
- 胶囊内容切换：`AnimatedSwitcher`

不要做重动画，不要做浮夸放大缩小。

---

## 八、推荐实施顺序

### 第一步：先拆层，不改功能

在 `controller_overlay.dart` 内部先拆成：

- `_TopInfoBar`
- `_FloatingCapsule`
- `_ProgressStrip`
- `_BottomActionBar`

这一步先不改交互，只调整布局和视觉层级。

### 第二步：移除顶部 PopupMenu 旧逻辑

把：

- `onShowChangeType`

替换成：

- `onShowMore`

并把书签、换源、净化规则等放进更多面板。

### 第三步：收口状态判断

引入 `ControllerCapsuleMode`，让控制器不再自己组合判断：

- 普通模式
- TTS 模式
- 自动翻页模式

### 第四步：替换视觉风格

把当前底部大卡片改成：

- 顶部信息条
- 中部悬浮胶囊
- 底部进度条 + 功能栏

这一步做完，风格上就会很接近目标。

### 第五步：补更多面板和设置抽屉的联动

把高频与低频入口彻底分开：

- 高频留主控制器
- 低频收到底部弹层

---

## 九、验收标准

做到以下几点，说明这轮控制器优化基本合格：

1. 顶部栏能单独展示书名、章节、来源、刷新、更多
2. 中间有独立悬浮胶囊，普通/TTS/自动翻页三种状态只替换胶囊内容
3. 章节进度条独立成行
4. 底部栏只保留目录、设置
5. 书签/换源/净化规则被收进更多面板
6. 深浅色按钮不再依赖 `useReplaceRule`
7. `ControllerOverlay` 不再直接接收无用 `provider`
8. `reader_page.dart` 的阅读业务逻辑不因这轮改造而变复杂

---

## 十、这轮不做的事

以下内容不属于本次控制器优化：

- 阅读引擎重写
- 章节切换机制调整
- 分页算法优化
- 段落拆分修复
- TTS 朗读策略调整
- 净化规则执行逻辑调整

这些是阅读内核问题，不要在控制器改造里混做。

---

## 十一、涉及文件

| 文件 | 作用 |
|------|------|
| `lib/pages/reader/widgets/controller_overlay.dart` | 本轮主战场 |
| `lib/pages/reader/reader_state.dart` | 可新增 `ControllerCapsuleMode` 或相关 getter |
| `lib/pages/reader/reader_page.dart` | 只做接口适配，不改阅读业务 |
| `lib/pages/reader/widgets/reader_theme.dart` | 补控制器所需主题 token |
| `lib/pages/reader/widgets/paged_reader.dart` | 仅用于联调观察，不作为主修改点 |
| `lib/pages/reader/widgets/scroll_reader.dart` | 同上 |

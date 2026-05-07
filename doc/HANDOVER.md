# Qread Handover

## 当前结论

本轮工作已完成阅读器翻页与背景这一阶段的关键修复，当前可以结束这个主题，下一会话转入整个应用的 GUI 风格统一与视觉打磨。

当前 Flutter 仓库：

- `D:\Qread`

本轮新增参考仓库：

- `D:\Qread\_refs\BookPage`
- `D:\Qread\_refs\flutter_novel`
- `D:\Qread\_refs\page_turn_animation`
- `D:\Qread\_refs\page_turn`

## 已完成内容

### 1. 阅读器翻页模式收敛

现在只保留 5 种模式：

- `覆盖`
- `滑动`
- `仿真`
- `滚动`
- `无`

旧模式名已做兼容映射，避免历史配置读崩：

- `book -> simulation`
- `horizontal -> slide`
- `vertical -> scroll`

相关文件：

- `D:\Qread\lib\pages\reader\reader_state.dart`
- `D:\Qread\lib\pages\reader\reader_page.dart`

### 2. 自定义背景修复

之前自定义背景不生效，原因是 `custom_xxx` 主题名保存的是十六进制，但读取时按十进制解析，导致回退。

现已修复：

- 自定义背景可正常生效
- 可正常持久化
- 重进阅读页不会丢

相关文件：

- `D:\Qread\lib\pages\reader\widgets\reader_theme.dart`

### 3. 仿真翻页已重写为几何卷页

最开始的 Flutter 实现只是整块 `Transform`，用户明确不接受。

最终采用的是：

- 参考 `BookPage` 的几何模型
- 参考 `flutter_novel` 的 Flutter 组织方式
- 当前页先截图
- 仿真翻页时基于触摸点与角点计算控制点
- 按 A/B/C 区域绘制
- 背页通过反射矩阵镜像当前页位图
- 目标页作为底层真实内容显示

核心算法已经不是“整块反转”，而是真正卷页。

相关文件：

- `D:\Qread\lib\pages\reader\widgets\paged_reader.dart`

### 4. 四角阴影问题已修复

曾出现的问题：

- 右上角效果正常
- 右下 / 左上 / 左下有明显瑕疵
- B 区阴影过宽，出现一整条多余阴影块
- 阴影方向只对“右上角”成立，其他角错误

已完成修正：

- A 区左右阴影分开处理
- C 区阴影裁剪到 `pathC`
- B 区阴影裁剪到 `areaBPath`
- 阴影方向不再只按 `isTopRight`，而是按四角条件分支
- B 区阴影透明度已降低

当前状态：

- 用户确认“完美，修复了”

### 5. 阅读页底部黄黑 overflow 修复

之前经常报：

- `A RenderFlex overflowed by ... pixels on the bottom`

并在页面底部出现黄黑斜纹提示。

已处理方式：

- 正文区改为可裁剪容器
- 不再直接让正文 `Column` 在固定高度下硬撑

相关文件：

- `D:\Qread\lib\pages\reader\widgets\content_renderer.dart`

## 本轮主要改动文件

- `D:\Qread\lib\pages\reader\reader_state.dart`
- `D:\Qread\lib\pages\reader\reader_page.dart`
- `D:\Qread\lib\pages\reader\widgets\paged_reader.dart`
- `D:\Qread\lib\pages\reader\widgets\reader_theme.dart`
- `D:\Qread\lib\pages\reader\widgets\content_renderer.dart`

## 当前验证状态

已验证：

- `flutter analyze`
  - 没有新增 error
  - 仍有一些旧的 info / warning，主要在 `reader_page.dart`
- `flutter build windows --debug`
  - 代码本身可通过

注意：

- 最后一次 Windows 构建失败不是代码问题，而是 `qread.exe` 正在运行，锁住了 `WebView2Loader.dll`
- 如果下个会话还要构建 Windows，请先关闭正在运行的 `qread`

## 当前阅读器实现说明

### 模式实现现状

- `覆盖`
  - 手势驱动
  - 当前页覆盖滑走

- `滑动`
  - 普通横向分页
  - 走 `PageView`

- `仿真`
  - 手势驱动
  - 当前页截图卷起
  - 背页镜像
  - A/B/C 分区阴影

- `滚动`
  - 整章滚动

- `无`
  - 手势驱动
  - 不做动画，直接切页

### 仿真翻页核心入口

重点看这里：

- `D:\Qread\lib\pages\reader\widgets\paged_reader.dart`

里面最重要的是：

- `PagedReader`
- `_SimulationTurnPainter`
- `_SimulationTurnGeometry`

## 参考实现来源

这轮真正有用的参考不是 Legado 本体，而是：

### 1. BookPage

路径：

- `D:\Qread\_refs\BookPage\src\main\java\com\anlia\pageturn\view\BookPageView.java`

作用：

- 几何数学最清晰
- `calcPointsXY`
- `getIntersectionPoint`
- A/B/C 区路径
- 背页镜像矩阵
- 阴影的旋转中心与裁剪关系

### 2. flutter_novel

路径：

- `D:\Qread\_refs\flutter_novel\lib\app\novel\widget\reader\content\helper\animation\animation_page_simulation_turn.dart`
- `D:\Qread\_refs\flutter_novel\lib\app\novel\widget\reader\content\helper\animation\animation_page_cover.dart`

作用：

- Flutter 里如何组织手势、动画控制器、确认/取消翻页
- 如何把几何卷页嵌进阅读器状态流

## 下个会话目标

下个会话不要再继续做阅读器翻页。这个阶段已经够用了。

下一步主目标：

## GUI 风格统一与视觉打磨

建议重点：

### 1. 统一全局视觉语言

先做一轮审视：

- 书架
- 发现
- 搜索
- 阅读设置
- 个人页
- 书源/RSS 管理页

现在整体问题大概率会是：

- 控件风格不统一
- 边距与层级不统一
- 字号/圆角/分割线风格混杂
- 顶栏、卡片、弹窗、胶囊按钮语言不一致

建议先确定一套全局规则：

- 颜色体系
- 圆角体系
- 间距体系
- 标题/正文/辅助文案字号层级
- 卡片与列表的边框/阴影规则
- 底部弹窗样式

### 2. 阅读器设置面板视觉整理

虽然功能已经可用了，但视觉层还可以继续统一：

- 翻页模式胶囊
- 背景色圆点
- 间距设置入口
- 更多设置入口

这块现在很适合作为 GUI 风格重构的第一块样板。

### 3. 书架与发现页优先级最高

因为这是最常见入口，最能决定产品第一印象。

建议优先看：

- `D:\Qread\lib\pages\bookshelf\bookshelf_page.dart`
- `D:\Qread\lib\pages\discover\discover_page.dart`
- `D:\Qread\lib\widgets\book_card.dart`

### 4. 先提炼，再改页面

建议不要直接一页页硬改。

先抽：

- 统一按钮
- 统一 section 标题
- 统一卡片容器
- 统一底部弹窗样式
- 统一标签/胶囊样式

再把页面换上去，成本最低。

## 不建议下个会话做的事

- 不要继续大改翻页数学
- 不要再引入新的翻页第三方包
- 不要同时推进“GUI 重构”和“书源登录适配”两条大线

建议先把 GUI 做整洁，再开下一轮处理更复杂的功能适配。

## 交接提示

如果新会话要先确认当前成果，建议优先人工验证：

1. 打开阅读页
2. 测试五种翻页模式
3. 检查自定义背景
4. 检查页面底部是否还有黄黑 overflow 条
5. 然后再开始 GUI 统一

如果要重新构建 Windows：

1. 先关闭正在运行的 `qread.exe`
2. 再执行 `flutter build windows --debug`

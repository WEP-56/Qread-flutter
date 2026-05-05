# Qread 项目接手文档

> 供新会话 AI 快速接手当前 Flutter 端状态与下一步开发重点

## 项目目标

基于后端项目 `Qread-source`（Kotlin/Solon）与开源 Web 客户端，开发 **Flutter 客户端**（Windows + Android），尽可能复刻 Legado/Qread 的实际行为。

当前主目标已经从“跑通基本链路”切换为：

1. **书源全量适配**
2. **订阅源全量适配**
3. **阅读器使用打磨**

这里的“全量适配”重点不是静态页面，而是：

- `loginUi`
- `loginUrl`
- 源变量
- 源动作
- 调试页
- WebView 行为
- 一键导入
- 表单式源编辑器

## 当前仓库与参考代码

- Flutter 仓库根目录：`D:\Qread`
- 后端 / Web 参考仓库：`D:\Qread\Qread-source`
- 本地克隆的 Legado 参考源码：`D:\Qread\_refs\legado`

> 后续涉及书源/订阅源编辑、登录、变量、动作、调试时，**优先直接参考 `_refs/legado`**，不要只靠记忆或搜索网页资料。

## 当前状态概览

### 基础链路

以下链路已经基本可用：

- 登录
- 发现
- 搜索
- 加入书架
- 阅读
- 书源管理基本修改

### 已经做完或基本可用的模块

- 书架页
- 发现页
- 搜索页
- 登录 / 注册页
- 我的页
- 阅读器基础页
- 书源管理页（已不再是占位）
- RSS 订阅页
- RSS 管理页（基础版）
- RSS 文章列表 / 详情页（基础版）

### 已完成的重要结构升级

1. **Windows WebView 已补齐**
   - 之前 Windows 没有默认 WebView 实现，`type=1` 订阅源会直接报错。
   - 现在新增了 `webview_windows`，并封装了统一组件：
     - `lib/widgets/adaptive_webview.dart`
   - Windows 用 `webview_windows`
   - 其它平台暂时仍走 `webview_flutter`

2. **书源 / 订阅源结构化编辑器已建立**
   - 不再只依赖 JSON 文本框
   - 已按 Legado 的 tab 结构拆成 Flutter 页
   - 书源编辑：
     - `lib/pages/source/book_source_editor_page.dart`
   - 订阅源编辑：
     - `lib/pages/rss/rss_source_editor_page.dart`
   - 通用 JSON path 读写：
     - `lib/pages/source/source_editor_support.dart`

3. **一键导入链路已接入**
   - 支持拦截：
     - `yuedu://booksource/importonline?src=...`
     - `legado://import/{path}?src=...`
   - 导入逻辑在：
     - `lib/pages/rss/rss_web_page.dart`
     - `lib/widgets/adaptive_webview.dart`

4. **API body 编码问题已修正**
   - 之前很多 `@Body List<String>` / `@Body Object` 接口被错误按表单方式发出
   - 现已统一补 `application/json`
   - 影响范围：
     - 批量书源接口
     - 批量 RSS 接口
     - `getRssSourcejson`
     - `getbookSourcejson`
     - `editRssSources`

## 当前仍未完成的核心问题

### 1. 登录 UI / 登录动作还没真正适配

这是当前最关键的缺口。

很多源的能力不在普通网页 HTML，而在源 JSON 内部定义：

- `loginUi`
- `loginUrl`
- `loginCheckJs`
- `variableComment`
- `shouldOverrideUrlLoading`

目前状态：

- 可以打开网页
- 可以拦截部分一键导入协议
- **不能完整渲染 Legado 风格的 `loginUi` 按钮 / 输入表单 / 动作执行**

例如：

- 切换起始页
- 登录
- 清理 cookie
- 源变量编辑
- 源动作执行

这些都还是待做。

### 2. 调试页还没做

Legado 原版有非常重要的调试页：

- 调试搜索
- 调试发现
- 调试详情
- 调试目录
- 调试正文

这对书源适配是核心工具，Flutter 端目前还没有。

### 3. 结构化编辑器还是第一版

目前编辑器已经有 tab + 表单，但还是“基础字段表单化”，还没到 Legado 原版成熟度。

目前缺：

- 更多 checkbox / dropdown / 特殊控件
- 字段级帮助
- 登录入口
- 变量入口
- 调试入口
- 粘贴 / QR / 分享 / 导入辅助
- URL 选项插入器

### 4. 阅读器仍需继续打磨

已修复一个明显错误：

- 漫画类型应是 `type == 2`

但仍缺：

- 书签
- 阅读设置完整化
- HTML / 漫画 / 有声的进一步细分
- 源变量 / WebView 内容对阅读器的联动

## 本会话新增 / 修改的重点文件

### 新增

- `lib/widgets/adaptive_webview.dart`
- `lib/pages/source/source_editor_support.dart`
- `lib/pages/source/book_source_editor_page.dart`
- `lib/pages/rss/rss_source_editor_page.dart`
- `lib/pages/rss/rss_web_page.dart`
- `lib/pages/rss/rss_article_list_page.dart`
- `lib/pages/rss/rss_article_detail_page.dart`
- `lib/providers/rss_manage_provider.dart`
- `D:\Qread\_refs\legado`（本地参考仓库）

### 关键修改

- `lib/services/api_service.dart`
- `lib/pages/source/source_manage_page.dart`
- `lib/pages/rss/rss_source_page.dart`
- `lib/config/routes.dart`
- `lib/main.dart`
- `lib/pages/reader/reader_page.dart`
- `lib/widgets/rss_source_card.dart`
- `lib/providers/source_manage_provider.dart`

## 当前 Provider / 页面状态

### Provider

- `UserProvider`
- `BookshelfProvider`
- `DiscoverProvider`
- `ReaderProvider`
- `RssProvider`
- `SourceManageProvider`
- `RssManageProvider`

### 页面

- `BookshelfPage`
- `DiscoverPage`
- `ExploreBooksPage`
- `SearchPage`
- `ReaderPage`
- `ProfilePage`
- `RssPage`
- `RssArticleListPage`
- `RssArticleDetailPage`
- `RssSourcePage`
- `SourceManagePage`
- `BookSourceEditorPage`
- `RssSourceEditorPage`

## 与 Legado 对照时的关键入口

### 登录 UI

- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\login\SourceLoginActivity.kt`
- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\login\SourceLoginViewModel.kt`

### 书源编辑

- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\book\source\edit\BookSourceEditActivity.kt`

### 订阅源编辑

- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\rss\source\edit\RssSourceEditActivity.kt`

### 书源管理

- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\book\source\manage`

### RSS 管理

- `D:\Qread\_refs\legado\app\src\main\java\io\legado\app\ui\rss\source\manage`

## API 关键注意点

### 通用

- API 基础路径：`/api/{v}`，当前 `v=5`
- 认证方式：`accessToken` **查询参数**
- 不是 Bearer token

### 分页缓存接口

- `getXxxPage` 先写缓存并返回 `md5 + page`
- `getXxxNew` 再读缓存
- 缓存 TTL 约 60 秒
- 过期时 `New` 接口可能返回空 / false，需要 fallback

### 书源 / RSS 旧接口 fallback

- `getBookSources` 返回 `errorMsg` 带权限语义：
  - `"ok"` = 可编辑
  - `"no"` = 只读
- `getRssSourcess` 返回：
  - `data.sources`
  - `data.can`

### Body 编码

这类接口必须特别注意：

- `saveBookSources`：body 是 **纯文本 JSON**
- `saveBookSource`：body 是 **纯文本 JSON**
- `saveRssSources`：`source` / `urls` 是 query/form 参数
- 很多批量接口：body 是 **JSON 数组**

如果又看到：

- 后端返回空数组
- 后端 `400`
- 明明接口通了但数据为空

优先检查 `content-type` 和 body 序列化方式。

## 当前依赖

```yaml
provider: ^6.0.3
dio: ^4.0.6
shared_preferences: ^2.0.15
cached_network_image: ^3.2.1
pull_to_refresh: ^2.0.0
flutter_html: ^3.0.0-alpha.3
webview_flutter: ^3.0.4
webview_windows: ^0.4.0
url_launcher: ^6.1.3
path_provider: ^2.0.11
sqflite: ^2.0.2+1
json_annotation: ^4.5.0
```

## 当前已知问题 / 风险

1. **源码中文文案仍有部分历史乱码**
   - 不是终端显示问题，而是部分源码字符串本身已经坏了
   - 新增页面尽量保持正常中文，旧页面后续逐步清理

2. **Windows WebView 切换行为仍需继续测试**
   - 当前已把 popup policy 改成 `sameWindow`
   - 能解决一部分“点击二级页没反应”
   - 但更复杂的站点跳转仍需继续观察

3. **结构化编辑页还只是第一版**
   - 已可编辑主要字段
   - 但距离 Legado 原版还差很多增强行为

4. **`loginUi` / `loginUrl` 才是全量适配主战场**
   - 这部分还没真正开工完成

## 下个会话建议顺序

### 第一优先级

1. **适配 `loginUi`**
   - 按 Legado 的 RowUi 结构渲染按钮 / 输入项
   - 支持点击动作
   - 支持保存登录信息

2. **适配 `loginUrl` / 动作执行**
   - 书源
   - 订阅源
   - 源变量
   - 清理 cookie / cache

3. **做调试页**
   - 调试搜索
   - 调试发现
   - 调试详情
   - 调试目录
   - 调试正文

### 第二优先级

4. **继续增强结构化编辑器**
   - menu
   - 登录入口
   - 变量入口
   - 调试入口
   - 导入 / 导出 / 粘贴辅助

5. **阅读器继续打磨**
   - 书签
   - 设置
   - 内容模式细化

## 验证基线

截至本次交接：

- `flutter analyze` 无新增 error（仍有一些历史 warning/info）
- `flutter test` 通过

如果下个会话引入了新的 Windows 插件或 WebView 行为，记得：

- 不要只靠热重载验证
- 需要完整重启 Windows 端应用

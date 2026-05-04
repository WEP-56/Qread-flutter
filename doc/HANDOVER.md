# Qread 项目接手文档

> 供新会话 AI 快速理解项目状态和开发上下文

## 项目目标

基于后端项目 `/workspace/read`（Kotlin/Solon），开发 **Flutter 客户端**（仅 Windows + Android），复刻其 Web 端阅读器的全部功能。**不修改后端**，仅做前端客户端。

## 仓库

- GitHub: https://github.com/WEP-56/Qread-flutter
- 本地路径: `/workspace/Qread`
- 后端源码: `/workspace/read`

## 当前进度

### 已完成

1. **项目初始化** — Flutter 项目已创建，已 push 到 GitHub main 分支
2. **目录结构搭建** — config/models/services/providers/pages/widgets
3. **数据模型** — Book/BookSource/RssSource/RssArticle/BookGroup/ReplaceRule/SearchResult/Chapter（含 .g.dart）
4. **API 服务层** — `lib/services/api_service.dart`，Dio 单例，完整覆盖后端所有 API：
   - 用户: login/register/getUserInfo
   - 书架: getBookshelfPage/getBookshelfNew/saveBookProgress/getBookread/addreadchapter/deleteBooks/deleteBook
   - 书籍: getBookInfo/getChapterList/getChapterListNew/getBookContent/getBookContentNew
   - 搜索: searchBook（支持多书源 bookSourceUrl 参数）
   - 发现: exploreBook/getBookSourcesExploreUrl
   - 书源: getBookSourcesPage/getBookSourcesNew/saveBookSources/deleteBookSources
   - RSS: getRssSourcesPage/getRssSourcesNew/getRssArticles/saveRssSources/deleteRssSources
   - 分组: getgroup/getgroupNew/addgroup/delgroup/editgroup/ordergroup/setgroup/setgroups
   - 替换规则: getReplaceRules/saveReplaceRule/deleteReplaceRule
   - 书籍操作: saveBook/refreshBook/changeBookType
   - 封面代理: proxypng
5. **本地存储** — `lib/services/storage_service.dart`，SharedPreferences 存储 token/baseUrl/themeMode
6. **状态管理** — Provider: UserProvider/BookshelfProvider/DiscoverProvider/RssProvider/**ReaderProvider**
7. **页面实现**:
   - ✅ 书架页（GridView 3列 + 下拉刷新 + **分组筛选 TabBar** + **分组 CRUD**）
   - ✅ 发现页（ExpansionTile 按分组展示书源 + 分类底部弹窗）
   - ✅ RSS订阅页（分组网格展示 + 源卡片）
   - ✅ 我的页（用户信息/设置入口/服务器地址配置/关于）
   - ✅ 登录/注册页（切换模式 + 密码可见性）
   - ✅ 搜索页（**多书源并行搜索** + 去重 + 加入书架）
   - ✅ **阅读器页**（章节列表 + 内容展示 + 进度保存 + 翻页 + 字号/行距调节 + 目录弹窗）
   - ⬜ 书源管理页（占位，开发中）
   - ⬜ RSS源管理页（占位，开发中）
8. **组件** — BookCard（支持长按菜单：继续阅读/更新/修改类型/设置分组/移出书架）/RssSourceCard/LoadingWidget
9. **主题** — 明暗模式切换（teal 主色 #009688）
10. **API 文档** — `doc/API.md`，157 个端点完整记录
11. **功能清单** — `doc/FEATURE_TODO.md`，按 5 大页面详细列出功能+API+样式参考

### P0 已完成详情

**1. 阅读器（ReaderPage）**:
- 接收 Book 参数，自动加载章节列表（getChapterListNew）
- 章节内容展示（getBookContentNew），支持替换规则
- 阅读进度保存（saveBookProgress），退出时自动保存
- 已读章节标记（addreadchapter/getBookread），目录中已读章节灰色显示
- 点击屏幕切换顶部/底部控制栏
- 上一章/下一章导航
- 字号/行距滑块调节
- 底部进度条显示章节进度
- 目录弹窗（DraggableScrollableSheet），当前章节高亮
- 暖色阅读背景（#F5F0E8）

**2. 书架分组筛选（BookshelfPage）**:
- ChoiceChip 横向滚动分组筛选：全部/未分组/有声书/漫画/自定义分组
- 分组加载：getBookshelfPage → getgroupNew
- 分组 CRUD：添加分组（addgroup）、删除分组（delgroup）、重命名分组（editgroup）
- 书籍设置分组（setgroup）
- BookCard 长按菜单支持修改类型和设置分组
- 下拉刷新

**3. 搜索多书源并行搜索（SearchPage）**:
- 启动时加载所有启用搜索的书源（getBookSourcesPage → getBookSourcesNew）
- 搜索时并行查询前6个书源（Future.wait）
- 实时显示搜索进度（已搜索源数/总源数）
- 结果去重（按 bookUrl+origin）
- 无书源时回退到单源搜索
- 封面图通过 proxypng 代理加载

### 待开发（按优先级）

**P1 — 核心功能**:
- 发现页书籍列表展示
- 书源管理完整页面（导入/编辑/启用禁用/分组/排序/导出）
- 阅读器设置（字体/背景/翻页模式/替换规则）
- 书签功能（addbookmark/getbookmark/delbookmark）

**P2 — 进阶功能**:
- RSS 文章列表页 + 文章详情页（WebView 渲染）
- 替换规则管理页
- TTS 语音朗读
- 缓存/离线功能
- 本地书籍导入（TXT/EPUB）
- KV 配置同步（getitem/setitem）— 原版用此同步前端设置

**P3 — 体验优化**:
- 阅读背景自定义
- WebView 漫画/有声书支持
- 付费章节
- 图片解密代理
- Cookie 管理
- 多设备管理

## 关键技术信息

### API 要点
- 基础路径: `/api/{v}`，v=5，所有接口直接挂在此路径下，无子路径分组
- 认证: `accessToken` 查询参数（非 Header）
- `appversion` 返回纯字符串，非 JsonResponse
- `deleteBooks` 的 ids 是书籍 URL 列表（@Body JSON数组），非查询参数
- `saveBookProgress` 的 pos 是 Double? 可空，默认 0.0
- `getBookshelfPage` 返回 {page: 总页数, md5: 书架md5标识}
- `getBookshelfNew` 需要 md5 参数（从 getBookshelfPage 获取）
- `getgroupNew` 需要 md5 参数
- `saveRssSources` 的 source/urls 是普通参数，非 @Body
- `getBookSourcesPage` 返回的 md5 = `user.sourcemd5 + user.source`
- `getBookSources` 的 errorMsg 有语义: "ok"=有权限, "no"=无权限
- `proxypng` 无需 accessToken
- `uploadimage` 返回 `http//assets/images/{md5}.png`（缺少冒号，是后端 bug）
- `getChapterListNew` 参数: bookSourceUrl(非source)/bookname/useReplaceRule/needRefresh
- `getBookContentNew` 返回 {text: 正文内容, rules: 替换规则列表}
- `saveBookProgress` 参数: url/title/index/pos/isnew
- `addreadchapter` 的 readchapter 为章节索引字符串

### 后端额外发现
- `BookMarkController`（3个）: addbookmark/getbookmark/delbookmark — API 文档已补
- `ItemController`（2个）: getitem/setitem — 前端 KV 配置同步用，API 文档已补
- `A.ba("/...")` 形式的 API 调用已从编译产物 main.dart.js*.part.js 中完整提取并核对

### Flutter 版本
- Flutter 3.0.0 (stable), Dart 2.17.0 — 工作区环境
- 项目 SDK 约束: `>=2.17.0 <3.0.0`
- 注意：不可使用 `context.mounted`（3.7+才支持）、`firstOrNull`（Dart 2.18+才支持）、`TabAlignment`（3.13+才支持）

### 当前依赖
```yaml
provider: ^6.0.3 | dio: ^4.0.6 | shared_preferences: ^2.0.15
cached_network_image: ^3.2.1 | flutter_html: ^3.0.0-alpha.3
webview_flutter: ^3.0.4 | url_launcher: ^6.1.3
path_provider: ^2.0.11 | json_annotation: ^4.5.0
```

## 文件导航

| 用途 | 路径 |
|------|------|
| 入口 | `lib/main.dart` |
| App 配置 | `lib/app.dart` |
| 路由 | `lib/config/routes.dart` |
| 常量 | `lib/config/constants.dart` |
| 主题 | `lib/config/theme.dart` |
| API 服务 | `lib/services/api_service.dart` |
| 本地存储 | `lib/services/storage_service.dart` |
| 用户状态 | `lib/providers/user_provider.dart` |
| 书架状态 | `lib/providers/bookshelf_provider.dart` |
| 阅读器状态 | `lib/providers/reader_provider.dart` |
| 发现状态 | `lib/providers/discover_provider.dart` |
| RSS状态 | `lib/providers/rss_provider.dart` |
| 阅读器页 | `lib/pages/reader/reader_page.dart` |
| 书架页 | `lib/pages/bookshelf/bookshelf_page.dart` |
| 搜索页 | `lib/pages/search/search_page.dart` |
| API 文档 | `doc/API.md` |
| 功能清单 | `doc/FEATURE_TODO.md` |
| 后端控制器 | `/workspace/read/src/main/kotlin/web/controller/api/` |
| 后端基础路径 | `/workspace/read/src/main/kotlin/web/controller/api/BaseController.kt` → `routepath="/api/{v}"` |

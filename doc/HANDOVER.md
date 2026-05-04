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
3. **数据模型** — Book/BookSource/RssSource/RssArticle/BookGroup/ReplaceRule/SearchResult/Chapter（含 .g.dart，已提交到 Git）
4. **API 服务层** — `lib/services/api_service.dart`，Dio 单例，完整覆盖后端所有 API
5. **本地存储** — `lib/services/storage_service.dart`，SharedPreferences 存储 token/baseUrl/themeMode
6. **状态管理** — Provider: UserProvider/BookshelfProvider/DiscoverProvider/RssProvider/ReaderProvider
7. **页面实现**:
   - ✅ 书架页（GridView 3列 + 下拉刷新 + 分组筛选 + 分组 CRUD）
   - ✅ 发现页（ExpansionTile 按分组展示书源 + 分类底部弹窗 + getBookSourcesExploreUrl API）
   - ✅ RSS订阅页（分组网格展示 + 源卡片）
   - ✅ 我的页（用户信息/设置入口/服务器地址配置/关于）
   - ✅ 登录/注册页（切换模式 + 密码可见性）
   - ✅ 搜索页（多书源并行搜索 + 去重 + 加入书架）
   - ✅ 阅读器页（章节列表 + 内容展示 + 进度保存 + 翻页 + 字号/行距调节 + 目录弹窗）
   - ⬜ 书源管理页（占位，开发中）
   - ⬜ RSS源管理页（占位，开发中）
8. **组件** — BookCard/RssSourceCard/LoadingWidget
9. **主题** — 明暗模式切换（teal 主色 #009688），CardThemeData（非 CardTheme）
10. **API 文档** — `doc/API.md`，157 个端点完整记录
11. **功能清单** — `doc/FEATURE_TODO.md`，按 5 大页面详细列出功能+API+样式参考
12. **登录→数据加载完整链路** — 已验证可跑通

### 本会话修复的关键问题

1. **`.g.dart` 未提交** — `.gitignore` 排除了 `*.g.dart`，克隆后缺失 → 已移除排除，8个 `.g.dart` 已提交
2. **`CardTheme` → `CardThemeData`** — 新版 Flutter 重命名 → 已修复
3. **API 版本号** — `apiVersion = 1` → `5`（后端 `apiversion = 5`，版本校验 `v < apiversion` 会拒绝）
4. **登录 token 字段** — 后端返回 `data.accessToken`，代码写的是 `data.token` → 已修复
5. **getUserInfo 路径** — `/getuserinfo` → `/getUserInfo`（大小写敏感）
6. **getUserInfo 用户名路径** — `data.name` → `data.userInfo.username`
7. **多个 API 路径大小写** — `/getBookInfo`→`/getBookinfo`、`/deleteReplaceRule`→`/delReplaceRule`、`/deleteBookSources`→`/delbookSources`、`/getRssArticles`→`/getArticles`
8. **注册接口不存在** — `/register` 不存在，注册也走 `/login`
9. **Bearer header 无用** — 后端通过 `accessToken` 查询参数认证，不需要 Authorization header → 已移除
10. **getBookshelfPage 响应解析** — 直接取 `['md5']` → 取 `['data']['md5']`
11. **setState during build** — `didChangeDependencies` 中直接触发异步操作 → 改用 `addPostFrameCallback` 延迟加载
12. **登录后数据不刷新** — 各页面监听 `UserProvider.isLoggedIn` 变化自动加载数据
13. **New 接口缓存机制** — `getBookSourcesNew`/`getRssSourcessNew` 必须先调 `Page` 接口写入缓存再读取，且缓存60秒TTL过期后返回 false → 添加 `getBookSources`/`getRssSources` fallback
14. **残留代码片段** — `api_service.dart` 第333-343行重复代码 → 已删除

### 待开发（按优先级）

**P1 — 核心功能**:
- 发现页书籍列表展示（点击分类后展示 exploreBook 结果）
- 书源管理完整页面（导入/编辑/启用禁用/分组/排序/导出）
- 阅读器设置（字体/背景/翻页模式/替换规则）
- 书签功能（addbookmark/getbookmark/delbookmark）

**P2 — 进阶功能**:
- RSS 文章列表页 + 文章详情页（WebView 渲染）
- 替换规则管理页
- TTS 语音朗读
- 缓存/离线功能
- 本地书籍导入（TXT/EPUB）
- KV 配置同步（getitem/setitem）

**P3 — 体验优化**:
- 阅读背景自定义
- WebView 漫画/有声书支持
- 付费章节
- 图片解密代理
- Cookie 管理
- 多设备管理

## 关键技术信息

### API 要点
- 基础路径: `/api/{v}`，**v=5**，所有接口直接挂在此路径下，无子路径分组
- 认证: `accessToken` **查询参数**（非 Header，不需要 Bearer token）
- **版本校验**: login 的 `v` 是路径参数 `@Path v:Int`，`v < 5` 会返回"版本不支持"，`v > 5` 返回"后端不支持"
- `appversion` 返回纯字符串（当前 `"3.1.0"`），非 JsonResponse
- `deleteBooks` 的 ids 是书籍 URL 列表（@Body JSON数组）
- `saveBookProgress` 的 pos 是 Double? 可空，默认 0.0
- **缓存机制**: `getXxxPage` 接口写入缓存并返回 md5+page，`getXxxNew` 接口从缓存读取。New 接口缓存60秒TTL，过期返回 `isSuccess: false`
- md5 格式: 书架=`user.bookmd5`，书源=`user.sourcemd5+user.source`，RSS=`user.rssmd5+user.source`
- `getBookSources` fallback: errorMsg "ok"=有权限, "no"=无权限；返回 data 直接是数组
- `getRssSourcess` fallback: 返回 `{sources: [...], can: true/false}`
- `proxypng` 无需 accessToken
- `getChapterListNew` 参数: bookSourceUrl(非source)/bookname/useReplaceRule/needRefresh
- `getBookContentNew` 返回 {text: 正文内容, rules: 替换规则列表}
- `addreadchapter` 的 readchapter 为章节索引字符串
- `saveRssSources` 的 source/urls 是普通参数，非 @Body
- `uploadimage` 返回 `http//assets/images/{md5}.png`（缺少冒号，是后端 bug）

### 后端额外发现
- `BookMarkController`（3个）: addbookmark/getbookmark/delbookmark
- `ItemController`（2个）: getitem/setitem — 前端 KV 配置同步用
- 后端没有独立的注册接口，注册也走 `/login`
- 后端**没有** `/register` 端点

### 用户权限（user.source）
- `0`: 只读模式，能获取书/RSS源列表和阅读，不能修改书源/RSS源
- `1`: 可获取所有源（含禁用的），可修改
- `2`: 独立书源空间

### Flutter 版本
- 用户本机 Flutter 版本较新（支持 CardThemeData）
- 项目 SDK 约束: `>=2.17.0 <3.0.0`
- 注意：不可使用 `context.mounted`（3.7+）、`firstOrNull`（Dart 2.18+）、`TabAlignment`（3.13+）

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

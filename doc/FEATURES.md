# Qread Flutter 客户端功能列表

> 基于 `/workspace/read` Web 端（Flutter Web 编译产物）功能逆推
> 仅供开发 TODO 使用，标记 ☐=未实现

---

## 一、书架

### 1.1 书架列表
- ☐ 网格/列表视图切换
- ☐ 按分组筛选（全部/自定义分组）
  - API: `getBookshelfPage` → `getBookshelfNew`（分页加载）
  - API: `getgroupNew`（获取分组列表）
- ☐ 下拉刷新 / 长按批量选择
- ☐ 书籍封面卡片显示：封面、书名、最新章节、阅读进度
  - 封面通过 `proxypng` 代理加载
- ☐ 书架搜索（按书名筛选）
  - API: `getBookshelf`（旧版，传 `name` 参数筛选）

### 1.2 书籍操作
- ☐ 长按弹出菜单：详情/更新/换源/删除/改分组/修改类型
  - API: `deleteBook` / `deleteBooks`（删除）
  - API: `refreshBook`（更新书籍信息）
  - API: `setBookSource`（换源）
  - API: `setgroup` / `setgroups`（修改分组）
  - API: `changebooktype`（修改类型：0小说/1有声/2漫画）
  - API: `updateuseReplaceRule`（开关替换规则）
- ☐ 点击书籍进入阅读器

### 1.3 阅读进度同步
- ☐ 自动上传阅读进度
  - API: `saveBookProgress`（pos/index/title）
- ☐ 多设备进度同步（WebSocket `read` 消息推送）
  - WS: `/api/{v}/ws?id={accessToken}`
  - 收到 `bookmd5` 消息时刷新书架

### 1.4 添加书籍
- ☐ 从搜索结果加入书架
  - API: `saveBook`
- ☐ 从发现页加入书架
- ☐ URL 导入
  - API: `urlsaveBook`
- ☐ 批量导入（本地书籍同步）
  - API: `saveBooks`

### 1.5 本地书籍
- ☐ 上传 TXT/EPUB 文件
  - API: `importBookPreview`
- ☐ 本地书籍封面自定义上传
  - API: `uploadimage`（返回 `http//assets/images/{md5}.png`）
- ☐ 修改书籍信息（自定义封面/书名/作者/简介）
  - API: `saveBookInfo`

### 1.6 缓存管理
- ☐ 添加/删除缓存
  - API: `addCache` / `delCache` / `getcancachelist`
- ☐ 刷新缓存
  - API: `fetchBook` / `fetchBookContent`
- ☐ 清理全部缓存
  - API: `cleancaches`

---

## 二、发现

### 2.1 发现页分类
- ☐ 书源分组列表（按 `bookSourceGroup` 分组展示）
  - API: `getBookSourcesPage` → `getBookSourcesNew`
- ☐ 展开/折叠分组，显示启用发现的书源
- ☐ 点击书源显示发现分类
  - API: `getBookSourcesExploreUrl`（获取分类URL列表）

### 2.2 发现内容浏览
- ☐ 分类内容网格/列表
  - API: `exploreBook`（按 ruleFindUrl+page 加载）
- ☐ 分页加载更多
- ☐ 点击书籍查看详情 / 加入书架

### 2.3 发现页动作
- ☐ 执行书源发现动作
  - API: `findaction`（action/key/value）

---

## 三、订阅

### 3.1 RSS 源列表
- ☐ 按分组展示 RSS 源（卡片网格）
  - API: `getRssSourcessPage` → `getRssSourcessNew`
  - 或 API: `getRssSourcess`（旧版一次加载）
- ☐ 显示：源图标、源名称、分组、启用状态

### 3.2 RSS 文章列表
- ☐ 获取 RSS 分类标签
  - API: `getRssType`（返回 type/url/name/enableJs/js/loginUi 等）
  - API: `getRsssortUrls`（获取分类列表）
- ☐ 按分类加载文章列表
  - API: `getArticles`（id/sortUrl/sortName/page）
- ☐ 分页加载
- ☐ 文章卡片：标题、描述、发布时间、缩略图

### 3.3 RSS 文章阅读
- ☐ 获取文章内容（HTML）
  - API: `getRssContent`（返回 content/enableJs/js/header/baseurl/id）
- ☐ WebView 渲染（enableJs=true 时）
- ☐ 内容缓存 HTML 获取
  - API: `getRssContenthtml`（按缓存 id 获取）
- ☐ URL 跳转拦截
  - API: `rssshouldOverrideUrlLoading`

### 3.4 RSS 源管理
- ☐ 添加/导入 RSS 源
  - API: `saveRssSources`（source/urls 参数）
- ☐ 编辑 RSS 源
  - API: `editRssSources`
- ☐ 删除/启用/禁用/置顶/置底
  - API: `delRssSource` / `delRssSources`
  - API: `stopRssSource` / `startRssSources` / `stopRssSources`
  - API: `topRssSource` / `bottomRssSource`
  - API: `topallrssSource` / `bottomallrssSource`
- ☐ 修改分组
  - API: `editrsssourcegroup`
- ☐ 导出源 JSON
  - API: `getRssSourcejson`
- ☐ 查看源详情
  - API: `getRssSources`
- ☐ 登录/变量
  - API: `getRssSourcesloginui` / `getRssLoginInfo` / `putRssLoginInfo`
  - API: `rssaction` / `getRssVariable` / `setRssVariable`

---

## 四、我的

### 4.1 用户认证
- ☐ 登录
  - API: `login`
- ☐ 注册（邀请码版/邮箱验证码版）
  - API: `register`（对应后端 `/regester`）
- ☐ 修改密码
  - API: `changepass`
- ☐ 管理登录设备
  - API: `getalltocken`
- ☐ 退出登录

### 4.2 书源管理
- ☐ 书源列表（分页/搜索/按分组筛选）
  - API: `getBookSourcesPage` → `getBookSourcesNew`
- ☐ 导入书源（JSON/URL）
  - API: `saveBookSources` / `saveBookSourcesv2` / `saveBookSource`
- ☐ 编辑书源
  - API: `editbookSources`
- ☐ 查看书源详情
  - API: `getbookSources`
- ☐ 删除/启用/禁用/置顶/置底
  - API: `delbookSource` / `delbookSources`
  - API: `stopbookSource` / `stopbookSources` / `startbookSources`
  - API: `topSource` / `bottomSource` / `topallSource` / `bottomallSource`
- ☐ 启用/禁用发现
  - API: `stopbookSourceExplores` / `startbookSourceExplores`
- ☐ 修改书源分组
  - API: `editsourcegroup`
- ☐ 导出书源 JSON
  - API: `getbookSourcejson`
- ☐ 检查书源权限
  - API: `getcansource` / `getBookSources`（errorMsg 含权限语义）

### 4.3 替换规则管理
- ☐ 规则列表
  - API: `getReplaceRulesPage` → `getReplaceRulesNew`
- ☐ 添加/编辑/删除规则
  - API: `addReplaceRule` / `saverule` / `delReplaceRule` / `delReplaceRules`
- ☐ 启用/禁用/置顶
  - API: `stopReplaceRules` / `startReplaceRulesbyIds` / `stopReplaceRulesbyIds`
  - API: `topReplaceRule`
- ☐ 批量导入规则
  - API: `saverules`
- ☐ 获取默认净化规则
  - API: `getdefaultrule`

### 4.4 TTS 朗读引擎管理
- ☐ 引擎列表
  - API: `getallttsPage` → `getallttsNew` / `getalltts`
- ☐ 添加/编辑/删除引擎
  - API: `addtts` / `savettss` / `deltts` / `delttss`
- ☐ 获取默认 TTS
  - API: `getdefaulttts`
- ☐ 登录/变量
  - API: `getttsLoginInfo` / `putttsLoginInfo`
  - API: `ttsaction`

### 4.5 分组管理
- ☐ 分组列表
  - API: `getgroup`
- ☐ 添加/删除/重命名分组
  - API: `addgroup` / `delgroup` / `editgroup`
- ☐ 分组排序
  - API: `ordergroup`

### 4.6 阅读背景管理
- ☐ 背景列表
  - API: `getallgroundPage` → `getallgroundNew` / `getallground`
- ☐ 添加/删除背景
  - API: `addground` / `delground`
- ☐ 导入背景图片
  - API: `importground`

### 4.7 服务器设置
- ☐ 配置服务器地址
- ☐ 书源权限修改
  - API: `changeSourcePermission`

### 4.8 Cookie 管理
- ☐ 保存/获取/清理 Cookie
  - API: `saveCookies` / `getCookies` / `cleancookies`
- ☐ WebView 回调
  - API: `noCookies` / `savehtml`

### 4.9 JSON 上传
- ☐ 上传 JSON 文件
  - API: `upjson`

---

## 五、阅读器

### 5.1 章节目录
- ☐ 章节列表展示
  - API: `getChapterList` / `getChapterListNew`（新版支持替换规则）
- ☐ 章节替换规则（标题净化）
  - API: `getChapterListNew`（useReplaceRule=1）
- ☐ 目录刷新
  - API: `getChapterListNew`（needRefresh=1）

### 5.2 正文阅读
- ☐ 加载章节内容
  - API: `getBookContent` / `getBookContentNew`
- ☐ 替换规则生效
  - API: `getBookContentNew`（useReplaceRule=1，返回 rules+text）
- ☐ 翻页/滚动模式
- ☐ 阅读进度记忆与上传
  - API: `saveBookProgress`
- ☐ 已读章节记录
  - API: `addreadchapter`（上传已读章节列表）
  - API: `getBookread`（获取已读章节）

### 5.3 阅读设置
- ☐ 字体大小调节
- ☐ 行间距/边距调节
- ☐ 主题/背景色切换（内置+自定义背景）
  - 背景图: `assets/bg/1.jpg ~ 14.jpg`
  - API: `getallground`（自定义背景）
- ☐ 亮度调节
- ☐ 屏幕常亮（wakelock_plus 插件）
- ☐ 音量键翻页

### 5.4 TTS 朗读
- ☐ TTS 语音合成播放
  - API: `/api/{v}/tts`（音频流，id/speakText/speechRate）
- ☐ 语速调节（5-50）
- ☐ 播放/暂停/上下章

### 5.5 换源
- ☐ 显示可用书源列表
- ☐ 切换书源
  - API: `setBookSource`

### 5.6 书源登录
- ☐ 登录 UI 展示
  - API: `getSourcesloginui`
- ☐ 保存/获取登录信息
  - API: `getLoginInfo` / `putLoginInfo`
- ☐ 获取/设置变量
  - API: `getVariable` / `setVariable`
- ☐ 执行书源动作
  - API: `action`
- ☐ 获取/设置书籍变量
  - API: `getbookVariable` / `setbookVariable`

### 5.7 图片相关
- ☐ 封面图片代理
  - API: `proxypng`
- ☐ 图片解密
  - API: `imageDecode`
- ☐ 自定义封面
  - API: `uploadimage` / `saveBookInfo`

### 5.8 付费章节
- ☐ 购买章节
  - API: `payAction` / `payAction2`

### 5.9 URL 解析
- ☐ 解析 AnalyzeUrl 获取最终 URL
  - API: `getopenurl`
- ☐ 通用代理请求
  - API: `listen`
- ☐ JSON 代理请求
  - API: `getjson`
- ☐ SVG 转 PNG
  - API: `svgtopng`

---

## 六、实时通信（WebSocket）

- ☐ WebSocket 连接: `/api/{v}/ws?id={accessToken}`
- ☐ 初始化消息（onOpen 推送）:
  - `init` — 连接建立
  - `source` — 书源权限（"0"=无/"1"=有）
  - `bookmd5` — 书架变更标识
  - `sourcemd5` — 书源变更标识
  - `rssmd5` — RSS源变更标识
  - `tssmd5` — TTS变更标识
  - `replacemd5` — 替换规则变更标识
  - `groundmd5` — 背景变更标识
  - `allowchange` — 是否允许修改权限
  - `gonggao` — 公告内容
- ☐ 变更推送（其他端操作后触发）:
  - 收到 `bookmd5` → 刷新书架
  - 收到 `sourcemd5` → 刷新书源列表
  - 收到 `rssmd5` → 刷新RSS源列表
  - 收到 `read` + `bookurl` → 刷新指定书籍阅读进度
  - 收到 `logout` → 强制登出
- ☐ WebView 请求/响应（通过 `ResponseManager` 中转）
  - `saveCookies` / `savehtml` / `noCookies` 配合 WebSocket 完成异步 WebView 请求

---

## 七、全局功能

### 7.1 搜索
- ☐ 多书源并行搜索
  - API: `searchBook`（bookSourceUrl/key/page）
- ☐ 搜索结果展示：书名、作者、封面、来源
- ☐ 点击查看详情 / 加入书架

### 7.2 版本检查
- ☐ 获取 App 版本
  - API: `appversion`（纯字符串返回）
- ☐ 版本比对与更新提示

### 7.3 书籍详情
- ☐ 获取书籍详情
  - API: `getBookinfo` / `getBookinfo2`
- ☐ 显示：封面、书名、作者、简介、最新章节、总章节数
- ☐ 加入书架 / 开始阅读

### 7.4 主题切换
- ☐ 明/暗模式
- ☐ 跟随系统

### 7.5 多设备同步
- ☐ 基于 md5 标识的增量同步
  - 书架: `bookmd5`
  - 书源: `sourcemd5`
  - RSS源: `rssmd5`
  - 替换规则: `replacemd5`
  - TTS: `tssmd5`
  - 背景: `groundmd5`

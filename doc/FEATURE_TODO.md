# Qread Flutter 客户端功能开发清单

> 基于原版 Web 阅读器（Flutter Web 编译产物）反编译分析 + 后端源码核对  
> 原版版本：3.4.5 (build 27)

---

## 一、书架页面 (Bookshelf)

### 1.1 页面布局

| 功能 | 说明 | 参考样式位置 |
|------|------|-------------|
| 顶部标题栏 | 显示"书架"标题，右侧搜索+更多菜单按钮 | AppBar |
| 分组筛选栏 | 横向滚动Tab栏：全部/未分组/有声书/漫画/自定义分组 | TabBar + TabController |
| 书籍网格 | 3列网格展示书籍封面+书名+阅读进度 | GridView(crossAxisCount:3, childAspectRatio:0.65) |
| 下拉刷新 | 刷新书架数据 | RefreshIndicator |
| 搜索入口 | 跳转搜索页 | IconButton → /search |
| 长按操作 | 长按书籍弹出底部菜单 | showModalBottomSheet |

### 1.2 分组筛选功能

| 功能 | API | 说明 |
|------|-----|------|
| 获取分组列表 | `GET /getBookshelfPage` → 拿到md5 | 先获取分页信息和md5 |
| 获取分组数据 | `GET /getgroupNew?accessToken=&md5=` | 返回分组列表 |
| 获取书架书籍 | `GET /getBookshelfNew?accessToken=&md5=&page=` | 按页加载书籍 |
| 添加分组 | `POST /addgroup?accessToken=&name=` | 输入新分组名 |
| 删除分组 | `POST /delgroup?accessToken=&name=` | 删除分组 |
| 重命名分组 | `POST /editgroup?accessToken=&oldname=&newname=` | 修改分组名 |
| 分组排序 | `POST /ordergroup?accessToken=&groups=` | 传入排序后的分组名JSON数组 |
| 设置书籍分组 | `POST /setgroup?accessToken=&name=&url=` | 单本设置 |
| 批量设置分组 | `POST /setgroups?accessToken=&name=` + Body ids | 多本设置 |

### 1.3 书籍操作功能

| 功能 | API | 说明 |
|------|-----|------|
| 删除书籍 | `POST /deleteBook` + Body SearchBook | 单本删除（需传book对象） |
| 批量删除 | `POST /deleteBooks` + Body ids(List\<String\>) | ids为书籍URL列表 |
| 刷新书籍 | `GET /refreshBook?accessToken=&bookurl=` | 重新获取书籍信息 |
| 更换书源 | `GET /setBookSource?accessToken=&bookUrl=&newUrl=&bookSourceUrl=` | 切换书源 |
| 修改类型 | `GET /changebooktype?accessToken=&bookUrl=&type=` | 0:小说 1:有声 2:漫画 |
| 修改替换规则 | `GET /updateuseReplaceRule?accessToken=&url=&useReplaceRule=` | 0/1 |
| 加入缓存 | `GET /addCache?accessToken=&url=` | 离线缓存 |
| 检查可缓存 | `GET /getcancache?accessToken=&url=` | 是否可缓存 |

### 1.4 更多菜单

| 功能 | API | 说明 |
|------|-----|------|
| 书籍详情 | → 跳转书籍详情页 | 显示完整信息 |
| 批量管理 | — | 勾选多本进行批量删除/分组 |
| 书架排序 | 本地操作 | 按名称/作者/最近阅读排序 |

---

## 二、发现页面 (Discover)

### 2.1 页面布局

| 功能 | 说明 | 参考样式位置 |
|------|------|-------------|
| 顶部标题栏 | "发现"标题 | AppBar |
| 书源分组列表 | ExpansionTile展开式列表，按书源分组折叠 | ListView + ExpansionTile |
| 分类底部弹窗 | 点击书源弹出分类选择 | showModalBottomSheet + DraggableScrollableSheet |
| 发现结果页 | 网格/列表展示发现书籍 | 同书架网格样式 |

### 2.2 发现功能

| 功能 | API | 说明 |
|------|-----|------|
| 获取书源分页 | `GET /getBookSourcesPage?accessToken=` | 拿到md5和page |
| 获取书源列表 | `GET /getBookSourcesNew?accessToken=&md5=&page=` | 获取所有书源 |
| 获取发现分类 | `GET /getBookSourcesExploreUrl?accessToken=&bookSourceUrl=&need=1` | 返回found(分类列表)、checkKeyWord、loginUrl、loginUi |
| 发现书籍 | `GET /exploreBook?accessToken=&bookSourceUrl=&page=&ruleFindUrl=` | 按分类获取书籍列表 |

### 2.3 书源管理入口

| 功能 | API | 说明 |
|------|-----|------|
| 进入书源管理 | → /sourceManage | 独立页面管理书源 |

---

## 三、订阅页面 (RSS)

### 3.1 页面布局

| 功能 | 说明 | 参考样式位置 |
|------|------|-------------|
| 顶部标题栏 | "订阅"标题 + 添加按钮 | AppBar + IconButton |
| 分组标题 | 按源分组显示组名 | Padding + Text(titleMedium, bold) |
| 源卡片网格 | 2列网格展示RSS源（图标+名称+描述） | GridView(crossAxisCount:2, childAspectRatio:1.8) |
| 下拉刷新 | 刷新RSS源列表 | RefreshIndicator |

### 3.2 RSS源功能

| 功能 | API | 说明 |
|------|-----|------|
| 获取RSS源分页 | `GET /getRssSourcessPage?accessToken=` | 拿md5和page |
| 获取RSS源列表 | `GET /getRssSourcessNew?accessToken=&md5=&page=` | 分页加载 |
| 获取全部RSS源(旧) | `GET /getRssSourcess?accessToken=` | 返回sources+can |
| 保存RSS源 | `POST /saveRssSources?accessToken=&source=&urls=` | source和urls为普通参数 |
| 编辑RSS源 | `POST /editRssSources` + Body EditMsg | json+id |
| 删除RSS源 | `POST /delRssSource?accessToken=&id=` | 单个删除 |
| 批量删除 | `POST /delRssSources` + Body ids | 批量 |
| 启用/禁用 | `POST /stopRssSource?accessToken=&id=&st=` | 0:禁 1:启 |
| 批量启用 | `POST /startRssSources` + Body ids | |
| 批量禁用 | `POST /stopRssSources` + Body ids | |
| 置顶 | `POST /topRssSource?accessToken=&id=` | |
| 置底 | `POST /bottomRssSource?accessToken=&id=` | |
| 批量置顶 | `POST /topallrssSource` + Body ids | |
| 批量置底 | `POST /bottomallrssSource` + Body ids | |
| 修改分组 | `POST /editrsssourcegroup?accessToken=&st=&group=` + Body ids | |
| 获取源JSON | `POST /getRssSourcejson` + Body ids | |
| 获取登录UI | `GET /getRssSourcesloginui?accessToken=&url=` | |

### 3.3 RSS文章列表页（点击源后进入）

| 功能 | API | 说明 |
|------|-----|------|
| 获取RSS类型 | `GET /getRssType?accessToken=&id=` | 返回type/url/name/enableJs等 |
| 获取分类Tab | `GET /getRsssortUrls?accessToken=&id=` | 返回sortName+sortUrl数组 |
| 获取文章列表 | `GET /getArticles?accessToken=&id=&sortUrl=&sortName=&page=` | 返回articles+next |
| URL跳转拦截 | `GET /rssshouldOverrideUrlLoading?accessToken=&id=&url=` | 返回true允许/false拦截 |

### 3.4 RSS文章详情页

| 功能 | API | 说明 |
|------|-----|------|
| 获取文章内容 | `GET /getRssContent?accessToken=&id=&article=` | 返回content+enableJs+js+header+baseurl+id |
| 获取内容HTML | `GET /getRssContenthtml?id=` | 直接输出HTML（通过缓存ID） |
| 获取登录信息 | `GET /getRssLoginInfo?accessToken=&id=` | |
| 保存登录信息 | `POST /putRssLoginInfo?accessToken=&id=&info=` | |
| 执行动作 | `POST /rssaction?accessToken=&id=&action=` | |
| 获取变量 | `GET /getRssVariable?accessToken=&id=` | |
| 设置变量 | `POST /setRssVariable?accessToken=&id=&info=` | |

---

## 四、我的页面 (Profile)

### 4.1 页面布局

| 功能 | 说明 | 参考样式位置 |
|------|------|-------------|
| 用户卡片 | 头像+用户名+登录状态 | Card + CircleAvatar + ListTile |
| 功能菜单列表 | 书源管理/订阅源管理/替换规则/TTS等 | Card + ListView ListTile |
| 服务器设置 | 配置后端地址 | AlertDialog + TextField |
| 主题切换 | 明暗模式切换 | SwitchListTile |
| 关于信息 | 版本号 | ListTile |

### 4.2 用户功能

| 功能 | API | 说明 |
|------|-----|------|
| 登录 | `POST /login?username=&password=&model=&v=` | v为API版本号(Path) |
| 注册 | — (同login接口的注册流程) | |
| 获取用户信息 | `GET /getUserInfo?accessToken=` | 返回userInfo对象 |
| 修改密码 | `POST /changepass?accessToken=&password=&oldpassword=` | |
| 获取登录设备 | `GET /getalltocken?accessToken=` | |
| 修改书源权限 | `POST /changeSourcePermission?accessToken=&permission=` | 0/2 |
| 退出登录 | 本地操作 | 清除token |

### 4.3 书源管理页面（/sourceManage）

| 功能 | API | 说明 |
|------|-----|------|
| 分页信息 | `GET /getBookSourcesPage?accessToken=` | |
| 分页数据 | `GET /getBookSourcesNew?accessToken=&md5=&page=` | |
| 检查权限 | `GET /getcansource?accessToken=` | |
| 保存书源(v1) | `POST /saveBookSources` + Body content | JSON数组 |
| 保存书源(v2) | `POST /saveBookSourcesv2?group=&source=&urls=` | 支持分组+URL过滤 |
| 保存单个书源 | `POST /saveBookSource` + Body content | |
| 获取书源详情 | `GET /getbookSources?accessToken=&id=` | 返回json+enabled+group |
| 编辑书源 | `POST /editbookSources` + Body EditMsg | json+id |
| 删除书源 | `POST /delbookSource?accessToken=&id=` | |
| 批量删除 | `POST /delbookSources` + Body ids | |
| 启用/禁用 | `POST /stopbookSource?accessToken=&id=&st=` | 0/1 |
| 批量禁用 | `POST /stopbookSources` + Body ids | |
| 批量启用 | `POST /startbookSources` + Body ids | |
| 禁用发现 | `POST /stopbookSourceExplores` + Body ids | |
| 启用发现 | `POST /startbookSourceExplores` + Body ids | |
| 置顶 | `POST /topSource?accessToken=&id=` | |
| 置底 | `POST /bottomSource?accessToken=&id=` | |
| 批量置顶 | `POST /topallSource` + Body ids | |
| 批量置底 | `POST /bottomallSource` + Body ids | |
| 修改分组 | `POST /editsourcegroup?accessToken=&st=&group=` + Body ids | |
| 导出JSON | `POST /getbookSourcejson` + Body ids | |
| 获取登录UI | `GET /getSourcesloginui?accessToken=&url=&bookurl=&chapter=` | |

### 4.4 替换规则管理页面

| 功能 | API | 说明 |
|------|-----|------|
| 分页信息 | `GET /getReplaceRulesPage?accessToken=` | |
| 分页数据 | `GET /getReplaceRulesNew?accessToken=&md5=&page=` | |
| 获取默认规则 | `GET /getdefaultrule?accessToken=` | |
| 添加规则 | `POST /addReplaceRule` + Body rule | |
| 保存单条规则 | `POST /saverule` + Body content | |
| 批量保存规则 | `POST /saverules` + Body content | |
| 删除规则 | `POST /delReplaceRule?accessToken=&id=` | |
| 批量删除 | `POST /delReplaceRules` + Body ids | |
| 启用/禁用 | `POST /stopReplaceRules?accessToken=&id=&st=` | 0/1 |
| 批量禁用 | `POST /stopReplaceRulesbyIds` + Body ids | |
| 批量启用 | `POST /startReplaceRulesbyIds` + Body ids | |
| 置顶 | `POST /topReplaceRule?accessToken=&id=` | |

### 4.5 TTS管理页面

| 功能 | API | 说明 |
|------|-----|------|
| 分页信息 | `GET /getallttsPage?accessToken=` | |
| 分页数据 | `GET /getallttsNew?accessToken=&md5=&page=` | |
| 获取全部TTS | `GET /getalltts?accessToken=` | |
| 获取默认TTS | `GET /getdefaulttts?accessToken=` | |
| 添加TTS | `POST /addtts` + Body tts | id为空新增/非空更新 |
| 删除TTS | `POST /deltts?accessToken=&id=` | |
| 批量删除 | `POST /delttss` + Body ids | |
| 保存TTS | `POST /savettss` + Body content | |
| 语音合成 | `GET /tts?accessToken=&id=&speakText=&speechRate=` | 返回音频流 |
| 获取登录信息 | `GET /getttsLoginInfo?accessToken=&id=` | |
| 保存登录信息 | `POST /putttsLoginInfo?accessToken=&id=&info=` | |
| 执行动作 | `POST /ttsaction?accessToken=&id=&action=` | |
| 上传JSON | `POST /upjson` + Body content | |

### 4.6 阅读背景管理

| 功能 | API | 说明 |
|------|-----|------|
| 分页信息 | `GET /getallgroundPage?accessToken=` | |
| 分页数据 | `GET /getallgroundNew?accessToken=&md5=&page=` | |
| 获取全部背景 | `GET /getallground?accessToken=` | |
| 添加背景 | `POST /addground` + Body ground | errorMsg为"true"时需上传图片 |
| 删除背景 | `POST /delground` + Body ground | |
| 导入背景图片 | `POST /importground` + file | |

### 4.7 本地书籍上传

| 功能 | API | 说明 |
|------|-----|------|
| 导入预览 | `POST /importBookPreview` + file | 上传TXT/EPUB |
| 上传图片 | `POST /uploadimage` + file | 返回图片路径 |

### 4.8 KV存储（前端本地配置持久化）

| 功能 | API | 说明 |
|------|-----|------|
| 获取配置 | `GET /getitem?accessToken=&name=` | 按name获取value |
| 保存配置 | `POST /setitem?accessToken=&name=&value=` | 保存KV对 |

> 原版Web阅读器用此接口保存前端配置（如阅读设置、主题偏好等），替代本地localStorage实现多端同步

### 4.9 书签管理

| 功能 | API | 说明 |
|------|-----|------|
| 添加书签 | `POST /addbookmark?accessToken=&url=&name=&index=&pos=` | url=书籍URL, name=书签名, index=章节索引, pos=位置 |
| 获取书签 | `GET /getbookmark?accessToken=&url=` | 返回书签列表 |
| 删除书签 | `POST /delbookmark?accessToken=&id=` | |

---

## 五、阅读页面 (Reader)

### 5.1 页面布局

| 功能 | 说明 | 参考样式位置 |
|------|------|-------------|
| 状态栏 | 隐藏系统状态栏 | SystemUiOverlayStyle |
| 内容区域 | 全屏显示章节内容，上下滑动翻页 | PageView / ScrollView |
| 顶部栏（点击弹出） | 书名+返回按钮 | AnimatedOpacity + AppBar |
| 底部栏（点击弹出） | 章节列表+阅读设置+亮度调节 | AnimatedOpacity + BottomSheet |
| 进度指示 | 底部章节进度+阅读百分比 | Positioned(bottom) |
| 翻页方式 | 滚动/覆盖/仿真翻页 | GestureDetector + PageView |

### 5.2 阅读核心功能

| 功能 | API | 说明 |
|------|-----|------|
| 获取章节列表 | `GET /getChapterList?accessToken=&bookSourceUrl=&url=` | 旧版 |
| 获取章节列表(新) | `GET /getChapterListNew?accessToken=&bookSourceUrl=&url=&bookname=&useReplaceRule=&needRefresh=` | 支持替换规则 |
| 获取章节内容 | `GET /getBookContent?accessToken=&bookSourceUrl=&url=&index=&type=` | 旧版，返回纯文本 |
| 获取章节内容(新) | `GET /getBookContentNew?accessToken=&bookSourceUrl=&url=&index=&type=&bookname=&useReplaceRule=` | 返回{text, rules} |
| 保存阅读进度 | `POST /saveBookProgress?accessToken=&pos=&url=&title=&index=&isnew=` | pos可选默认0.0 |
| 获取已读章节 | `GET /getBookread?accessToken=&url=` | 返回逗号分隔的章节索引 |
| 添加已读记录 | `POST /addreadchapter?accessToken=&readchapter=&url=` | |
| 刷新章节内容 | `GET /fetchBookContent?accessToken=&url=&index=` | 清缓存后重新加载 |
| 刷新书籍缓存 | `GET /fetchBook?accessToken=&url=` | 清所有缓存 |

### 5.3 阅读设置

| 功能 | API | 说明 |
|------|-----|------|
| 字体大小 | 本地设置 | SharedPreferences / setitem |
| 行距 | 本地设置 | |
| 背景色/背景图 | 本地设置 + getallground | |
| 亮度调节 | 本地设置 | screen_brightness |
| 翻页模式 | 本地设置 | 滚动/覆盖/仿真 |
| 替换规则开关 | `GET /updateuseReplaceRule?accessToken=&url=&useReplaceRule=` | |

### 5.4 章节切换

| 功能 | API | 说明 |
|------|-----|------|
| 上一章 | 本地切换 index-1 | |
| 下一章 | 本地切换 index+1 | |
| 章节目录 | 弹出章节列表 | getChapterList |
| 切换书源 | `GET /setBookSource?accessToken=&bookUrl=&newUrl=&bookSourceUrl=` | |

### 5.5 书签功能

| 功能 | API | 说明 |
|------|-----|------|
| 添加书签 | `POST /addbookmark?accessToken=&url=&name=&index=&pos=` | |
| 查看书签 | `GET /getbookmark?accessToken=&url=` | |
| 删除书签 | `POST /delbookmark?accessToken=&id=` | |

### 5.6 WebView内容（漫画/有声书）

| 功能 | API | 说明 |
|------|-----|------|
| 打开WebView | 本地 InAppWebView | 用于漫画图片和有声书播放 |
| 获取解析URL | `GET /getopenurl?accessToken=&bookSourceUrl=&url=&bookurl=` | |
| 保存Cookie | `POST /saveCookies?accessToken=&url=&cookie=&html=&id=` | |
| 获取Cookie | `GET /getCookies?accessToken=&url=` | |
| 无Cookie回调 | `POST /noCookies?accessToken=&id=` | WebView无Cookie时回调 |
| 保存HTML | `POST /savehtml?accessToken=&html=&id=` | |
| 清理Cookie | `POST /cleancookies?accessToken=` | |

### 5.7 付费章节

| 功能 | API | 说明 |
|------|-----|------|
| 购买章节(v1) | `GET /payAction?accessToken=&url=&index=` | |
| 购买章节(v2) | `GET /payAction2?accessToken=&bookSourceUrl=&url=&index=` | |

### 5.8 图片代理/解密

| 功能 | API | 说明 |
|------|-----|------|
| 封面代理 | `GET /proxypng?url=` | 无需token |
| 图片解密 | `GET /imageDecode?accessToken=&bookSourceUrl=&book=&url=&header=` | 需要图片解密权限 |
| SVG转PNG | `GET /svgtopng?accessToken=&svg=` | |

### 5.9 TTS语音朗读

| 功能 | API | 说明 |
|------|-----|------|
| 语音合成 | `GET /tts?accessToken=&id=&speakText=&speechRate=` | 返回音频流 |

---

## 六、全局功能

### 6.1 登录/注册页面

| 功能 | API | 说明 |
|------|-----|------|
| 登录 | `POST /login?username=&password=&model=&v=` | |
| 注册 | `POST /register?username=&password=` | |

### 6.2 搜索页面

| 功能 | API | 说明 |
|------|-----|------|
| 搜索书籍 | `GET /searchBook?accessToken=&bookSourceUrl=&page=&key=` | 多书源搜索 |
| URL保存书籍 | `GET /urlsaveBook?accessToken=&url=` | 通过URL识别并保存 |
| 保存书籍到书架 | `POST /saveBook?useReplaceRule=` + Body SearchBook | |
| 批量保存 | `POST /saveBooks` + Body content | JSON数组 |

### 6.3 通用代理

| 功能 | API | 说明 |
|------|-----|------|
| HTTP代理 | `GET /listen?accessToken=&url=&header=` | 通用代理请求 |
| JSON代理 | `GET /getjson?accessToken=&url=` | JSON代理请求 |

### 6.4 书源/变量操作

| 功能 | API | 说明 |
|------|-----|------|
| 获取登录信息 | `GET /getLoginInfo?accessToken=&bookSourceUrl=` | |
| 保存登录信息 | `POST /putLoginInfo?accessToken=&bookSourceUrl=&info=` | |
| 获取变量 | `GET /getVariable?accessToken=&bookSourceUrl=` | |
| 设置变量 | `POST /setVariable?accessToken=&bookSourceUrl=&info=` | |
| 执行动作 | `POST /action?accessToken=&bookSourceUrl=&action=&info=&chapter=&bookurl=` | |
| 发现页动作 | `POST /findaction?accessToken=&bookSourceUrl=&action=&key=&value=` | |
| 获取书籍变量 | `GET /getbookVariable?accessToken=&bookurl=` | |
| 设置书籍变量 | `POST /setbookVariable?accessToken=&bookurl=&info=` | |

### 6.5 版本检查

| 功能 | API | 说明 |
|------|-----|------|
| 获取版本号 | `GET /appversion` | 返回纯字符串如"3.1.0" |

### 6.6 缓存管理

| 功能 | API | 说明 |
|------|-----|------|
| 清理缓存 | `POST /cleancaches?accessToken=` | |
| 清理Cookie | `POST /cleancookies?accessToken=` | |

---

## 七、原版Web端使用但API文档遗漏的接口

> 以下接口从编译产物中提取，API.md中未记录

| 路径 | 控制器 | 说明 |
|------|--------|------|
| `/addbookmark` | BookMarkController | 添加书签(url,name,index,pos) |
| `/getbookmark` | BookMarkController | 获取书签(url) |
| `/delbookmark` | BookMarkController | 删除书签(id) |
| `/getitem` | ItemController | 获取KV配置(name) |
| `/setitem` | ItemController | 保存KV配置(name,value) |

---

## 八、开发优先级建议

### P0 - 核心流程（MVP）
1. ✅ 登录/注册
2. ✅ 书架展示（分组+书籍网格）
3. 阅读器（章节列表+内容展示+进度保存）
4. 搜索（搜索+加入书架）

### P1 - 核心功能
5. 发现页（书源分类+书籍列表）
6. 书源管理（导入/编辑/启用禁用/分组）
7. 阅读器设置（字体/背景/翻页/替换规则）
8. 书签功能

### P2 - 进阶功能
9. RSS订阅（源管理+文章列表+文章详情）
10. 替换规则管理
11. TTS语音朗读
12. 缓存/离线功能
13. 本地书籍导入
14. KV配置同步（getitem/setitem）

### P3 - 体验优化
15. 阅读背景自定义
16. WebView漫画/有声书
17. 付费章节
18. 图片解密代理
19. Cookie管理
20. 多设备管理

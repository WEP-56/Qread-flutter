# 轻阅读 (QRead) API 文档

> 基于 `/workspace/read` 项目源码分析整理  
> 所有接口直接挂在 `/api/{v}` 下，无子路径分组

## 基础信息

| 项目 | 说明 |
|------|------|
| API 版本 | 5 |
| App 版本 | 3.1.0 |
| 基础路径 | `/api/{v}` |
| 认证方式 | `accessToken` 参数 |

---

## 通用响应格式

```json
{
  "isSuccess": true,
  "errorMsg": "success",
  "data": {}
}
```

> 特例：`/api/{v}/appversion` 返回纯字符串 `"3.1.0"`，不走 JsonResponse

### 通用错误码

| 错误码 | 说明 |
|--------|------|
| NEED_LOGIN | 需要登录 |
| NOT_BANK | 参数不能为空 |
| PASS_ERROR | 密码错误 |
| NOT_SOURCE | 未找到书源 |
| NOT_IS | 记录不存在 |
| CAN_NOT | 无权限操作 |
| BOOKSEARCHERROR | 书籍搜索失败 |
| BOOKIS | 书籍已在书架 |
| NO_BOOK | 未找到书籍 |
| SOURCE_JSON_ERROR | 书源JSON格式错误 |
| SOURCE_URL_ERROR | 书源URL错误 |
| SOURCE_IS | 书源已存在 |
| NAME_ERROR | 名称已存在 |
| MAX_ERROR | 超出数量限制 |
| GROUPIS | 分组已存在 |
| GROUP_NOT_EDIT | 内置分组不可编辑 |
| TOO_MANY_GROUPS | 分组数量超过限制 |
| USE_ERROE | 操作类型错误 |
| CACHE_ERROR | 缓存数量超限 |
| CacheIS | 缓存已存在 |
| IS_WEBVIEW | 不支持WebView书源 |
| NOT_ALLOW_TXT | 不允许上传TXT |
| NOT_TXT | 仅支持TXT/EPUB格式 |
| NO_PAY | 无付费章节 |
| PASS_VAIL_ERROR | 密码格式错误 |

---

## UserController（6个）

### 获取App版本
**路径**: `/api/{v}/appversion`

**响应**: 纯字符串 `"3.1.0"`（非通用 JsonResponse）

**代码位置**: `UserController.kt:21-24`

---

### 修改书源权限
**路径**: `/api/{v}/changeSourcePermission`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| permission | Integer | 是 | 0:不允许, 2:独立书源 |

**代码位置**: `UserController.kt:29-53`

---

### 用户登录
**路径**: `/api/{v}/login`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | String | 是 | 用户名或邮箱 |
| password | String | 是 | 密码 |
| model | String | 否 | 设备型号 |
| v | Integer | 是 | App版本号（Path参数） |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "accessToken": "token_id"
  }
}
```

**代码位置**: `UserController.kt:55-82`

---

### 获取用户信息
**路径**: `/api/{v}/getUserInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "userInfo": {
      "username": "用户名",
      "phone": "手机号",
      "email": "邮箱"
    }
  }
}
```

**代码位置**: `UserController.kt:84-91`

---

### 修改密码
**路径**: `/api/{v}/changepass`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| password | String | 是 | 新密码(6-15位) |
| oldpassword | String | 是 | 旧密码 |

**代码位置**: `UserController.kt:93-108`

---

### 获取所有登录设备
**路径**: `/api/{v}/getalltocken`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": [
    {
      "id": "token_id",
      "model": "设备型号",
      "createtime": "创建时间"
    }
  ]
}
```

**代码位置**: `UserController.kt:110-117`

---

## BookshelfController（4个）

### 获取书架分页信息
**路径**: `/api/{v}/getBookshelfPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "书架标识"
  }
}
```

**代码位置**: `BookshelfController.kt:36-76`

---

### 获取书架书籍列表
**路径**: `/api/{v}/getBookshelfNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | 书架标识 |
| page | String | 是 | 页码 |

**代码位置**: `BookshelfController.kt:78-82`

---

### 获取分组列表
**路径**: `/api/{v}/getgroupNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | 书架标识 |

**代码位置**: `BookshelfController.kt:85-89`

---

### 添加已读章节记录
**路径**: `/api/{v}/addreadchapter`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| readchapter | String | 否 | 已读章节(逗号分隔) |
| url | String | 是 | 书籍URL |

**代码位置**: `BookshelfController.kt:91-109`

---

## BookController（22个）

### 搜索书籍
**路径**: `/api/{v}/searchBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| page | Integer | 否 | 页码(默认0) |
| key | String | 是 | 搜索关键词 |

**代码位置**: `BookController.kt:124-126`

---

### 发现书籍
**路径**: `/api/{v}/exploreBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| page | Integer | 否 | 页码 |
| ruleFindUrl | String | 是 | 发现规则URL |

**代码位置**: `BookController.kt:128-130`

---

### 保存书籍信息
**路径**: `/api/{v}/saveBookInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| book | Object | 是 | SearchBook对象，用于更新书名、作者、封面、简介 |

**代码位置**: `BookController.kt:133-150`

---

### URL保存书籍
**路径**: `/api/{v}/urlsaveBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍页面URL |

**代码位置**: `BookController.kt:153-195`

---

### 保存书籍到书架
**路径**: `/api/{v}/saveBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| book | Object | 是 | SearchBook对象 |
| useReplaceRule | Integer | 否 | 是否使用替换规则(0/1) |

**书籍对象结构**:
```json
{
  "name": "书名",
  "author": "作者",
  "bookUrl": "书籍URL",
  "origin": "书源URL"
}
```

**代码位置**: `BookController.kt:198-240`

---

### 批量保存书籍
**路径**: `/api/{v}/saveBooks`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | JSON数组字符串(Body) |

**代码位置**: `BookController.kt:242-295`

---

### 刷新书籍
**路径**: `/api/{v}/refreshBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookurl | String | 是 | 书籍URL |

**代码位置**: `BookController.kt:297-342`

---

### 获取书籍详情
**路径**: `/api/{v}/getBookinfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| book | Object | 是 | SearchBook对象（需含bookUrl和origin） |

**代码位置**: `BookController.kt:344-370`

---

### 通过URL获取书籍详情
**路径**: `/api/{v}/getBookinfo2`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL（无需指定书源，自动匹配） |

**代码位置**: `BookController.kt:372-379`

---

### 删除书籍
**路径**: `/api/{v}/deleteBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| book | Object | 是 | SearchBook对象（需含bookUrl） |

**代码位置**: `BookController.kt:384-411`

---

### 批量删除书籍
**路径**: `/api/{v}/deleteBooks`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书籍URL列表(Body)，非数据库ID |

**代码位置**: `BookController.kt:414-435`

---

### 修改书籍替换规则
**路径**: `/api/{v}/updateuseReplaceRule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |
| useReplaceRule | Integer | 是 | 0:不使用, 1:使用 |

**代码位置**: `BookController.kt:437-452`

---

### 检查书籍是否可缓存
**路径**: `/api/{v}/getcancache`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |

**响应**: `isSuccess=true` 表示可缓存，`isSuccess=false` 表示已有缓存不可重复

**代码位置**: `BookController.kt:454-462`

---

### 获取可缓存列表
**路径**: `/api/{v}/getcancachelist`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `BookController.kt:464-468`

---

### 添加缓存
**路径**: `/api/{v}/addCache`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |

**代码位置**: `BookController.kt:470-503`

---

### 删除缓存
**路径**: `/api/{v}/delCache`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 缓存ID |

**代码位置**: `BookController.kt:505-514`

---

### 保存Cookie
**路径**: `/api/{v}/saveCookies`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 域名URL |
| cookie | String | 是 | Cookie内容(加密) |
| html | String | 否 | WebView HTML |
| id | String | 否 | 请求ID |

**代码位置**: `BookController.kt:516-540`

---

### 获取Cookie
**路径**: `/api/{v}/getCookies`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 域名URL |

**代码位置**: `BookController.kt:542-551`

---

### 保存HTML
**路径**: `/api/{v}/savehtml`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| html | String | 否 | HTML内容 |
| id | String | 否 | 请求ID |

**代码位置**: `BookController.kt:553-563`

---

### 清理Cookies
**路径**: `/api/{v}/cleancookies`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `BookController.kt:566-572`

---

### 清理缓存
**路径**: `/api/{v}/cleancaches`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `BookController.kt:574-580`

---

### WebView无Cookie回调
**路径**: `/api/{v}/noCookies`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 请求ID |

**代码位置**: `BookController.kt:583-590`

---

## ReadController（30个）

### 获取章节列表
**路径**: `/api/{v}/getChapterList`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 否 | 书源URL(loc_book表示本地书) |
| url | String | 是 | 书籍URL |

**代码位置**: `ReadController.kt:195-200`

---

### 获取章节列表(新版)
**路径**: `/api/{v}/getChapterListNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 否 | 书源URL |
| url | String | 是 | 书籍URL |
| bookname | String | 否 | 书名(用于替换规则) |
| useReplaceRule | Integer | 否 | 是否使用替换规则 |
| needRefresh | Integer | 否 | 是否强制刷新(1) |

**代码位置**: `ReadController.kt:294-339`

---

### 获取章节内容
**路径**: `/api/{v}/getBookContent`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 否 | 书源URL |
| url | String | 是 | 书籍URL |
| index | Integer | 否 | 章节索引(默认0) |
| type | Integer | 否 | 类型(0:正文, 1:源码) |

**响应**:
```json
{
  "isSuccess": true,
  "data": "章节正文内容"
}
```

**代码位置**: `ReadController.kt:237-244`

---

### 获取章节内容(新版)
**路径**: `/api/{v}/getBookContentNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 否 | 书源URL |
| url | String | 是 | 书籍URL |
| index | Integer | 否 | 章节索引 |
| type | Integer | 否 | 类型 |
| bookname | String | 否 | 书名 |
| useReplaceRule | Integer | 否 | 是否使用替换规则 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "rules": ["生效的替换规则"],
    "text": "章节正文"
  }
}
```

**代码位置**: `ReadController.kt:246-292`

---

### 刷新章节内容
**路径**: `/api/{v}/fetchBookContent`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |
| index | Integer | 是 | 章节索引 |

**代码位置**: `ReadController.kt:341-348`

---

### 刷新书籍缓存
**路径**: `/api/{v}/fetchBook`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |

**代码位置**: `ReadController.kt:350-367`

---

### 保存阅读进度
**路径**: `/api/{v}/saveBookProgress`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| pos | Double | 否 | 阅读位置(0.0-2.0)，默认0.0 |
| url | String | 是 | 书籍URL |
| title | String | 否 | 章节标题 |
| index | Integer | 是 | 章节索引 |
| isnew | String | 否 | 是否新书("1") |

**代码位置**: `ReadController.kt:370-429`

---

### 获取已读章节
**路径**: `/api/{v}/getBookread`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |

**响应**:
```json
{
  "isSuccess": true,
  "data": "1,2,3,5,10"
}
```

**代码位置**: `ReadController.kt:432-449`

---

### 更换书籍书源
**路径**: `/api/{v}/setBookSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookUrl | String | 是 | 当前书籍URL |
| newUrl | String | 是 | 新书源URL |
| bookSourceUrl | String | 是 | 书源URL |

**代码位置**: `ReadController.kt:452-489`

---

### 获取书架（旧版，不分页）
**路径**: `/api/{v}/getBookshelf`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| version | String | 否 | 客户端版本标记 |
| name | String | 否 | 按书名筛选 |
| v | Integer | 是 | API版本号（Path参数） |

**响应**: errorMsg 字段含语义——与当前app版本一致时为 `"ok"`，否则为实际app版本号

**代码位置**: `ReadController.kt:492-519`

---

### 获取书源登录UI
**路径**: `/api/{v}/getSourcesloginui`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书源URL |
| bookurl | String | 否 | 书籍URL |
| chapter | Boolean | 否 | 是否章节上下文 |

**代码位置**: `ReadController.kt:521-559`

---

### 获取所有书源(旧版)
**路径**: `/api/{v}/getBookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| isall | String | 否 | 是否获取全部(1) |
| v | Integer | 是 | API版本号（Path参数） |

**响应**: errorMsg 字段含语义——`"ok"` 表示有书源权限，`"no"` 表示无书源权限（user.source==0）

**代码位置**: `ReadController.kt:562-603`

---

### 获取发现页URL
**路径**: `/api/{v}/getBookSourcesExploreUrl`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| need | String | 否 | 是否需要分类(1) |

**代码位置**: `ReadController.kt:606-613`

---

### 解析AnalyzeUrl获取最终URL
**路径**: `/api/{v}/getopenurl`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 否 | 书源URL |
| url | String | 否 | 待解析URL |
| bookurl | String | 否 | 书籍URL |

**代码位置**: `ReadController.kt:615-630`

---

### SVG转PNG
**路径**: `/api/{v}/svgtopng`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| svg | String | 是 | SVG内容 |

**返回**: PNG图片数据

**代码位置**: `ReadController.kt:632-638`

---

### 通用代理请求
**路径**: `/api/{v}/listen`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 目标URL |
| header | String | 否 | 请求头JSON |

**返回**: 目标URL响应的数据流

**代码位置**: `ReadController.kt:641-673`

---

### JSON代理请求
**路径**: `/api/{v}/getjson`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 目标URL |

**代码位置**: `ReadController.kt:675-701`

---

### 图片解密代理
**路径**: `/api/{v}/imageDecode`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| book | String | 否 | 书籍JSON |
| url | String | 是 | 图片URL |
| header | String | 否 | 请求头JSON |

**返回**: 解密后的图片数据

**代码位置**: `ReadController.kt:704-779`

---

### 获取登录信息
**路径**: `/api/{v}/getLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |

**代码位置**: `ReadController.kt:781-792`

---

### 获取变量
**路径**: `/api/{v}/getVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |

**代码位置**: `ReadController.kt:794-802`

---

### 设置变量
**路径**: `/api/{v}/setVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| info | String | 否 | 变量信息JSON |

**代码位置**: `ReadController.kt:804-813`

---

### 获取书籍变量
**路径**: `/api/{v}/getbookVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookurl | String | 是 | 书籍URL |

**代码位置**: `ReadController.kt:815-822`

---

### 设置书籍变量
**路径**: `/api/{v}/setbookVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookurl | String | 是 | 书籍URL |
| info | String | 否 | 变量信息JSON |

**代码位置**: `ReadController.kt:824-832`

---

### 保存登录信息
**路径**: `/api/{v}/putLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| info | String | 否 | 登录信息JSON |

**代码位置**: `ReadController.kt:834-844`

---

### 执行书源动作
**路径**: `/api/{v}/action`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| action | String | 是 | 动作名称 |
| info | String | 否 | 动作参数 |
| chapter | Boolean | 否 | 是否章节上下文 |
| bookurl | String | 否 | 书籍URL |

**代码位置**: `ReadController.kt:847-873`

---

### 发现页执行动作
**路径**: `/api/{v}/findaction`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| action | String | 是 | 动作名称 |
| key | String | 否 | 动作键 |
| value | String | 否 | 动作值 |

**代码位置**: `ReadController.kt:876-890`

---

### 购买章节
**路径**: `/api/{v}/payAction`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |
| index | Integer | 是 | 章节索引 |

**代码位置**: `ReadController.kt:892-919`

---

### 购买章节v2
**路径**: `/api/{v}/payAction2`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookSourceUrl | String | 是 | 书源URL |
| url | String | 是 | 书籍URL |
| index | Integer | 是 | 章节索引 |

**代码位置**: `ReadController.kt:922-947`

---

### 修改书籍类型
**路径**: `/api/{v}/changebooktype`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| bookUrl | String | 是 | 书籍URL |
| type | Integer | 是 | 0:小说, 1:有声书, 2:漫画 |

**代码位置**: `ReadController.kt:950-965`

---

### 封面图片代理
**路径**: `/api/{v}/proxypng`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| url | String | 是 | 目标图片URL（无需accessToken） |

**返回**: PNG图片数据。URL格式支持 `图片URL,headerJSON` 形式附带请求头

**代码位置**: `ReadController.kt:969-1016`

---

## SourceController（21个）

### 获取书源列表(分页信息)
**路径**: `/api/{v}/getBookSourcesPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| st | String | 否 | 是否获取登录UI |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "用户书源md5+权限后缀（如 md5字符串2）"
  }
}
```

> md5 实际值为 `user.sourcemd5 + user.source`，如 `"abc1232"` 表示source=2

**代码位置**: `SourceController.kt:42-102`

---

### 获取书源列表(分页数据)
**路径**: `/api/{v}/getBookSourcesNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | 书源标识 |
| page | String | 是 | 页码 |

**代码位置**: `SourceController.kt:105-109`

---

### 检查书源权限
**路径**: `/api/{v}/getcansource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**: `isSuccess=true` 表示有权限，`isSuccess=false(CAN_NOT)` 表示无权限（user.source==0）

**代码位置**: `SourceController.kt:111-118`

---

### 保存书源
**路径**: `/api/{v}/saveBookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | JSON数组字符串(Body) |

**代码位置**: `SourceController.kt:120-144`

---

### 保存书源v2
**路径**: `/api/{v}/saveBookSourcesv2`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| group | String | 否 | 要添加的分组名 |
| source | String | 是 | 书源JSON数组字符串（普通参数） |
| urls | String | 是 | 要保存的书源URL列表JSON（普通参数） |

> v2版支持分组和URL过滤：只有urls列表中的书源才会保存，group会追加到书源分组

**代码位置**: `SourceController.kt:146-195`

---

### 保存单个书源
**路径**: `/api/{v}/saveBookSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | 书源JSON(Body) |

**代码位置**: `SourceController.kt:198-217`

---

### 书源置顶
**路径**: `/api/{v}/topSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书源URL |

**代码位置**: `SourceController.kt:220-259`

---

### 书源置底
**路径**: `/api/{v}/bottomSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书源URL |

**代码位置**: `SourceController.kt:261-299`

---

### 删除书源
**路径**: `/api/{v}/delbookSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书源URL |

**代码位置**: `SourceController.kt:301-316`

---

### 批量置顶书源
**路径**: `/api/{v}/topallSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:318-365`

---

### 批量置底书源
**路径**: `/api/{v}/bottomallSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:367-412`

---

### 修改书源分组
**路径**: `/api/{v}/editsourcegroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| st | String | 是 | 0:添加, 1:移除 |
| group | String | 是 | 分组名称 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:414-463`

---

### 批量删除书源
**路径**: `/api/{v}/delbookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:465-479`

---

### 获取书源详情
**路径**: `/api/{v}/getbookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书源URL |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "json": "书源完整JSON",
    "enabled": true,
    "bookSourceGroup": "分组",
    "enabledexplore": true
  }
}
```

**代码位置**: `SourceController.kt:481-498`

---

### 编辑书源
**路径**: `/api/{v}/editbookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | Object | 是 | 编辑内容(Body) |

**content结构**:
```json
{
  "json": "书源JSON",
  "id": "书源URL(编辑时传)"
}
```

**代码位置**: `SourceController.kt:500-565`

---

### 启用/禁用书源
**路径**: `/api/{v}/stopbookSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书源URL |
| st | String | 是 | 0:禁用, 1:启用 |

**代码位置**: `SourceController.kt:568-600`

---

### 批量禁用书源
**路径**: `/api/{v}/stopbookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:602-624`

---

### 批量启用书源
**路径**: `/api/{v}/startbookSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:626-648`

---

### 批量禁用书源发现
**路径**: `/api/{v}/stopbookSourceExplores`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:650-672`

---

### 批量启用书源发现
**路径**: `/api/{v}/startbookSourceExplores`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**代码位置**: `SourceController.kt:674-696`

---

### 获取书源JSON
**路径**: `/api/{v}/getbookSourcejson`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 书源URL列表(Body) |

**响应**:
```json
{
  "isSuccess": true,
  "data": "[书源JSON数组]"
}
```

**代码位置**: `SourceController.kt:699-719`

---

## RssController（29个）

### RSS源分页信息
**路径**: `/api/{v}/getRssSourcessPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "用户RSS md5+权限后缀"
  }
}
```

> md5 实际值为 `user.rssmd5 + user.source`

**代码位置**: `RssController.kt:59-121`

---

### RSS源分页数据
**路径**: `/api/{v}/getRssSourcessNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | RSS源标识 |
| page | String | 是 | 页码 |

**代码位置**: `RssController.kt:123-127`

---

### 获取RSS源列表
**路径**: `/api/{v}/getRssSourcess`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "sources": [
      {
        "sourceName": "订阅源名称",
        "sourceUrl": "订阅源URL",
        "sourceIcon": "图标URL",
        "sourceGroup": "分组",
        "variableComment": "变量注释",
        "loginUrl": "登录URL",
        "loginUi": "登录UI",
        "enabled": true
      }
    ],
    "can": true
  }
}
```

**代码位置**: `RssController.kt:129-180`

---

### RSS URL跳转拦截
**路径**: `/api/{v}/rssshouldOverrideUrlLoading`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| url | String | 是 | 待拦截URL |

**响应**: `isSuccess=true` 表示允许跳转，`isSuccess=false` 表示拦截

**代码位置**: `RssController.kt:182-208`

---

### 获取RSS源详情
**路径**: `/api/{v}/getRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "json": "RSS源完整JSON",
    "enabled": true,
    "sourceGroup": "分组"
  }
}
```

**代码位置**: `RssController.kt:210-226`

---

### 编辑RSS源
**路径**: `/api/{v}/editRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | Object | 是 | 编辑内容(Body) |

**content结构**:
```json
{
  "json": "RSS源JSON",
  "id": "源URL(编辑时传)"
}
```

**代码位置**: `RssController.kt:228-282`

---

### RSS源置顶
**路径**: `/api/{v}/topRssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:285-322`

---

### 批量置顶RSS源
**路径**: `/api/{v}/topallrssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:370-416`

---

### 批量置底RSS源
**路径**: `/api/{v}/bottomallrssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:324-368`

---

### RSS源置底
**路径**: `/api/{v}/bottomRssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:418-455`

---

### 修改RSS源分组
**路径**: `/api/{v}/editrsssourcegroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| st | String | 是 | 0:添加, 1:移除 |
| group | String | 是 | 分组名称 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:457-506`

---

### 删除RSS源
**路径**: `/api/{v}/delRssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:508-523`

---

### 启用/禁用RSS源
**路径**: `/api/{v}/stopRssSource`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| st | String | 是 | 0:禁用, 1:启用 |

**代码位置**: `RssController.kt:526-557`

---

### 批量启用RSS源
**路径**: `/api/{v}/startRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:559-580`

---

### 批量禁用RSS源
**路径**: `/api/{v}/stopRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:582-603`

---

### 批量删除RSS源
**路径**: `/api/{v}/delRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:605-619`

---

### 获取RSS源JSON
**路径**: `/api/{v}/getRssSourcejson`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | RSS源URL列表(Body) |

**代码位置**: `RssController.kt:621-641`

---

### 保存RSS源
**路径**: `/api/{v}/saveRssSources`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| source | String | 是 | RSS源JSON数组字符串（普通参数，非Body） |
| urls | String | 否 | URL列表JSON字符串（普通参数，非Body） |

> source 和 urls 均为普通表单/查询参数，不是 @Body

**代码位置**: `RssController.kt:643-679`

---

### 获取RSS源登录UI
**路径**: `/api/{v}/getRssSourcesloginui`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:682-701`

---

### 获取RSS类型信息
**路径**: `/api/{v}/getRssType`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "type": 0,
    "url": "默认分类URL",
    "name": "默认分类名",
    "enableJs": true,
    "js": "注入JS",
    "loginUi": "登录UI",
    "loginUrl": "登录URL",
    "contentBlacklist": "内容黑名单",
    "contentWhitelist": "内容白名单",
    "shouldOverrideUrlLoading": "URL拦截JS",
    "header": "请求头JSON"
  }
}
```

> type: 0=多分类, 1=单URL

**代码位置**: `RssController.kt:703-771`

---

### 获取RSS文章列表
**路径**: `/api/{v}/getArticles`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| sortUrl | String | 是 | 分类URL |
| sortName | String | 是 | 分类名称 |
| page | Integer | 是 | 页码 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "articles": [
      {
        "title": "文章标题",
        "link": "文章链接",
        "description": "描述",
        "pubDate": "发布时间"
      }
    ],
    "next": "下一页URL"
  }
}
```

**代码位置**: `RssController.kt:773-802`

---

### 获取RSS分类
**路径**: `/api/{v}/getRsssortUrls`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:804-846`

---

### 获取RSS文章内容
**路径**: `/api/{v}/getRssContent`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| article | String | 是 | 文章对象JSON |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "content": "文章内容HTML",
    "enableJs": true,
    "js": "注入JS",
    "header": "请求头JSON",
    "baseurl": "基础URL",
    "id": "内容缓存ID"
  }
}
```

**代码位置**: `RssController.kt:848-888`

---

### 获取RSS登录信息
**路径**: `/api/{v}/getRssLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:892-908`

---

### 保存RSS登录信息
**路径**: `/api/{v}/putRssLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| info | String | 否 | 登录信息JSON |

**代码位置**: `RssController.kt:910-925`

---

### 执行RSS动作
**路径**: `/api/{v}/rssaction`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| action | String | 是 | 动作名称 |

**代码位置**: `RssController.kt:928-948`

---

### 获取RSS变量
**路径**: `/api/{v}/getRssVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |

**代码位置**: `RssController.kt:950-963`

---

### 设置RSS变量
**路径**: `/api/{v}/setRssVariable`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | RSS源URL |
| info | String | 否 | 变量信息 |

**代码位置**: `RssController.kt:965-979`

---

### 获取RSS内容HTML
**路径**: `/api/{v}/getRssContenthtml`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | String | 是 | 缓存ID（无需accessToken） |

**返回**: HTML内容（直接输出，非JsonResponse）

**代码位置**: `RssController.kt:982-986`

---

## ReplaceRuleController（12个）

### 获取默认净化规则
**路径**: `/api/{v}/getdefaultrule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**: `data` 为配置中的默认规则字符串

**代码位置**: `ReplaceRuleController.kt:41-45`

---

### 获取替换规则分页信息
**路径**: `/api/{v}/getReplaceRulesPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "规则标识"
  }
}
```

**代码位置**: `ReplaceRuleController.kt:48-67`

---

### 获取替换规则分页数据
**路径**: `/api/{v}/getReplaceRulesNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | 规则标识 |
| page | String | 是 | 页码 |

**代码位置**: `ReplaceRuleController.kt:69-73`

---

### 添加替换规则
**路径**: `/api/{v}/addReplaceRule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| rule | Object | 是 | 规则对象(Body) |

**代码位置**: `ReplaceRuleController.kt:75-101`

---

### 规则置顶
**路径**: `/api/{v}/topReplaceRule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 规则ID |

**代码位置**: `ReplaceRuleController.kt:103-120`

---

### 删除替换规则
**路径**: `/api/{v}/delReplaceRule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 规则ID |

**代码位置**: `ReplaceRuleController.kt:122-130`

---

### 批量删除替换规则
**路径**: `/api/{v}/delReplaceRules`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 规则ID列表(Body) |

**代码位置**: `ReplaceRuleController.kt:132-146`

---

### 启用/禁用替换规则
**路径**: `/api/{v}/stopReplaceRules`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 规则ID |
| st | String | 是 | 0:禁用, 1:启用 |

**代码位置**: `ReplaceRuleController.kt:150-168`

---

### 批量禁用替换规则
**路径**: `/api/{v}/stopReplaceRulesbyIds`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 规则ID列表(Body) |

**代码位置**: `ReplaceRuleController.kt:170-182`

---

### 批量启用替换规则
**路径**: `/api/{v}/startReplaceRulesbyIds`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | 规则ID列表(Body) |

**代码位置**: `ReplaceRuleController.kt:184-196`

---

### 批量保存替换规则
**路径**: `/api/{v}/saverules`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | 规则JSON数组字符串(Body) |

**代码位置**: `ReplaceRuleController.kt:198-214`

---

### 保存单条替换规则
**路径**: `/api/{v}/saverule`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | 规则JSON(Body) |

**代码位置**: `ReplaceRuleController.kt:216-229`

---

## TTsController（13个）

### TTS分页信息
**路径**: `/api/{v}/getallttsPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "TTS标识"
  }
}
```

**代码位置**: `TTsController.kt:45-72`

---

### TTS分页数据
**路径**: `/api/{v}/getallttsNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | TTS标识 |
| page | String | 是 | 页码 |

**代码位置**: `TTsController.kt:74-78`

---

### 获取朗读引擎列表
**路径**: `/api/{v}/getalltts`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `TTsController.kt:80-96`

---

### 获取默认TTS
**路径**: `/api/{v}/getdefaulttts`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**: `data` 为配置中的默认TTS JSON字符串

**代码位置**: `TTsController.kt:98-102`

---

### 添加TTS引擎
**路径**: `/api/{v}/addtts`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| tts | Object | 是 | HttpTts对象(Body) |

> tts.id 为空时新增，非空时更新

**代码位置**: `TTsController.kt:106-130`

---

### 删除朗读引擎
**路径**: `/api/{v}/deltts`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 引擎ID |

**代码位置**: `TTsController.kt:132-140`

---

### 批量删除TTS
**路径**: `/api/{v}/delttss`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ids | List\<String\> | 是 | TTS ID列表(Body) |

**代码位置**: `TTsController.kt:142-154`

---

### 保存朗读引擎
**路径**: `/api/{v}/savettss`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | 引擎JSON数组字符串(Body) |

**代码位置**: `TTsController.kt:157-173`

---

### TTS语音合成
**路径**: `/api/{v}/tts`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 引擎ID |
| speakText | String | 是 | 要朗读的文本 |
| speechRate | Double | 否 | 语速(5-50)，默认5 |

**返回**: 音频流 (audio/mpeg)

**代码位置**: `TTsController.kt:176-199`

---

### 获取TTS登录信息
**路径**: `/api/{v}/getttsLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | TTS引擎ID |

**代码位置**: `TTsController.kt:202-213`

---

### 保存TTS登录信息
**路径**: `/api/{v}/putttsLoginInfo`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | TTS引擎ID |
| info | String | 否 | 登录信息JSON |

**代码位置**: `TTsController.kt:216-225`

---

### 执行TTS动作
**路径**: `/api/{v}/ttsaction`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | TTS引擎ID |
| action | String | 是 | 动作名称 |

**代码位置**: `TTsController.kt:227-240`

---

### 上传JSON文件
**路径**: `/api/{v}/upjson`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| content | String | 是 | JSON内容(Body) |

**响应**: `data` 为存储路径如 `"/assets/json/{md5}.json"`

**代码位置**: `TTsController.kt:242-255`

---

## BookGroupController（7个）

### 获取分组列表
**路径**: `/api/{v}/getgroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `BookGroupController.kt:38-42`

---

### 添加分组
**路径**: `/api/{v}/addgroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 是 | 分组名称 |

**代码位置**: `BookGroupController.kt:44-72`

---

### 删除分组
**路径**: `/api/{v}/delgroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 是 | 分组名称 |

**代码位置**: `BookGroupController.kt:74-90`

---

### 重命名分组
**路径**: `/api/{v}/editgroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| oldname | String | 是 | 原分组名称 |
| newname | String | 是 | 新分组名称 |

> 内置分组（未分组、有声书、漫画）不可编辑

**代码位置**: `BookGroupController.kt:92-112`

---

### 设置书籍分组
**路径**: `/api/{v}/setgroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 否 | 分组名称(空表示未分组) |
| url | String | 是 | 书籍URL |

**代码位置**: `BookGroupController.kt:114-139`

---

### 批量设置分组
**路径**: `/api/{v}/setgroups`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 否 | 分组名称 |
| ids | List\<String\> | 是 | 书籍URL列表(Body) |

**代码位置**: `BookGroupController.kt:142-169`

---

### 分组排序
**路径**: `/api/{v}/ordergroup`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| groups | String | 是 | 分组名称JSON数组字符串 |

> groups 格式为 `["分组A","分组B","分组C"]`，按数组顺序排序

**代码位置**: `BookGroupController.kt:171-190`

---

## LocalBookController（2个）

### 导入书籍预览
**路径**: `/api/{v}/importBookPreview`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| file | File | 是 | TXT/EPUB文件 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "books": {"name": "书名", "author": "作者"},
    "chapters": [{"title": "章节", "url": "URL"}]
  }
}
```

**代码位置**: `LocalBookController.kt:33-83`

---

### 上传图片
**路径**: `/api/{v}/uploadimage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| file | File | 是 | 图片文件 |

**响应**:
```json
{
  "isSuccess": true,
  "data": "http//assets/images/{md5}.png"
}
```

> 注意：当前后端实现返回值 `http//` 缺少冒号，应为 `http://`

**代码位置**: `LocalBookController.kt:85-96`

---

## GroundController（6个）

### 阅读背景分页信息
**路径**: `/api/{v}/getallgroundPage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**响应**:
```json
{
  "isSuccess": true,
  "data": {
    "page": 1,
    "md5": "背景标识"
  }
}
```

**代码位置**: `GroundController.kt:40-59`

---

### 阅读背景分页数据
**路径**: `/api/{v}/getallgroundNew`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| md5 | String | 是 | 背景标识 |
| page | String | 是 | 页码 |

**代码位置**: `GroundController.kt:61-65`

---

### 添加阅读背景
**路径**: `/api/{v}/addground`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ground | Object | 是 | 背景对象(Body) |

> errorMsg 为 `"true"` 表示需要上传背景图片，为 `"false"` 表示不需要

**代码位置**: `GroundController.kt:67-83`

---

### 删除阅读背景
**路径**: `/api/{v}/delground`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| ground | Object | 是 | 背景对象(Body)，需含name |

**代码位置**: `GroundController.kt:85-93`

---

### 获取阅读背景列表
**路径**: `/api/{v}/getallground`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |

**代码位置**: `GroundController.kt:95-99`

---

### 导入背景图片
**路径**: `/api/{v}/importground`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| file | File | 是 | 图片文件 |

**代码位置**: `GroundController.kt:101-118`

---

## BookMarkController（3个）

### 添加书签
**路径**: `/api/{v}/addbookmark`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |
| name | String | 是 | 书签名称 |
| index | Integer | 是 | 章节索引 |
| pos | Double | 是 | 章节内位置 |

**错误码**: `MARK_IS` 书签已存在

**代码位置**: `BookMarkController.kt:30-50`

---

### 获取书签
**路径**: `/api/{v}/getbookmark`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| url | String | 是 | 书籍URL |

**代码位置**: `BookMarkController.kt:53-62`

---

### 删除书签
**路径**: `/api/{v}/delbookmark`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| id | String | 是 | 书签ID |

**代码位置**: `BookMarkController.kt:64-76`

---

## ItemController（2个）

### 获取KV配置
**路径**: `/api/{v}/getitem`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 是 | 配置键名 |

**响应**: `data` 为配置值字符串，不存在时为 null

> 前端用此接口保存/获取用户配置（阅读设置、主题偏好等），实现多端同步

**代码位置**: `ItemController.kt:23-31`

---

### 保存KV配置
**路径**: `/api/{v}/setitem`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accessToken | String | 是 | 访问令牌 |
| name | String | 是 | 配置键名 |
| value | String | 是 | 配置值 |

**代码位置**: `ItemController.kt:33-43`

---

## 接口统计

| 控制器 | API数量 |
|--------|--------|
| UserController | 6 |
| BookshelfController | 4 |
| BookController | 22 |
| ReadController | 30 |
| SourceController | 21 |
| RssController | 29 |
| ReplaceRuleController | 12 |
| TTsController | 13 |
| BookGroupController | 7 |
| LocalBookController | 2 |
| GroundController | 6 |
| BookMarkController | 3 |
| ItemController | 2 |
| **总计** | **157** |

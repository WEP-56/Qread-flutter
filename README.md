### Qread Flutter

基于项目：[read](https://github.com/autobcb/read)后端制作的flutter客户端（第三方）


#### 范围

- 保持后端行为不变。
- 交付具有相同核心阅读流程的 Flutter 桌面/移动客户端。

#### 目录结构

- `lib/`: Flutter 应用程序代码
- `doc/API.md`: 后端 API 参考文档
- `doc/FEATURE_TODO.md`: 映射到页面的功能检查清单

#### 当前基准

- 书架、发现、订阅源、个人中心、搜索、阅读、书架、净化、管理员账号相关权限已部分实现，但欠缺打磨。
- Flutter 静态分析通过。

#### 运行

```bash
flutter pub get
flutter run -d windows
```

Android 端运行：

```bash
flutter run -d android
```

#### 构建可分发包体
仅制作了windows、android适配，其他设备可用性未知

#### 致谢
本项目灵感来源于 [read](https://github.com/autobcb/read)，并使用了以下优秀的开源库：
[legado](https://github.com/gedoor/legado)

#### License
MIT


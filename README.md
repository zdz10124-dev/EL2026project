# 今天吃什么

这个仓库当前保存的是 Flutter 版本的“今天吃什么”应用。

项目目录：

- `today_eat_app/`：Flutter 应用源码
- `今天吃什么.md`：需求说明

运行方式：

```bash
cd today_eat_app
flutter pub get
flutter run
```

## 三种运行方案对比

| 方案 | 命令 | 依赖 | 优缺点 |
|------|------|------|--------|
| **Android 模拟器** | `flutter run`（默认选模拟器） | Android SDK + 系统镜像 (~2-3GB) | 资源占用中等，无需额外硬件 |
| **Android 真机** | `flutter run -d <device-id>` | Android 手机 + USB 连接 | 零额外磁盘/内存开销，比模拟器流畅 |
| **Windows 桌面** | `flutter run -d windows` | Visual Studio 2022 + "使用 C++ 的桌面开发" 工作负载 | 编译产物为 `.exe`，功能完整 |

### 真机调试

USB 连接 Android 手机后，开启**开发者选项**和 **USB 调试**，然后：

```bash
flutter devices          # 查看已连接的设备 ID
flutter run -d <设备ID>  # 指定设备运行
```

### Windows 桌面（需额外安装）

安装 [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/)（Community 版免费），安装时勾选 **"使用 C++ 的桌面开发"** 工作负载。

### Android 模拟器（需额外安装）

通过 Android Studio 的 AVD Manager 创建模拟器，或使用命令行安装系统镜像后创建。

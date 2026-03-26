# Speed Volume Controller - Flutter版

## 📱 应用介绍

根据手机GPS速度实时控制蓝牙音箱音量的Android应用。

- 速度越快 → 音量越大
- 停下来 → 自动暂停播放
- 速度范围：0-200 km/h

## 🚀 快速构建

```powershell
# 1. 配置环境变量
$env:PATH = "C:\flutter\bin;" + $env:PATH
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"

# 2. 进入项目目录
cd C:\Users\Administrator\.qclaw\workspace\speed_volume_flutter

# 3. 获取依赖
flutter pub get

# 4. 构建APK
flutter build apk --release

# 5. 安装到手机
flutter install
```

## 📂 项目结构

```
speed_volume_flutter/
├── lib/
│   └── main.dart          # 主程序（UI + 逻辑）
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
└── pubspec.yaml           # 依赖配置
```

## 🔧 依赖说明

| 包 | 用途 |
|---|---|
| geolocator | GPS定位和速度获取 |
| permission_handler | 运行时权限管理 |
| volume_controller | 系统音量控制 |
| audioplayers | 音频播放 |

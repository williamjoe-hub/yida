# 衣搭（YiDa）

面向大学生的男女通用穿搭与数字衣橱 App，使用 Flutter 开发。

## 主要功能

- 根据性别、季节、天气和个人衣橱生成今日穿搭推荐
- 帽子、上衣、下装、鞋子模块化组合，任一部位可留空
- 系统衣物与用户真实衣物统一筛选：颜色、材质、款式
- 拍照或从相册导入衣服，并在设备本地完成背景处理
- 保存、命名、分享个人搭配
- 试衣间当前搭配可直接设为今日穿搭，无需先保存
- 穿搭日历与首页今日穿搭同步
- 本地化天气、性别偏好和首次使用引导

## 技术环境

- Flutter 3.x
- Dart 3.x
- Android SDK
- JDK 17
- 仅支持 ARM64（`arm64-v8a`）安卓设备

## 本地运行

```bash
flutter pub get
flutter run
```

## 构建 APK

调试包：

```bash
flutter build apk --debug
```

正式包：

```bash
flutter build apk --release
```

输出目录：`build/app/outputs/flutter-apk/`

## 项目说明

- 用户衣橱、搭配和日历数据默认保存在设备本地。
- `android/local.properties`、签名文件、构建缓存等本机内容不会提交到仓库。
- Android 应用包名：`com.dressfit.dressfit_app`

# FreeMyFinance

FreeMyFinance 是面向 Android 和 iOS 的个人记账应用，目前处于首个开发版本。

## 已实现

- 创建账户并设置初始余额；以人民币元显示，以整数分计算。
- 手动记录收入、支出、分类、日期和备注，删除账单。
- 查看账户余额、当月收支和最近账单。
- 添加账户时可填写 HTTPS 卡面图片地址；加载失败时显示默认图标。
- 可通过右上角菜单导出、恢复备份；恢复会替换当前账本，备份文件未加密。
- 账目保存在当前设备，不需要登录；卸载应用或清除应用数据可能导致数据丢失。支持导出 JSON 备份并从备份恢复；目前没有云同步或加密功能，请妥善保存备份。

图片地址由使用者自行提供，仓库不包含第三方卡面；使用前请确认图片授权。尚未集成 AirCards 目录。

## 开发

需要 Flutter SDK 和 Android SDK。iOS 构建需要 macOS 和 Xcode。

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

在此工作站，可以先运行 `. E:\DevEnv\Android\Enable-FlutterEnvironment.ps1`，再执行以上命令。

## 状态

这是开发中的版本，尚未发布；未完成真机和 iOS 构建验证。账户余额由初始余额和手工录入的账目计算，不连接银行，也不会自动同步交易。

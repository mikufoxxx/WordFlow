# GitHub Actions 自动构建和发布指南

本项目配置了两类 GitHub Actions 工作流：持续集成会在每次提交和 Pull Request
中检查代码质量；发布工作流会在版本标签推送后构建 Android APK 并创建 GitHub Release。

## 工作流总览

| 工作流 | 文件 | 触发条件 | 作用 |
| --- | --- | --- | --- |
| Verify WordFlow | `.github/workflows/ci.yml` | 推送或 PR 到 `dev` / `main`，或手动运行 | 静态分析和测试 |
| Build and Release | `.github/workflows/build-and-release.yml` | 推送 `v*.*.*` 标签，或手动运行 | 构建 APK 并创建 GitHub Release |

## 持续集成（CI）

CI 会安装依赖并运行以下质量检查：

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
```

提交 Pull Request 前，还应在本地执行格式检查：

```bash
dart format <changed Dart files>
```

只有在 CI 通过后再合并，可以更早发现静态分析和回归问题。

## Android 发布工作流

### 触发条件

1. **标签推送触发**：当推送格式为 `v*.*.*` 的标签时（如 `v1.0.0`）
2. **手动触发**：在 GitHub Actions 页面手动运行

### 构建流程

1. 检出代码
2. 设置 Java 17 环境
3. 设置 Flutter 3.27.0 稳定版
4. 获取项目依赖
5. 构建 Release APK
6. 从 pubspec.yaml 获取版本号
7. 创建 GitHub Release
8. 上传 APK 到 Release

## 使用方法

### 方法一：标签发布（推荐）

1. 更新 `pubspec.yaml` 中的版本号：
   ```yaml
   version: 1.0.1+2
   ```

2. 提交并推送代码：
   ```bash
   git add .
   git commit -m "Release v1.0.1"
   git push origin dev
   ```

3. 创建并推送标签：
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. GitHub Actions 将自动开始构建和发布流程

### 更新说明管理

GitHub Actions 支持三种方式生成更新说明：

#### 方法一：使用 CHANGELOG.md 文件（推荐）

1. 在项目根目录维护 `CHANGELOG.md` 文件
2. 按照以下格式添加版本更新内容：
   ```markdown
   ## [v1.0.1] - 2024-01-XX
   
   ### 新增功能
   - 功能描述
   
   ### 改进
   - 改进描述
   
   ### 修复
   - 修复描述
   ```
3. 发布时，Actions 会自动提取对应版本的更新内容

#### 方法二：自动从 Git 提交生成

- 如果没有 CHANGELOG.md 或找不到对应版本
- Actions 会自动使用自上个标签以来的 Git 提交信息
- 提交信息会格式化为列表形式

#### 方法三：默认更新说明

- 如果以上两种方法都无法获取内容
- 会使用默认的更新说明模板

### 方法二：手动触发

1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "Build and Release" 工作流
3. 点击 "Run workflow" 按钮
4. 选择分支并运行

## 配置要求

### 1. Android 签名密钥

发布 APK 需要在仓库 Secrets 中配置以下值：

- `SIGNING_KEY`：Android keystore 文件的 Base64 内容
- `KEY_STORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

工作流会在构建时临时创建 `android/wordflow-key.jks` 和
`android/key.properties`，不要将它们提交到仓库。

### 2. 仓库设置

确保 GitHub 仓库具有以下权限和配置：
- Actions 权限已启用
- GITHUB_TOKEN 具有创建 Release 的权限（默认已有）
- 默认开发分支为 `dev`；合并到 `main` 前也会执行 CI

## 输出文件

构建成功后，将在 GitHub Releases 中生成：
- Release 页面，包含版本信息和更新日志
- `app-release.apk` 文件，可直接下载安装

## 版本管理

- 版本号从 `pubspec.yaml` 自动读取
- 标签格式：`v{major}.{minor}.{patch}`（如 `v1.0.0`）
- Release 名称：`WordFlow v{version}`

## 故障排除

### 常见问题

1. **构建失败**：检查 Flutter 版本兼容性和依赖项
2. **权限错误**：确保 GITHUB_TOKEN 权限正确
3. **标签冲突**：确保标签名称唯一，删除重复标签后重新创建

### 查看构建日志

1. 访问 GitHub 仓库的 Actions 页面
2. 点击对应的工作流运行记录
3. 查看详细的构建日志和错误信息

## 自定义配置

可以根据需要修改 `.github/workflows/build-and-release.yml` 文件：

- 更改 Flutter 版本
- 添加代码签名
- 修改 Release 描述模板
- 添加其他构建步骤

## 注意事项

1. 首次使用前请确保所有依赖项都能正常安装
2. 建议在本地先测试构建流程：`flutter build apk --release`
3. 大型项目构建可能需要较长时间，请耐心等待
4. 确保 `pubspec.yaml` 中的版本号格式正确

# GitHub Release 发布指南

## 方式一：使用 GitHub Actions 自动发布（推荐）

### 准备工作
1. 确保你的 GitHub 仓库已创建
2. GitHub Actions 默认已启用，无需额外配置

### 发布步骤

#### 1. 创建并推送 Tag
```bash
# 创建标签（例如 v1.0.0）
git tag -a v1.0.0 -m "Release version 1.0.0"

# 推送标签到远程仓库
git push origin v1.0.0
```

#### 2. 自动构建和发布
- GitHub Actions 会自动检测到 tag 推送
- 会自动构建应用并上传到 Release 页面
- 发布内容包括：
  - `MacLauncher.app` - 应用包
  - `MacLauncher.zip` - 压缩包（方便下载）

#### 3. 查看发布结果
- 前往仓库的 **Releases** 页面
- 找到对应的版本
- 下载应用文件

---

## 方式二：手动发布

### 步骤

1. **本地打包**
   ```bash
   ./package.sh
   ```

2. **在 GitHub 上创建 Release**
   - 前往仓库页面
   - 点击右侧 **Releases**
   - 点击 **"Create a new release"**

3. **填写发布信息**
   - **Tag**: 创建新 tag，例如 `v1.0.0`
   - **Release title**: 例如 "MacLauncher v1.0.0"
   - **Description**: 填写版本说明

4. **上传文件**
   - 将 `MacLauncher.app` 或 `MacLauncher.zip` 拖拽到上传区域
   - 点击 **"Publish release"**

---

## 版本号管理建议

建议使用语义化版本号：
- **v1.0.0** - 主要版本.次要版本.补丁版本
- **v1.0.1** - 修复 bug
- **v1.1.0** - 新功能
- **v2.0.0** - 重大更新

---

## 注意事项

1. **签名问题**: GitHub Actions 中的 Ad-hoc 签名与本地签名可能不同，但都能正常运行
2. **文件大小**: `.app` 文件可能较大，建议上传 `.zip` 压缩包
3. **权限**: 确保仓库有创建 Release 的权限


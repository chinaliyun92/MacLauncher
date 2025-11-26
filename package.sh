#!/bin/bash

APP_NAME="MacLauncher"
OUTPUT_DIR="."
EXECUTABLE_PATH=".build/release/$APP_NAME"

# 1. 编译 Release 版本
echo "🔨 正在编译 Release 版本..."
swift build -c release -Xswiftc -O

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ 编译失败！找不到可执行文件: $EXECUTABLE_PATH"
    exit 1
fi

# 2. 创建目录结构
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "📦 正在创建 App Bundle: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# 2.1 生成 App Icon
if [ -f "AppIcon.png" ]; then
    echo "🎨 发现 AppIcon.png，正在生成应用图标..."
    
    mkdir -p AppIcon.iconset
    # 生成不同尺寸的图标
    sips -z 16 16     AppIcon.png --out AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     AppIcon.png --out AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   AppIcon.png --out AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   AppIcon.png --out AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   AppIcon.png --out AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
    
    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "$RESOURCES/"
    
    # 清理临时文件 (保留原始 png)
    rm -rf AppIcon.iconset AppIcon.icns
else
    echo "⚠️ 未找到 AppIcon.png，跳过图标生成。"
fi

# 3. 复制可执行文件
cp "$EXECUTABLE_PATH" "$MACOS/$APP_NAME"

# 4. 创建 Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>启动台</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>需要权限来启动其他应用程序。</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 5. 清理 & 签名
chmod +x "$MACOS/$APP_NAME"

echo "🔏 正在进行 Ad-hoc 签名..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ 打包完成！"
echo "应用位置: $APP_BUNDLE"
echo "你可以直接双击运行，或者把它拖到 Applications 文件夹。"
echo "快捷键: Control + Space 唤起/隐藏"
echo "如果无法激活窗口，请尝试赋予辅助功能权限。"

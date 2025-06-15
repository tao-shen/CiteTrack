<div align="center">
  <img src="logo.png" alt="CiteTrack Logo" width="128" height="128">
  
  # CiteTrack
  
  **A professional multilingual macOS menu bar app for monitoring Google Scholar citation counts**
  
  [![Platform](https://img.shields.io/badge/platform-macOS-blue)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/language-Swift-orange)](https://swift.org/)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
  [![Release](https://img.shields.io/github/v/release/tao-shen/CiteTrack)](https://github.com/tao-shen/CiteTrack/releases)
  
</div>

## ✨ Features

- 🔄 **Real-time Monitoring**: Automatically fetch Google Scholar citation data with customizable intervals
- 👥 **Multi-Scholar Support**: Track multiple scholars simultaneously with drag-and-drop reordering
- 🌍 **Multilingual Interface**: Support for 7 languages (English, Chinese, Japanese, Korean, Spanish, French, German)
- 🌙 **Theme Adaptation**: Menu bar icon automatically adapts to system dark/light theme
- ⚙️ **Professional Settings**: Tabbed settings interface with General and Scholar management pages
- ⚡ **Lightweight**: Only ~850KB application size
- 🔒 **Privacy First**: All data stored locally, no personal information collected

## 🌍 Language Support

CiteTrack automatically detects your system language and supports:

- 🇺🇸 **English** (Full support)
- 🇨🇳 **简体中文** (Full support)
- 🇯🇵 **日本語** (Full support)
- 🇰🇷 **한국어** (Full support)
- 🇪🇸 **Español** (Basic support)
- 🇫🇷 **Français** (Basic support)
- 🇩🇪 **Deutsch** (Basic support)

You can also manually switch languages in the settings without restarting the app.

## 📥 Download

### Latest Release

Download the latest version from our [Releases page](https://github.com/tao-shen/CiteTrack/releases/latest).

**Recommended**: Download `CiteTrack-Multilingual-v1.1.0.dmg` for the complete multilingual installer package.

### Quick Installation

1. Download the DMG file from releases
2. Open the DMG file
3. If you see a security warning, run the included bypass script
4. Drag CiteTrack.app to your Applications folder

## 🚨 Security Notice

CiteTrack uses ad-hoc code signing and is not notarized through Apple's paid developer program. This may trigger a security warning on first launch.

**This is completely normal and safe.** The app is open-source and contains no malicious code.

### Bypass Security Warning

**Method 1 - Automatic (Recommended)**
Run the included script in the DMG:
```bash
./bypass_security_warning.sh
```

**Method 2 - Manual**
- Right-click CiteTrack.app → Select "Open" → Click "Open" in the dialog
- Or run: `xattr -dr com.apple.quarantine CiteTrack.app`

## 🚀 Usage

### Getting Started
1. **First Launch**: The app will guide you to add your first scholar
2. **Add Scholar**: Enter the Google Scholar profile URL or user ID
3. **View Data**: Click the ∞ menu bar icon to see citation statistics
4. **Manage Settings**: Access settings through the menu

### Settings Interface
- **General Tab**: Configure update intervals, language, display options, and startup preferences
- **Scholars Tab**: Manage your scholar list with drag-and-drop reordering, add/remove scholars

### Scholar Management
- Add scholars using their Google Scholar profile URL or user ID
- Drag and drop to reorder scholars in your preferred sequence
- View real-time citation counts and last update timestamps
- Customize update intervals from 30 minutes to 1 week

## 🛠️ Development

### Requirements
- macOS 10.15+
- Xcode Command Line Tools
- Swift 5.0+

### Build from Source

```bash
# Clone the repository
git clone https://github.com/tao-shen/CiteTrack.git
cd CiteTrack

# Build the multilingual application
./build_multilingual.sh

# Create multilingual DMG installer
./create_multilingual_dmg.sh
```

## 📊 Technical Specifications

- **Application Size**: ~850KB
- **Installer Size**: ~988KB (DMG)
- **System Requirements**: macOS 10.15+
- **Architecture**: Universal (Intel & Apple Silicon)
- **Language**: Swift
- **Framework**: AppKit
- **Localization**: 7 languages supported

## 🔐 Privacy & Security

CiteTrack is completely safe and respects your privacy:

- ✅ **Open Source**: Full source code available for inspection
- ✅ **No Data Collection**: Zero personal information collected
- ✅ **Local Storage**: All data stored on your device
- ✅ **Minimal Permissions**: Only accesses public Google Scholar data
- ✅ **Code Signed**: Uses ad-hoc signing for integrity

The security warning appears because the app is not notarized through Apple's paid developer program ($99/year). This does not affect the app's safety or functionality.

## 🆕 What's New in v1.1.0

- 🌍 **Multilingual Support**: 7 languages with automatic detection
- 🎨 **Redesigned Settings**: Professional tabbed interface
- 🔄 **Drag & Drop**: Reorder scholars with mouse drag
- 🚀 **Startup Options**: Configure launch preferences
- 🎯 **Theme Integration**: Better system theme adaptation
- 📱 **UI Improvements**: Cleaner interface without unnecessary backgrounds

## 🤝 Contributing

We welcome contributions! Please feel free to:

- 🐛 Report bugs via [GitHub Issues](https://github.com/tao-shen/CiteTrack/issues)
- 💡 Suggest features through issues
- 🔧 Submit pull requests
- 🌍 Help with translations for additional languages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

Need help? Check out:

- [GitHub Issues](https://github.com/tao-shen/CiteTrack/issues) for bug reports and questions
- [Releases](https://github.com/tao-shen/CiteTrack/releases) for the latest downloads
- [Multilingual Features Guide](MULTILINGUAL_FEATURES.md) for detailed documentation

---

<div align="center">
  <strong>Made with ❤️ for the global academic community</strong>
  <br>
  <em>Keep track of your research impact effortlessly, in your language</em>
</div> 
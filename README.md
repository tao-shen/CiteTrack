<div align="center">
  <img src="logo.png" alt="CiteTrack Logo" width="128" height="128">
  
  # CiteTrack
  
  **A lightweight macOS menu bar app for monitoring Google Scholar citation counts**
  
  [![Platform](https://img.shields.io/badge/platform-macOS-blue)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/language-Swift-orange)](https://swift.org/)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
  [![Release](https://img.shields.io/github/v/release/tao-shen/CiteTrack)](https://github.com/tao-shen/CiteTrack/releases)
  
</div>

## ✨ Features

- 🔄 **Real-time Monitoring**: Automatically fetch Google Scholar citation data
- 👥 **Multi-Scholar Support**: Track multiple scholars simultaneously
- 🎨 **Custom Icons**: Personalize each scholar with emoji icons
- 🌙 **Theme Adaptation**: Automatically adapts to system dark/light theme
- ⚡ **Lightweight**: Only 752KB application size
- 🔒 **Privacy First**: All data stored locally, no personal information collected

## 📥 Download

### Latest Release

Download the latest version from our [Releases page](https://github.com/tao-shen/CiteTrack/releases/latest).

**Recommended**: Download `CiteTrack-v1.0.0.dmg` for the complete installer package.

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

1. **First Launch**: The app will guide you to add your first scholar
2. **Add Scholar**: Enter the Google Scholar profile URL
3. **Customize Icon**: Choose an emoji icon for each scholar
4. **View Data**: Click the menu bar icon to see citation statistics
5. **Manage Settings**: Access settings through the menu

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

# Build the application
./build_complete.sh

# Create DMG installer
./create_user_friendly_dmg.sh
```

## 📊 Technical Specifications

- **Application Size**: 752KB
- **Installer Size**: 564KB (DMG)
- **System Requirements**: macOS 10.15+
- **Architecture**: Native Apple Silicon support
- **Language**: Swift
- **Framework**: AppKit

## 🔐 Privacy & Security

CiteTrack is completely safe and respects your privacy:

- ✅ **Open Source**: Full source code available for inspection
- ✅ **No Data Collection**: Zero personal information collected
- ✅ **Local Storage**: All data stored on your device
- ✅ **Minimal Permissions**: Only accesses public Google Scholar data
- ✅ **Code Signed**: Uses ad-hoc signing for integrity

The security warning appears because the app is not notarized through Apple's paid developer program ($99/year). This does not affect the app's safety or functionality.

## 🤝 Contributing

We welcome contributions! Please feel free to:

- 🐛 Report bugs via [GitHub Issues](https://github.com/tao-shen/CiteTrack/issues)
- 💡 Suggest features through issues
- 🔧 Submit pull requests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

Need help? Check out:

- [GitHub Issues](https://github.com/tao-shen/CiteTrack/issues) for bug reports and questions
- [Releases](https://github.com/tao-shen/CiteTrack/releases) for the latest downloads

---

<div align="center">
  <strong>Made with ❤️ for the academic community</strong>
  <br>
  <em>Keep track of your research impact effortlessly</em>
</div> 
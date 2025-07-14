# CiteTrack v1.1.3 - Automatic Updates Support 🔄

## 🚀 Major Feature Release

This release introduces **automatic update functionality** powered by Sparkle framework. Now you can keep CiteTrack up-to-date effortlessly!

### ✨ New Features

#### 🔄 Automatic Updates System
- **Sparkle Integration**: Professional automatic update system used by many macOS apps
- **Check for Updates**: New menu item "Check for Updates..." in the dropdown menu
- **Automatic Checking**: App checks for updates daily automatically
- **Seamless Installation**: Download and install updates with just one click
- **Background Updates**: Updates happen smoothly without interrupting your workflow

#### 🎛️ Update Management
- **Manual Check**: Click "Check for Updates..." anytime to check manually
- **Smart Notifications**: Get notified when new versions are available
- **Release Notes**: View detailed release notes before updating
- **Safe Updates**: Automatic code signing verification ensures security

### 🎯 Why This Matters

**Before v1.1.3**: You had to manually check GitHub, download DMG, and install
**Now with v1.1.3**: CiteTrack automatically notifies you of updates and installs them with one click

### 🛠️ Technical Implementation

#### Sparkle Framework Integration
- **Industry Standard**: Uses the same update system as popular macOS apps
- **Secure**: Supports digital signature verification for safe updates
- **Efficient**: Only downloads what's needed, minimizing bandwidth usage
- **Reliable**: Robust error handling and rollback capabilities

#### Update Configuration
- **Update Feed**: `https://raw.githubusercontent.com/tao-shen/CiteTrack/main/appcast.xml`
- **Check Interval**: Daily automatic checks (configurable)
- **Version Comparison**: Smart version detection prevents downgrades
- **System Integration**: Follows macOS update best practices

### 📱 User Experience

#### Simple Update Flow
```
New version available notification appears
↓
Click "Install Update" 
↓
App downloads and installs automatically
↓
Restart with new features ready to use
```

#### Multi-language Support
- **English**: "Check for Updates..."
- **Chinese**: "检查更新..."
- **Japanese**: "アップデートを確認..."
- All 7 supported languages included

### 🔄 What's Preserved

All existing features remain fully functional:
- ✅ Elegant progress window (v1.1.2)
- ✅ Real-time data synchronization (v1.1.2)
- ✅ Copy-paste functionality fix (v1.1.1)
- ✅ 7-language multilingual interface (v1.1.0)
- ✅ Professional tabbed settings
- ✅ Drag & drop scholar reordering

### 📊 Technical Details

#### Files Modified
- **`Sources/main_localized.swift`**: Added Sparkle integration and menu item
- **`Sources/Localization.swift`**: Added "Check for Updates" localization
- **`build_multilingual.sh`**: Framework linking and code signing updates
- **`appcast.xml`**: Update feed configuration

#### New Dependencies
- **Sparkle.framework**: ~3.2MB professional update framework
- **Automatic Updates**: Complete update infrastructure

#### App Size Impact
- **Before**: 880KB (v1.1.2 without Sparkle)
- **After**: 4.1MB (includes full Sparkle framework)
- **Benefit**: Professional automatic update capability

### 📥 Download

**Download**: `CiteTrack-Multilingual-v1.1.3.dmg` (~4.1MB)

This DMG includes:
- ✅ **Automatic update system** (NEW!)
- ✅ Elegant progress window with animations
- ✅ Real-time data synchronization
- ✅ Enhanced update feedback system
- ✅ All previous features and bug fixes

### 🚀 Upgrade Instructions

1. **Download** the new DMG file
2. **Quit** the current version of CiteTrack if running
3. **Install** v1.1.3 from DMG
4. **Future Updates**: Use "Check for Updates..." menu - no more manual downloads!
5. Your settings and scholar data will be preserved

### 🧪 Test the New Feature

#### Immediate Testing
1. **Launch** CiteTrack v1.1.3
2. **Click** the menu bar ∞ icon
3. **Look for** "Check for Updates..." menu item
4. **Click it** to test the update system
5. **Verify** no error messages appear

#### What You'll See
- Update check dialog appears
- Either "No updates available" or new version notification
- Professional update interface powered by Sparkle
- Smooth, native macOS experience

### 🎯 Future Benefits

With automatic updates now in place:
- **Always Current**: Never miss important bug fixes or new features
- **Effortless**: Updates happen automatically in the background
- **Secure**: Verified downloads ensure app integrity
- **Convenient**: One-click installation process

### 🔮 What's Next

Future updates will be delivered seamlessly through this system:
- Enhanced citation tracking features
- Export and reporting functionality
- Additional data visualization
- Performance optimizations
- New language support

### 💡 Pro Tip

**Enable automatic updates** in your system preferences to get the smoothest experience. CiteTrack will notify you when updates are ready and install them with minimal user intervention.

---

**Now you can stay up-to-date automatically!** 🎉

**GitHub Repository**: [tao-shen/CiteTrack](https://github.com/tao-shen/CiteTrack)

**Report Issues**: [GitHub Issues](https://github.com/tao-shen/CiteTrack/issues)

**Full Changelog**: [v1.1.2...v1.1.3](https://github.com/tao-shen/CiteTrack/compare/v1.1.2...v1.1.3) 
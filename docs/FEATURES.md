# 🌍 CiteTrack Multilingual Features

## Overview

CiteTrack v1.1.0 and above supports a fully multilingual user interface, providing a seamless localized experience for users worldwide. The app automatically detects your system language and allows real-time language switching without restarting.

## Supported Languages

| Language           | Code     | Status         |
|--------------------|----------|---------------|
| English            | en       | ✅ Full        |
| Simplified Chinese | zh-Hans  | ✅ Full        |
| Japanese           | ja       | ✅ Full        |
| Korean             | ko       | ✅ Full        |
| Spanish            | es       | ✅ Basic       |
| French             | fr       | ✅ Basic       |
| German             | de       | ✅ Basic       |

You can manually select your preferred language in the settings window at any time.

## Key Features

### 🔄 Automatic Language Detection
- Detects your system language on first launch
- Defaults to English if the system language is not supported
- User-selected language always takes precedence over system language

### 🌐 Real-time Language Switching
- Change the app language instantly in the settings window
- No need to restart the app
- All UI elements, menus, dialogs, and error messages are updated immediately

### 📝 Complete Localization
- All menu items and button texts
- Error and status messages
- Settings window and all options
- Date and time formatting
- Dialogs and alerts

## Technical Implementation

### Localization Manager
```swift
class LocalizationManager {
    static let shared = LocalizationManager()
    
    enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh-Hans"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case french = "fr"
        case german = "de"
    }
    
    func localized(_ key: String) -> String
    func setLanguage(_ language: Language)
}
```

### Convenient Functions
```swift
// Simple localization
func L(_ key: String) -> String

// Localization with arguments
func L(_ key: String, _ args: CVarArg...)
```

### Language Change Notification
```swift
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}
```

## Usage

### 1. Automatic Detection
On first launch, the app detects your system language:
- If supported, the UI is displayed in your language
- If not supported, English is used by default
- User selection in settings always overrides system language

### 2. Real-time Switching
- Open the settings window
- Select your preferred language
- The interface updates instantly

### 3. Contributing Translations
We welcome contributions for new languages and improvements to existing translations:
1. Fork the repository
2. Add your language to `Localization.swift`
3. Test all features in the new language
4. Submit a pull request

## Known Limitations

1. **Partial Support:** Spanish, French, and German currently have basic support only
2. **System Dialogs:** Some system dialogs may still use the system language
3. **Font Support:** Some languages may require specific fonts for best display

## Future Plans

1. **Complete Translations:** Improve Spanish, French, and German coverage
2. **Add More Languages:** Consider Italian, Portuguese, Russian, etc.
3. **RTL Support:** Add right-to-left support for Arabic, Hebrew, etc.
4. **Resource Files:** Move to .strings files for easier translation management

---

**Note:** This document describes the multilingual features of CiteTrack v1.1.0 and above. Features may evolve in future releases. 
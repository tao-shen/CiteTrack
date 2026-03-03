<div align="center">
  <img src="macOS/assets/logo.png" alt="CiteTrack" width="128" height="128">
  <h1>CiteTrack</h1>
  <p>Monitor your Google Scholar citations from your iPhone, iPad, and Mac.</p>

  <a href="https://apps.apple.com/app/citetrack/id6752281652"><img src="https://img.shields.io/badge/App_Store-0D96F6?style=flat-square&logo=app-store&logoColor=white" alt="App Store"></a>
  <a href="https://github.com/tao-shen/CiteTrack/releases/latest"><img src="https://img.shields.io/github/v/release/tao-shen/CiteTrack?style=flat-square&label=release" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/tao-shen/CiteTrack?style=flat-square" alt="License"></a>
  <a href="https://github.com/tao-shen/CiteTrack/stargazers"><img src="https://img.shields.io/github/stars/tao-shen/CiteTrack?style=flat-square" alt="Stars"></a>
</div>

<br>

<div align="center">
  <img src="macOS/assets/hinton_citations_example.png" alt="CiteTrack — tracking Geoffrey Hinton's citations" width="720">
</div>

## About

CiteTrack fetches citation data from [Google Scholar](https://scholar.google.com/) and lets you track how your numbers change over time. It runs natively on iOS (SwiftUI) and macOS (AppKit), sharing a common service layer for data fetching, persistence, and sync.

Key things it does:

- **Track multiple scholars** — add anyone by profile URL or Scholar ID
- **Visualize trends** — line, bar, area, and heatmap charts with time-range filtering
- **See who cites you** — browse citing papers, filter by year/keyword/author, export to CSV or JSON
- **Stay notified** — push alerts when citation counts change
- **Sync across devices** — optional iCloud sync via CloudKit
- **Widgets** — WidgetKit home screen widgets on iOS
- **Menu bar** — lightweight macOS menu bar presence
- **7 languages** — English, Chinese, Japanese, Korean, Spanish, French, German

## Install

**App Store (recommended)** — available for [iPhone, iPad, and Mac](https://apps.apple.com/app/citetrack/id6752281652).

**macOS DMG** — download from [GitHub Releases](https://github.com/tao-shen/CiteTrack/releases/latest), open the DMG, drag to Applications.

**Build from source:**

```bash
git clone https://github.com/tao-shen/CiteTrack.git
cd CiteTrack

# macOS
xcodebuild -project macOS/CiteTrack_macOS.xcodeproj -scheme CiteTrack -configuration Release build

# iOS
xcodebuild -project iOS/CiteTrack_iOS.xcodeproj -scheme CiteTrack -configuration Release \
  -destination 'generic/platform=iOS' build
```

Requires Xcode 15+ and Swift 5.9+. iOS device deployment needs an Apple Developer account.

## Project Structure

```
CiteTrack/
├── iOS/                    SwiftUI app, WidgetKit extension
├── macOS/                  AppKit app, Sparkle auto-update
├── Shared/
│   ├── Services/           CitationFetch, GoogleScholar, CloudKitSync, Analytics, …
│   ├── Managers/           CitationManager, AppConfig, iCloudSync, …
│   ├── Models/             Scholar, CitingPaper, CitationHistory, …
│   ├── CoreData/           Persistence stack and migrations
│   └── Localization/       7 languages
├── scripts/                Build and deployment scripts
└── docs/                   Technical documentation
```

iOS uses SwiftUI; macOS uses AppKit with a custom chart engine. Both share a `Shared/` layer that handles data fetching (HTML scraping of Google Scholar), Core Data persistence, CloudKit sync, notifications, and analytics.

## Roadmap

- **Citation source tracking** — see *how* other papers cite your work, with context snippets and categorization (top priority)
- Citation trend predictions
- Collaboration network visualization
- PDF library integration

## Contributing

Bug reports, feature requests, and pull requests are welcome. Open an [issue](https://github.com/tao-shen/CiteTrack/issues) or submit a PR.

## Privacy

CiteTrack is local-first. All data is stored on-device. iCloud sync is opt-in. No account required. The app only accesses publicly available Google Scholar pages.

## License

[MIT](LICENSE)

## Author

[Tao Shen](https://github.com/tao-shen)

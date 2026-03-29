# 📱 Gift Ledger

<div align="center">

![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffinal00000000%2FGift_Ledger%2Fmaster%2Fversion.json&query=%24.version&label=version&color=blue)
![Flutter](https://img.shields.io/badge/Flutter-3.2.0-02569B?logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Web%20%7C%20iOS-lightgrey)

A simple and elegant gift money tracking app for managing social gift exchanges.
Android and Windows now support **in-app update checks**.

English | [简体中文](./README.md)

</div>

---

## 📑 Table of Contents

- [Download](#-download)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Tech Stack](#-tech-stack)
- [Changelog](#-changelog)
- [Build Guide](#-build-guide)
- [Support](#-support)

---

## 🚀 Download

| Platform | Link | Notes |
|----------|------|------|
| **Android** | [📦 APK Download](https://github.com/final00000000/Gift_Ledger/releases/latest) | Supports in-app updates; Releases only include ARMv7 / ARM64 APKs and exclude x86 / x86_64 |
| **Windows** | [📦 EXE Installer Download](https://github.com/final00000000/Gift_Ledger/releases/latest) | Recommended for upgrade and in-app installer handoff |
| **Web** | [📦 ZIP Download](https://github.com/final00000000/Gift_Ledger/releases/latest) | Deploy to static hosting |
| **iOS** | [📦 IPA Download](https://github.com/final00000000/Gift_Ledger/releases/latest) | Provides an unsigned IPA for developer-side signing or verification only; no in-app update support |

---

## ✨ Features

- **Balance Overview**: Visual stats and trend charts
- **Quick Bookkeeping**: Events, relationships, and lunar date support
- **Social Tracking**: Contacts and return-gift reminders
- **Event Books**: Organize by event with batch entry
- **Backups**: Export and import via Excel or JSON
- **App Updates**: Android and Windows support in-app checks, ignore-this-version, and red-dot reminders

Details: [docs/FEATURES_EN.md](./docs/FEATURES_EN.md)

---

## 📸 Screenshots

<details>
<summary>Click to expand screenshots</summary>

| Home | Add Record |
|:---:|:---:|
| ![Home](screenshots/home.jpg) | ![Add Record](screenshots/add_record.jpg) |

| Statistics |
|:---:|:---:|
| ![Statistics](screenshots/statistics.jpg) |

| Settings |
|:---:|
| ![Settings](screenshots/settings.jpg) |

</details>

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.2.0+
- **Language**: Dart 2.18.0+
- **Database**: SQLite (sqflite)
- **UI**: Material Design 3
- **Export**: Excel / JSON

---

## 📋 Changelog

**v1.3.2 (2026-03-26)**
- ✨ Show note previews and status markers directly in list cards
- ✨ Improve note input with multiline support, length limit, and better save flow
- ✨ Integrate update entry points in Settings / About with ignore-version and red-dot reminders
- 🐛 Fix repeated installer relaunch after cancel and stabilize Windows installer publishing
- 📦 Unify Android / Windows artifact naming, version rules, update manifest generation, and Android ABI publishing rules

**v1.2.8 (2026-02-28)**
- Add GitHub shortcut in Settings
- Upgrade build toolchain (AGP 8.9.1 / Gradle 8.11.1)

👉 [Full changelog](./CHANGELOG.md)

---

## 🔨 Build Guide

See: [docs/BUILD_EN.md](./docs/BUILD_EN.md)

---

## 💬 Support

- 🐛 [Open an Issue](https://github.com/final00000000/Gift_Ledger/issues)
- ⭐ Star the repo if this helps

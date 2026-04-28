# PromptMe

[![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-black)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A notch-first macOS teleprompter designed for confident speaking on calls, demos, and recordings.

## What It Does

PromptMe is a menu bar teleprompter that displays your scripts in the notch area of modern MacBooks. It scrolls your text automatically while you speak, keeping your eyes naturally close to the camera. The app stays out of your way until you need it, living in the menu bar with no dock icon.

Core features include:

- Smooth auto-scroll with adjustable speed
- Hover-to-pause for quick stops
- Script library with multi-prompt management
- Import and export scripts (txt, md, rtf, docx, odt, pdf)
- Voice-coupled prompting mode (speech activity influences scroll)
- Privacy mode to hide from screen captures
- Multi-display support
- Adjustable font size and overlay height

## Problem Statement

Reading scripts while on camera is awkward. You either look down at notes, break eye contact to read from a separate window, or try to memorize everything. Traditional teleprompters are expensive hardware or bulky software that take over your screen. There was no simple, unobtrusive solution that works specifically with the MacBook notch, while being free!

## Target Audience

- Content creators recording videos or streaming
- Professionals presenting demos or leading meetings
- Educators teaching online courses
- Anyone who needs to deliver scripted content while maintaining eye contact

## How It Works

PromptMe runs as a menu bar application. When you activate it, an overlay appears in your MacBook's notch area showing your selected script. You control playback from the menu bar or the overlay's top control strip.

The settings window handles script editing, library management, and configuration. Scripts persist locally between sessions. You can import existing documents or type directly into the editor.

### Workflow

1. Open settings from the menu bar
2. Create or import your script
3. Adjust scroll speed and display preferences
4. Show the overlay when ready to record or present
5. Start scrolling and speak naturally
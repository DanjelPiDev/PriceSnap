# PriceSnap

🇩🇪 **Only Germans will get this.**  
If you've ever stood in a REWE or Lidl aisle squinting at a yellow price tag wondering *"Is this actually a deal?"*, this one's for you.

A small Flutter/Dart project to learn the framework and build something practical:  
A price scanner that extracts product names and prices straight from a photo of a store label. Because saying *“I built an OCR AI tool”* sounds cooler than *“I took a photo of my receipt.”*

## Features

- **OCR-based text recognition** using Google ML Kit
- **Automatic parsing** of product names, unit prices, and totals
- **Barcode lookup** via store APIs (for when Google misreads "Knoblauchbutter" as "Knochenbruch")
- **Save & load receipts** with persistent storage (SharedPreferences)
- **Mark favorites** and swipe-to-delete entries

## Getting Started

### Prerequisites

- A device or emulator running Android  
  (No clue if this works on iPhone – I don’t have one. Good luck 🍀)

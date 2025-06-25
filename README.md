# PriceSnap

🇩🇪 **Only Germans will get this.**  
If you've ever stood in a REWE or Lidl aisle squinting at a yellow price tag wondering *"Is this actually a deal?"*, this one's for you.

A small Flutter/Dart project to learn the framework and build something practical:  
A price scanner that extracts product names and prices straight from a photo of a store label. Because saying *“I built an OCR AI tool”* sounds cooler than *“I took a photo of my receipt.”*

## What Does It Actually Do?

- Take a photo of a price tag (or receipt, or whatever you want).
- The app reads the **product name and price** automatically (using OCR).
- You can **edit results** (because OCR isn't always perfect, especially with German handwriting).
- **Save your receipts** with all recognized items, totals, store, date, and even (optionally, currently in work) GPS location.
- Mark your favorite lists, and delete old stuff with a swipe.
- Everything is stored locally on your device, so no cloud/data privacy issues (Optionally, you can export to CSV, but that's not implemented yet).

## Features

- **OCR-based text recognition** using Google ML Kit (custom models possible)
- **Automatic parsing** of product names, unit prices, and totals
- [**Barcode lookup** via store APIs (for when Google misreads "Knoblauchbutter" as "Knochenbruch")]
- **Assign each item to a store** (REWE, Lidl, Aldi, etc.)
- **Store filter & sorting** (find the best/cheapest/most expensive deals)
- **Save & load receipts** with persistent storage (SharedPreferences)
- **Mark favorites** and swipe-to-delete entries
- **Minimalist, mobile-first design**, no ads, no tracker, no nonsense

## Getting Started

### Prerequisites

- A device or emulator running Android  
  (No clue if this works on iPhone, I don’t have one. Good luck 🍀)
- Flutter SDK installed (see [flutter.dev](https://flutter.dev/docs/get-started/install))
- Some sense of adventure
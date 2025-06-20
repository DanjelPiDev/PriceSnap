# PriceSnap

A small Flutter/Dart project to learn the framework and build something practical: A item price scanner that extracts item names and prices from a photo of a product label.

## Features

- **OCR-based text recognition** using Google ML Kit
- **Automatic parsing** of item names, unit prices and totals
- **Barcode lookup** to fetch product names from store APIs (If the Google ML Kit reads in the wrong name)
- **Save & load receipts** with persistent storage (SharedPreferences)
- **Mark favorites** and swipe-to-delete entries

## Getting Started

### Prerequisites

- A device or emulator running Android (I have no iPhone, so I have no idea if this works)

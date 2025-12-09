# Word Card Generator

A Swift application for creating and exporting custom word cards with various styling options.

## Features

- **Custom Card Design**: Create word cards with customizable:
  - Text content
  - Background and text colors
  - Font styles (Elegant, Book, Apple)
  - Corner radius
  - Border color and width
  
- **Adaptive Text Sizing**: Text automatically scales to fit the card, with a minimum size of 9pt for readability

- **High-Resolution Export**: Export cards as PNG images at various DPI settings (150, 300, 600)

- **Cross-Platform**: Built with SwiftUI and supports both iOS/iPadOS and macOS

## Technical Details

- **Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Export**: CoreGraphics for high-quality PNG rendering
- **Minimum Deployment**: iOS 17.0+ / macOS 14.0+

## Card Export Specifications

- Aspect ratio: 2:1 (3 inches × 1.5 inches)
- Configurable DPI: 150, 300, or 600
- Font scaling: Adapts to content length, minimum 9pt

## Project Structure

- `WordCard.swift`: Core data model
- `CardPreviewView.swift`: SwiftUI preview component
- `CardDetailView.swift`: Detail view for individual cards
- `CardEditorView.swift`: Card editing interface
- `CardListView.swift`: Main list view of all cards
- `PNGExporter.swift`: High-resolution PNG export engine

## Usage

1. Create a new card with your desired text
2. Customize the appearance (colors, fonts, borders)
3. Preview the card in real-time
4. Export as PNG at your desired resolution
5. Share or save your card

## Recent Updates

- Added adaptive text sizing with 9pt minimum
- Improved text rendering for long content
- Enhanced cross-platform compatibility

## License

[Add your license here]

# Voice Purchase Assistant

A Flutter application that uses speech recognition and Gemini AI to capture purchase details from
voice input, convert any language to English, and store the structured data.

## Features

- Speech recognition in multiple languages
- Automatic language conversion to English using Gemini AI
- Extraction of purchase details (item name, purchase amount, amount paid, date)
- JSON conversion of speech data
- Local storage of purchase records
- Beautiful UI with voice feedback

## Setup Instructions

### Prerequisites

- Flutter SDK (3.8+)
- Android Studio / VS Code
- A Google Generative AI API key for Gemini

### Installation

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Add your Gemini API key:
    - Open `lib/services/speech_service.dart`
    - Replace `YOUR_GEMINI_API_KEY` with your actual API key

### Required Permissions

The app requires the following permissions:

- Microphone access for speech recognition
- Internet access for Gemini AI API calls

## How to Use

1. Open the app and tap the microphone button
2. Speak your purchase details in any language (e.g., "Today I bought a shirt for 500 rupees and
   paid 550 rupees")
3. The app will:
    - Convert your speech to text
    - Process the text using Gemini AI to extract structured data
    - Display the extracted details (item name, purchase amount, amount paid, date)
4. Tap "Save Purchase" to store the details
5. View your purchase history in the list below

## Technical Implementation

This app uses:

- `speech_to_text` package for voice recognition
- `google_generative_ai` package for Gemini AI integration
- `flutter_tts` package for voice feedback
- `sqflite` package for local database storage
- `intl` package for date formatting
- `permission_handler` package for permission management

## Troubleshooting

- **Speech recognition not working**: Ensure microphone permissions are granted
- **Gemini AI extraction fails**: Check your API key and internet connection
- **Languages not being translated**: Ensure the Gemini API key is valid

## License

This project is licensed under the MIT License - see the LICENSE file for details.
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String _currentLanguage = 'en-IN';

  // Initialize the TTS engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(0.5); // Slower rate for clearer speech
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Add listeners for tracking state
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((error) {
      if (kDebugMode) print("TTS Error: $error");
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    // Check if Tamil is available
    final languages = await getLanguages();
    final hasTamil = languages.any((lang) =>
        lang.toString().toLowerCase().contains('ta') ||
        lang.toString().toLowerCase().contains('tamil'));

    if (hasTamil) {
      if (kDebugMode) print("Tamil language support available");
    }

    _isInitialized = true;
    return true;
  }

  // Speak the provided text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if already speaking - cancel previous speech
    if (_isSpeaking) {
      await _flutterTts.stop();
    }

    try {
      // Auto-detect if the text is Tamil and switch language if needed
      if (_containsTamilText(text) && _currentLanguage != 'ta-IN') {
        await setLanguage('ta-IN');
      } else if (!_containsTamilText(text) && _currentLanguage != 'en-IN') {
        await setLanguage('en-IN');
      }

      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (e) {
      if (kDebugMode) print("Error speaking text: $e");
      _isSpeaking = false;
    }
  }

  // Check if text contains Tamil characters
  bool _containsTamilText(String text) {
    // Unicode range for Tamil: 0B80-0BFF
    final tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
    return tamilRegex.hasMatch(text);
  }

  // Set language (for switching between English and Tamil)
  Future<void> setLanguage(String languageCode) async {
    try {
      await _flutterTts.setLanguage(languageCode);
      _currentLanguage = languageCode;
    } catch (e) {
      if (kDebugMode) print("Error setting TTS language: $e");
      // Fallback to English if Tamil fails
      if (languageCode == 'ta-IN') {
        await _flutterTts.setLanguage('en-IN');
        _currentLanguage = 'en-IN';
      }
    }
  }

  // Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  // Format expense details into a natural language string with bilingual support
  String formatExpenseMessage(String item, double amount, {String? quantity}) {
    // Detect if we should use Tamil or English format
    bool useTamil = _containsTamilText(item);

    String message =
        useTamil ? "$item செலவு சேர்க்கப்பட்டது" : "Expense saved for $item";

    if (quantity != null && quantity.isNotEmpty) {
      message += useTamil ? ", அளவு $quantity" : " with quantity $quantity";
    }

    message += useTamil ? ", தொகை ₹$amount" : ", amount ₹$amount";

    return message;
  }

  // Get available languages
  Future<List<dynamic>> getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages;
    } catch (e) {
      if (kDebugMode) print("Error getting TTS languages: $e");
      return [];
    }
  }

  bool get isSpeaking => _isSpeaking;
}
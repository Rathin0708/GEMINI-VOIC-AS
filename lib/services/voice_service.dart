import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  StreamController<String>? _textStreamController;
  Timer? _silenceTimer;
  String _currentBuffer = '';

  // Initialize the speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (kDebugMode) print('Microphone permission denied');
      return false;
    }

    try {
      // Initialize speech to text
      _isInitialized = await _speechToText.initialize(
        onError: (error) =>
            kDebugMode ? print('Speech recognition error: $error') : null,
        onStatus: (status) =>
            kDebugMode ? print('Speech recognition status: $status') : null,
        debugLogging: kDebugMode,
      );

      return _isInitialized;
    } catch (e) {
      if (kDebugMode) print('Error initializing speech recognition: $e');
      return false;
    }
  }

  // Start listening for speech
  Future<bool> startListening({required Function(String) onResult}) async {
    try {
      // Create a stream controller if not exists
      _textStreamController ??= StreamController<String>.broadcast();

      // Clean old data
      _currentBuffer = '';

      // Setup the stream listener
      _textStreamController?.stream.listen((text) {
        if (text.isNotEmpty) {
          onResult(text);
        }
      });

      if (!_isInitialized) {
        bool initialized = await initialize();
        if (!initialized) {
          return false;
        }
      }

      _isListening = true;

      // Try native speech recognition first
      if (_speechToText.isNotListening) {
        try {
          // First, let's get available locales and try to find Tamil
          final locales = await _speechToText.locales();

          // Use Tamil and English as priority languages
          final languagePriority = [
            'ta_IN',
            'ta',
            'en_IN',
            'en_US',
            'en_GB',
            'hi_IN'
          ];
          String selectedLocale = 'en_US'; // Default fallback

          // Find best supported language
          for (var localeId in languagePriority) {
            final found = locales.any((locale) =>
                locale.localeId.toLowerCase().contains(localeId.toLowerCase()));
            if (found) {
              selectedLocale = localeId;
              break;
            }
          }

          // Try to start listening
          bool listenSuccess = false;

          // Try with selected locale
          try {
            listenSuccess = await _speechToText.listen(
                  onResult: (result) {
                    if (result.recognizedWords.isNotEmpty) {
                      _processRecognizedText(result.recognizedWords, onResult);
                    }
                  },
                  listenFor: const Duration(seconds: 30),
                  pauseFor: const Duration(seconds: 3),
                  partialResults: true,
                  listenMode: ListenMode.dictation,
                  localeId: selectedLocale,
                ) ??
                false;
          } catch (_) {
            // If selected locale fails, try without specifying locale
            listenSuccess = await _speechToText.listen(
                  onResult: (result) {
                    if (result.recognizedWords.isNotEmpty) {
                      _processRecognizedText(result.recognizedWords, onResult);
                    }
                  },
                  listenFor: const Duration(seconds: 30),
                  pauseFor: const Duration(seconds: 3),
                  partialResults: true,
                  listenMode: ListenMode.dictation,
                ) ??
                false;
          }

          _isListening = listenSuccess;
          if (!listenSuccess) {
            if (kDebugMode) print('Failed to start listening.');
            return false;
          }

        } catch (e) {
          if (kDebugMode) print('Error in speech recognition: $e');
          _isListening = false;
          return false;
        }
      }

      // Start a silence timer to detect when speech ends
      _resetSilenceTimer(onResult);

      return _isListening;
    } catch (e) {
      if (kDebugMode) print('Error in startListening: $e');
      return false;
    }
  }

  // Process recognized text with improvements for Tamil
  void _processRecognizedText(String text, Function(String) onResult) {
    // Check if the new text provides better information
    if (_currentBuffer.isEmpty) {
      _currentBuffer = text;
    } else if (text.length > _currentBuffer.length &&
        !_similarTexts(_currentBuffer, text)) {
      _currentBuffer = text; // Replace with more complete text
    } else if (text.length <= _currentBuffer.length &&
        !_currentBuffer.toLowerCase().contains(text.toLowerCase())) {
      _currentBuffer += " " + text;
    }

    // Reset silence timer as we got new text
    _resetSilenceTimer(onResult);

    // Process text for Tamil patterns
    String processedText = _processTextForTamilPatterns(_currentBuffer);

    // Send to stream
    _textStreamController?.add(processedText);
  }

  // Improved similar text detection
  bool _similarTexts(String text1, String text2) {
    text1 = text1.toLowerCase();
    text2 = text2.toLowerCase();

    // If one text fully contains the other
    if (text1.contains(text2) || text2.contains(text1)) {
      return true;
    }

    // Compare word similarity
    final words1 = text1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = text2.split(' ').where((w) => w.isNotEmpty).toSet();
    final common = words1.intersection(words2).length;
    final total = words1.union(words2).length;

    return total > 0 && common / total > 0.7;
  }

  // Enhanced Tamil pattern recognition
  String _processTextForTamilPatterns(String text) {
    // Common speech recognition errors in Tamil
    final Map<String, String> commonErrorCorrections = {
      'mango': 'மாம்பழம்',
      'mangos': 'மாம்பழம்',
      'mangoes': 'மாம்பழம்',
      'break': 'வாங்க',
      'tomato': 'தக்காளி',
      'rupees': 'ரூபாய்',
      'rupee': 'ரூபாய்',
      'buy': 'வாங்க',
      'kilo': 'கிலோ',
      'kg': 'கிலோ',
      'onion': 'வெங்காயம்',
      'potato': 'உருளைக்கிழங்கு',
      'milk': 'பால்',
      'rice': 'அரிசி',
      'dal': 'பருப்பு',
      'lentils': 'பருப்பு',
      'today': 'இன்று',
      'yesterday': 'நேற்று',
      'bought': 'வாங்கினேன்',
      'purchased': 'வாங்கினேன்',
    };

    String result = text;

    // Apply corrections
    commonErrorCorrections.forEach((english, tamil) {
      final regExp = RegExp(r'\b' + english + r'\b', caseSensitive: false);
      if (regExp.hasMatch(result.toLowerCase())) {
        result = result.replaceAllMapped(
          regExp,
          (match) => tamil,
        );
      }
    });

    return result;
  }

  void _resetSilenceTimer(Function(String) onResult) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      // When silence is detected, send the final buffer
      if (_currentBuffer.isNotEmpty) {
        final finalText = _processTextForTamilPatterns(_currentBuffer);
        onResult(finalText);
      }
    });
  }

  // Stop listening
  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speechToText.stop();
        _isListening = false;

        // Close stream
        await _textStreamController?.close();
        _textStreamController = null;

        // Cancel timer
        _silenceTimer?.cancel();
        _silenceTimer = null;
      }
    } catch (e) {
      if (kDebugMode) print('Error stopping speech recognition: $e');
    }
  }

  bool get isListening => _isListening;

  // Clean up resources
  void dispose() {
    stopListening();
    _textStreamController?.close();
    _silenceTimer?.cancel();
  }

  // Helper method to perform direct text extraction
  Future<String> _performManualTextExtraction(String audioFilePath) async {
    // This would normally call a native API or service
    // For now, we'll just return a placeholder
    return '';
  }
}
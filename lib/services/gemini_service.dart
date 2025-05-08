import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GeminiService {
  final String _apiKey;
  final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  GeminiService(this._apiKey);

  // Process speech text and extract expense details
  Future<Map<String, dynamic>?> processExpense(String speechText) async {
    try {
      // Create prompt for Gemini - optimized for accurate extraction
      final prompt = '''
You are an AI assistant that extracts detailed expense information from voice input in Tamil or English.

Input: "$speechText"

IMPORTANT: The input may have recognition errors or be incomplete, as it's coming from voice recognition. 
Try to understand the intent even if the words are slightly incorrect.

If the text is in Tamil, first translate it to English.
Then extract the following information with extreme precision:
1. Item or product name (focus on identifying the main product purchased)
2. Quantity (exact number with unit like kg, liters, pieces, etc.) 
3. Total amount in rupees (just the number)
4. Location (if mentioned)
5. Today's date (unless another date is specified)
6. Calculate price per unit if both quantity and total amount are available

IMPORTANT: Make sure to extract EXACT numbers for quantity and amount.
For Tamil numbers: ஒன்று=1, இரண்டு=2, மூன்று=3, நான்கு=4, ஐந்து=5, ஆறு=6, ஏழு=7, எட்டு=8, ஒன்பது=9, பத்து=10, இருபது=20
For Tamil money terms: ரூபாய்=rupees, காசு=money/cash, விலை=price/cost, செலவு=expense

Common Tamil patterns to recognize:
- "X கிலோ Y ரூபாய்" = "X kg for Y rupees"
- "நான் X வாங்கினேன்" = "I bought X"
- "இன்று X வாங்கினேன்" = "Today I bought X"
- "X வாங்க Y ரூபாய் கொடுத்தேன்" = "Paid Y rupees to buy X"

Example Tamil: "நேற்று மாம்பழம் இருபது கிலோ இருநூறு ரூபாய் வாங்கினேன்"
Should extract: item="மாம்பழம்(Mango)", quantity="20 கிலோ(kg)", total_amount=200

Example 2: "தக்காளி 50 காசு கொடுத்தேன்"
Should extract: item="தக்காளி(Tomato)", total_amount=50

Return ONLY a clean JSON with no extra text:
{
  "item": "product name in English",
  "quantity": "exact number with unit",
  "total_amount": number,
  "price_per_unit": "calculated price per unit",
  "location": "place of purchase (if mentioned)",
  "date": "YYYY-MM-DD format",
  "original_text": "English translation of input",
  "language_detected": "language of original input"
}
''';

      // Prepare the request body as per v1beta API format
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2, // Lower temperature for more precise responses
          'topP': 0.8,
          'topK': 40,
        }
      };

      // Make the API call with timeout
      final url = '$_baseUrl?key=$_apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('Gemini API request timed out');
          return http.Response('{"error":"timeout"}', 408);
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode)
          print(
              'Error from Gemini API: ${response.statusCode} - ${response.body}');
        return _fallbackExtraction(speechText);
      }

      // Parse the response
      final responseData = json.decode(response.body);

      // Extract text from the response structure
      final responseText =
          responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];

      if (responseText == null || responseText.isEmpty) {
        if (kDebugMode) print('Empty response from Gemini');
        return _fallbackExtraction(speechText);
      }

      // Extract JSON from the response
      String jsonStr = responseText;
      if (jsonStr.contains('{') && jsonStr.contains('}')) {
        jsonStr = jsonStr.substring(
          jsonStr.indexOf('{'),
          jsonStr.lastIndexOf('}') + 1,
        );
      }

      try {
        // Parse JSON response
        final Map<String, dynamic> data = json.decode(jsonStr);
        return _processExtractedData(data, speechText);
      } catch (jsonError) {
        if (kDebugMode) print('Error parsing JSON: $jsonError');
        return _fallbackExtraction(speechText);
      }
    } catch (e) {
      if (kDebugMode) print('Error processing with Gemini: $e');
      return _fallbackExtraction(speechText);
    }
  }

  // Process and clean up the extracted data
  Map<String, dynamic> _processExtractedData(
      Map<String, dynamic> data, String originalText) {
    // Process date - convert "today" to actual date if needed
    if (data.containsKey('date')) {
      if (data['date'] == 'today' || data['date'].toString().isEmpty) {
        data['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }
    } else {
      data['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // Ensure total_amount is numeric
    if (data.containsKey('total_amount')) {
      var amountValue = data['total_amount'];
      if (amountValue is String) {
        // Try to extract number from string like "200 rupees"
        final numericRegex = RegExp(r'\d+');
        final matches = numericRegex.allMatches(amountValue);
        if (matches.isNotEmpty) {
          amountValue = double.tryParse(matches.first.group(0) ?? '0') ?? 0.0;
          data['total_amount'] = amountValue;
        } else {
          data['total_amount'] = 0.0;
        }
      }
    } else {
      data['total_amount'] = 0.0;
    }

    // Ensure quantity is processed
    if (!data.containsKey('quantity') || data['quantity'] == null) {
      // Try to extract quantity from original text
      final quantityRegex =
          RegExp(r'(\d+)\s*(kg|kilo|kilos|kilogram|kilograms|கிலோ)');
      final matches = quantityRegex.allMatches(originalText);
      if (matches.isNotEmpty) {
        final match = matches.first;
        data['quantity'] = '${match.group(1)} kg';
      }
    }

    // Extract Tamil-specific patterns if needed
    _extractTamilPatterns(data, originalText);

    return data;
  }

  // Extract patterns specifically for Tamil
  void _extractTamilPatterns(Map<String, dynamic> data, String text) {
    // Add specific Tamil pattern matching for product names
    final productPatterns = [
      // "நான் X வாங்கினேன்" pattern (I bought X)
      RegExp(r'நான்\s+([^\s]+(?:\s+[^\s]+)?)\s+வாங்கினேன்'),
      // Common fruit/vegetable mentions
      RegExp(
          r'(மாம்பழம்|தக்காளி|வெங்காயம்|உருளைக்கிழங்கு|முட்டை|பால்|அரிசி|பருப்பு)'),
    ];

    // Try to extract product name using Tamil patterns if not already found
    if (!data.containsKey('item') ||
        data['item'] == null ||
        data['item'].toString().isEmpty) {
      for (final pattern in productPatterns) {
        final matches = pattern.allMatches(text);
        if (matches.isNotEmpty) {
          final match = matches.first;
          data['item'] = match.group(1);
          break;
        }
      }
    }

    // Enhance quantity extraction for Tamil
    final quantityPatterns = [
      // X கிலோ pattern (X kg)
      RegExp(r'(\d+)\s*(?:கிலோ|கிலோகிராம்|கிலை)'),
      // X பேக்கெட் pattern (X packet)
      RegExp(r'(\d+)\s*(?:பேக்கெட்|பாக்கெட்)'),
      // X மீட்டர் pattern (X meter)
      RegExp(r'(\d+)\s*(?:மீட்டர்)'),
      // X லிட்டர் pattern (X liter)
      RegExp(r'(\d+)\s*(?:லிட்டர்)'),
    ];

    // Try to extract quantity using Tamil patterns
    if (!data.containsKey('quantity') ||
        data['quantity'] == null ||
        data['quantity'].toString().isEmpty) {
      for (final pattern in quantityPatterns) {
        final matches = pattern.allMatches(text);
        if (matches.isNotEmpty) {
          final match = matches.first;
          final num = match.group(1) ?? '0';
          data['quantity'] = '$num kg';
          break;
        }
      }
    }

    // Extract price from Tamil expressions
    final pricePatterns = [
      // X ரூபாய் pattern (X rupees)
      RegExp(r'(\d+)\s*(?:ரூபாய்|ரூபாய்க்கு|ரூபாய்க்கு)'),
      // X காசு pattern
      RegExp(r'(\d+)\s*(?:காசு)'),
      // விலை X (price X)
      RegExp(r'விலை\s*(\d+)'),
    ];

    // Extract amount using Tamil patterns
    if (data['total_amount'] == 0.0 || data['total_amount'] == null) {
      for (final pattern in pricePatterns) {
        final matches = pattern.allMatches(text);
        if (matches.isNotEmpty) {
          final match = matches.first;
          final amountStr = match.group(1) ?? '0';
          data['total_amount'] = double.tryParse(amountStr) ?? 0.0;
          break;
        }
      }
    }
  }

  // Fallback extraction when API or JSON parsing fails
  Map<String, dynamic> _fallbackExtraction(String speechText) {
    // Basic extraction using regex patterns
    final amountRegex = RegExp(r'(\d+)\s*(?:rupees|rs|₹|ரூ|காசு)');
    final quantityRegex =
        RegExp(r'(\d+)\s*(?:kg|kilo|kilos|kilogram|kilograms|கிலோ)');
    final itemRegex = RegExp(
        r'\b(milk|oil|rice|onion|tomato|potato|பால்|அரிசி|வெங்காயம்|தக்காளி|உருளைக்கிழங்கு|மாம்பழம்)\b',
        caseSensitive: false);

    double amount = 0.0;
    String? quantity;
    String item = 'Unknown Item';

    final amountMatches = amountRegex.allMatches(speechText);
    if (amountMatches.isNotEmpty) {
      amount = double.tryParse(amountMatches.first.group(1) ?? '0') ?? 0.0;
    }

    final quantityMatches = quantityRegex.allMatches(speechText);
    if (quantityMatches.isNotEmpty) {
      quantity = '${quantityMatches.first.group(1)} kg';
    }

    final itemMatches = itemRegex.allMatches(speechText.toLowerCase());
    if (itemMatches.isNotEmpty) {
      item = itemMatches.first.group(1) ?? 'Unknown Item';
    }

    return {
      "item": item,
      "total_amount": amount,
      "quantity": quantity,
      "date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
      "original_text": speechText,
      "language_detected": "unknown"
    };
  }
}
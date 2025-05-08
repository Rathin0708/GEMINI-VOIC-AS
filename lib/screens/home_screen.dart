import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../storage/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/voice_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final VoiceService _voiceService = VoiceService();
  late GeminiService _geminiService;
  late TTSService _ttsService;
  bool _isListening = false;
  bool _isProcessing = false;
  String _recognizedText = '';
  Map<String, dynamic>? _expenseData;
  bool _showManualInputOption = false;

  String? _getApiKey() {
    return const String.fromEnvironment('AIzaSyCtCVu5CpvXwooD51LHnpZBVa_GNpSq68o');
  }

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();
    final apiKey = _getApiKey();
    if (apiKey != null) {
      _geminiService = GeminiService(apiKey);
    } else {
      _showApiKeyDialog();
    }
    _ttsService = TTSService();
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _initializeVoiceService() async {
    await _voiceService.initialize();
  }

  void _showVoiceInputDialog() {
    _voiceService.startListening(onResult: (String text) {
      setState(() {
        _textController.text = text;
        _isListening = _voiceService.isListening;
      });
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        if (!_showManualInputOption) {
          Future.microtask(() {
            setDialogState(() {
              _showManualInputOption = true;
            });
          });
        }

        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'பொருள் மற்றும் விலை / Item & Price',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_isListening) {
                    _voiceService.stopListening();
                    setDialogState(() {
                      _isListening = false;
                    });
                    setState(() {
                      _isListening = false;
                    });
                  } else {
                    setDialogState(() {
                      _isListening = true; // Show immediate feedback
                      _recognizedText = ''; // Clear previous text
                      _expenseData = null; // Clear previous data
                    });

                    _voiceService.startListening(onResult: (String text) async {
                      setDialogState(() {
                        if (_recognizedText.isEmpty ||
                            (text.length > _recognizedText.length &&
                                !_isSimilarText(_recognizedText, text))) {
                          _recognizedText = text;
                          _textController.text = _recognizedText;
                        }
                        _isListening = _voiceService.isListening;
                      });
                      // If we detect that recognition isn't working well, show a manual input option after a delay
                      if (!_isListening && _recognizedText.isEmpty) {
                        await Future.delayed(const Duration(seconds: 2));
                        setDialogState(() {
                          _showManualInputOption = true;
                        });
                      }
                    });
                  }
                },
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic,
                    color: _isListening ? Colors.red : Colors.blue),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isListening ? Colors.red : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isListening
                          ? 'குரல் பதிவு செய்கிறது... / Listening...'
                          : _isProcessing
                              ? 'AI மூலம் செயலாக்கம்... / Processing...'
                              : 'பேசவும் அல்லது தட்டச்சு செய்யவும் / Speak or type'),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 80),
                        width: double.infinity,
                        child: SingleChildScrollView(
                          child: Text(
                            _recognizedText.isEmpty
                                ? 'குரல் அல்லது டெக்ஸ்ட் பதிவை காத்திருக்கிறது... / Waiting for voice or text input...'
                                : _recognizedText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _recognizedText.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_expenseData != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text('செலவின விவரம் / Expense Details:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  _buildExpenseDataWidget(_expenseData!),
                ] else if (_showManualInputOption) ...[
                  const SizedBox(height: 10),
                  const Divider(),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'பொருள், அளவு, விலை / Item, quantity, price',
                      hintText:
                          'உ.தா: மாம்பழம் 2kg 100 ரூபாய் / E.g. Mango 2kg 100 rupees',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_isListening) {
                  _voiceService.stopListening();
                }
                _ttsService.stop();
                Navigator.of(context).pop();
              },
              child: const Text('ரத்து செய்யு / Cancel'),
            ),
            ElevatedButton(
              onPressed: _recognizedText.isNotEmpty ||
                      _textController.text.isNotEmpty
                  ? () async {
                      if (_isListening) {
                        _voiceService.stopListening();
                        setDialogState(() {
                          _isListening = false;
                        });
                      }

                      setDialogState(() {
                        _isProcessing = true;
                        if (_textController.text.isNotEmpty &&
                            _recognizedText.isEmpty) {
                          _recognizedText = _textController.text;
                        }
                      });

                      // Give audio feedback
                      _ttsService.speak(
                          "செயலாக்கம் செய்கிறேன் / Processing your expense");

                      // Process with Gemini
                      final expenseData =
                          await _geminiService.processExpense(_recognizedText);

                      setDialogState(() {
                        _isProcessing = false;
                        _expenseData = expenseData;
                      });

                      // Provide voice feedback about the result
                      if (expenseData != null) {
                        final item = expenseData['item'] ?? 'Unknown item';
                        final amount = expenseData['total_amount'] ?? 0;
                        final quantity = expenseData['quantity'];

                        String feedbackText = _ttsService.formatExpenseMessage(
                            item,
                            amount is double
                                ? amount
                                : double.parse(amount.toString()),
                            quantity: quantity);

                        _ttsService.speak(feedbackText);
                      } else {
                        _ttsService.speak(
                            "மன்னிக்கவும், எனக்கு புரியவில்லை. மீண்டும் முயற்சிக்கவும் / Sorry, I couldn't understand. Please try again.");
                      }
                    }
                  : null, // Disable if no text
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'AI மூலம் செயலாக்கவும் / Process',
                style: TextStyle(color: Colors.white),
              ),
            ),
            if (_expenseData != null)
              ElevatedButton(
                onPressed: () async {
                  // Create expense from AI data
                  final expense =
                      ExpenseModel.fromGeminiResponse(_expenseData!);
                  // Add to database
                  await HiveBoxes.addExpense(expense);

                  Navigator.of(context).pop();
                  _ttsService.speak("செலவு சேர்க்கப்பட்டது / Expense added");

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'செலவு சேர்க்கப்பட்டது: ${expense.item} - ${expense.quantity ?? ""} - ₹${expense.amount}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text(
                  'சேமிக்க / Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildExpenseDataWidget(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('பொருள் / Item', data['item'] ?? 'Unknown'),
        if (data.containsKey('quantity') && data['quantity'] != null)
          _buildDetailRow('அளவு / Quantity', data['quantity'].toString()),
        _buildDetailRow('தொகை / Amount', '${data['total_amount'] ?? 0}₹',
            isHighlighted: true),
        if (data.containsKey('price_per_unit') &&
            data['price_per_unit'] != null)
          _buildDetailRow('ஒரு அலகு விலை / Price per unit',
              data['price_per_unit'].toString()),
        if (data.containsKey('location') && data['location'] != null)
          _buildDetailRow('இடம் / Location', data['location']),
        const SizedBox(height: 10),
        const Text(
          'இது சரியாக இருக்கிறதா? இல்லையென்றால், ரத்து செய்து மீண்டும் முயற்சிக்கவும் / Does this look correct? If not, tap Cancel and try again.',
          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(
            value,
            style: isHighlighted
                ? TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade800)
                : null,
          )),
        ],
      ),
    );
  }

  void _addExpense() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final expense = ExpenseModel(
        item: text,
        amount: 100.0, // Default amount
        date: DateTime.now(),
      );

      HiveBoxes.addExpense(expense);
      _textController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('செலவு சேர்க்கப்பட்டது / Expense added'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool _isSimilarText(String text1, String text2) {
    text1 = text1.toLowerCase();
    text2 = text2.toLowerCase();

    // If one contains the other
    if (text1.contains(text2) || text2.contains(text1)) {
      return true;
    }

    // Compare word similarity
    final words1 = text1.split(' ').toSet();
    final words2 = text2.split(' ').toSet();
    final commonWords = words1.intersection(words2).length;
    final totalWords = words1.union(words2).length;

    return totalWords > 0 && commonWords / totalWords > 0.6;
  }

  void _showApiKeyDialog() {
    final TextEditingController apiKeyController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your Gemini API key to use the expense processing feature.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API key required for expense processing'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newApiKey = apiKeyController.text.trim();
              if (newApiKey.isNotEmpty) {
                setState(() {
                  _geminiService = GeminiService(newApiKey);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API key set successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid API key'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Set API Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('பேச்சு செலவு தட்டம் / Voice Expense Tracker'),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input field for expense
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: 'பொருள் பெயர் / Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _addExpense,
                      child: const Text('செலவை சேர்க்கவும் / Add Expense'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Expense list
            const Text(
              'செலவுகள் / Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable:
                    Hive.box<ExpenseModel>('expenses').listenable(),
                builder: (context, box, _) {
                  final expenses = box.values.toList().cast<ExpenseModel>();

                  if (expenses.isEmpty) {
                    return const Center(
                      child: Text('இன்னும் செலவுகள் இல்லை / No expenses yet'),
                    );
                  }

                  return ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 0),
                        child: ListTile(
                          title: Text(
                            expense.item,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy').format(expense.date),
                              ),
                              if (expense.quantity != null)
                                Text('அளவு: ${expense.quantity}'),
                              if (expense.pricePerUnit != null)
                                Text('விலை: ${expense.pricePerUnit}'),
                              if (expense.location != null)
                                Text('இடம்: ${expense.location}'),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '₹${expense.amount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showVoiceInputDialog,
        child: const Icon(Icons.mic),
      ),
    );
  }
}
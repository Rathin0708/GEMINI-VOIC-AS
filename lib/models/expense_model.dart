// This is a model for expense data
import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 0)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  final String item;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? quantity;

  @HiveField(4)
  final String? pricePerUnit;

  @HiveField(5)
  final String? location;

  @HiveField(6)
  final String? originalText;

  ExpenseModel({
    required this.item,
    required this.amount,
    required this.date,
    this.quantity,
    this.pricePerUnit,
    this.location,
    this.originalText,
  });

  // Create from Gemini response
  factory ExpenseModel.fromGeminiResponse(Map<String, dynamic> data) {
    // Parse date
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(data['date'] as String);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    // Parse amount
    double amount = 0.0;
    if (data.containsKey('total_amount')) {
      if (data['total_amount'] is num) {
        amount = (data['total_amount'] as num).toDouble();
      } else if (data['total_amount'] is String) {
        amount = double.tryParse(data['total_amount'] as String) ?? 0.0;
      }
    }

    return ExpenseModel(
      item: data['item'] as String? ?? 'Unknown Item',
      amount: amount,
      date: parsedDate,
      quantity: data['quantity'] as String?,
      pricePerUnit: data['price_per_unit'] as String?,
      location: data['location'] as String?,
      originalText: data['original_text'] as String?,
    );
  }

  // For string representation and debugging
  @override
  String toString() {
    return 'ExpenseModel(item: $item, amount: $amount, date: $date, quantity: $quantity, pricePerUnit: $pricePerUnit, location: $location, originalText: $originalText)';
  }
}
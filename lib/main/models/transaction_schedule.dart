import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionSchedule {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String type; // 'expense' or 'income'
  final DateTime startDate;
  final DateTime? endDate;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final String? description;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  TransactionSchedule({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.startDate,
    this.endDate,
    required this.frequency,
    this.description,
    required this.userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'frequency': frequency,
      'description': description,
      'userId': userId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TransactionSchedule.fromMap(Map<String, dynamic> map, String id) {
    return TransactionSchedule(
      id: id,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: map['type'] ?? 'expense',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
      frequency: map['frequency'] ?? 'monthly',
      description: map['description'],
      userId: map['userId'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  TransactionSchedule copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
    String? description,
    String? userId,
    bool? isActive,
  }) {
    return TransactionSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

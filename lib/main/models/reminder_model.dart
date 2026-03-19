import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final bool isRecurring;
  final String? frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final String category;
  final double amount;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCompleted;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.isRecurring = false,
    this.frequency,
    required this.category,
    required this.amount,
    required this.userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isCompleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'isRecurring': isRecurring,
      'frequency': frequency,
      'category': category,
      'amount': amount,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isCompleted': isCompleted,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map, String id) {
    return Reminder(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      isRecurring: map['isRecurring'] ?? false,
      frequency: map['frequency'],
      category: map['category'] ?? 'Other',
      amount: (map['amount'] ?? 0.0).toDouble(),
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    bool? isRecurring,
    String? frequency,
    String? category,
    double? amount,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

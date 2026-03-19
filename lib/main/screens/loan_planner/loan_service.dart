import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Encapsulates Firestore + business logic for creating loans.
class LoanService {
  static Future<DocumentReference<Map<String, dynamic>>> saveLoan({
    required BuildContext context,
    required String name,
    required String lender,
    required double principal,
    required double annualRate,
    required double tenureMonths,
    required double processingFee,
    required String frequency,
    required String loanType,
    required DateTime startDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save loans')),
      );
      throw Exception('User not authenticated');
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    // Ensure user doc exists
    await userRef.set({
      'exists': true,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Compute EMI and totals based on frequency
    int totalPeriods;
    double ratePerPeriod;
    switch (frequency) {
      case 'Quarterly':
        totalPeriods = (tenureMonths / 3.0).round();
        ratePerPeriod = annualRate / 4.0;
        break;
      case 'Half Yearly':
        totalPeriods = (tenureMonths / 6.0).round();
        ratePerPeriod = annualRate / 2.0;
        break;
      default: // Monthly
        totalPeriods = tenureMonths.round();
        ratePerPeriod = annualRate / 12.0;
    }

    // EMI formula: P * r * (1+r)^n / ((1+r)^n - 1)
    final r = ratePerPeriod;
    final n = totalPeriods;
    double emi = 0;
    if (r > 0 && n > 0) {
      emi = principal * r * (pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else if (r == 0) {
      emi = principal / n;
    }

    final totalPayment = emi * n;
    final totalInterest = totalPayment - principal;

    // Overall loan due date = start date + full tenure in months
    final int tenureMonthsInt = tenureMonths.round();
    final DateTime emiDueDate = _addMonths(startDate, tenureMonthsInt);

    final loanData = {
      'name': name,
      'lender': lender,
      'principal': principal,
      'annualRate': annualRate * 100,
      'tenureMonths': tenureMonths,
      'processingFee': processingFee,
      'frequency': frequency,
      'type': loanType,
      'startDate': Timestamp.fromDate(startDate),
      'emiDueDate': Timestamp.fromDate(emiDueDate),
      'computedEmi': emi,
      'computedTotalPayment': totalPayment,
      'computedTotalInterest': totalInterest,
      'status': 'Active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await userRef.collection('loans').add(loanData);
    debugPrint('Loan saved with ID: ${docRef.id}');
    return docRef;
  }
}

// Helper function for date calculations
DateTime _addMonths(DateTime from, int months) {
  final int y = from.year;
  final int m = from.month + months;
  final int year = y + ((m - 1) ~/ 12);
  final int month = ((m - 1) % 12) + 1;
  final int day = from.day;
  // Clamp to last valid day of target month
  final int lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
  final int safeDay = day <= lastDayOfTargetMonth ? day : lastDayOfTargetMonth;
  return DateTime(year, month, safeDay);
}

double pow(double base, int exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Encapsulates Firestore + business logic for saving installments
/// and marking loans as closed.
class InstallmentService {
  static Future<void> saveInstallment({
    required BuildContext context,
    required String loanName,
    required double amount,
    required DateTime instDate,
    required String paymentType,
    required String? instLoanId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save installments')),
      );
      return;
    }

    try {
      debugPrint(
          'Saving installment for loan: $loanName, amount: $amount, date: $instDate, paymentType: $paymentType, instLoanId: $instLoanId');

      // Prefer using the explicit loanId from the currently viewed loan.
      DocumentReference<Map<String, dynamic>> loanRef;
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (instLoanId != null && instLoanId.isNotEmpty) {
        loanRef = userRef.collection('loans').doc(instLoanId);
        debugPrint('Using explicit loanId for installment: ${loanRef.id}');
      } else {
        // If no explicit id, fall back to name-based match.
        final snap = await userRef
            .collection('loans')
            .where('name', isEqualTo: loanName)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          loanRef = snap.docs.first.reference;
        } else {
          // Create a minimal loan doc if it does not exist.
          loanRef = await userRef.collection('loans').add({
            'name': loanName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        debugPrint(
            'Using name-based lookup for installment, loanId: ${loanRef.id}');
      }

      final installmentData = {
        'amount': amount,
        'date': instDate,
        'paymentType': paymentType,
        'createdAt': FieldValue.serverTimestamp(),
      };
      debugPrint('Installment data: $installmentData');

      final docRef =
          await loanRef.collection('installments').add(installmentData);
      debugPrint('Installment saved with ID: ${docRef.id}');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Installment saved')));

      // After saving, check if loan should be marked closed
      // Use a batch to reduce round trips
      final batch = FirebaseFirestore.instance.batch();

      final loanSnap = await loanRef.get();
      final data = loanSnap.data();
      if (data != null) {
        final tenureMonths = (data['tenureMonths'] is num)
            ? (data['tenureMonths'] as num).toDouble()
            : 0.0;
        final freq = (data['frequency'] ?? 'Monthly') as String;
        int totalPeriods;
        switch (freq) {
          case 'Quarterly':
            totalPeriods = (tenureMonths / 3.0).round();
            break;
          case 'Half Yearly':
            totalPeriods = (tenureMonths / 6.0).round();
            break;
          default:
            totalPeriods = tenureMonths.round();
        }

        // Get current installment count more efficiently
        final instSnap = await loanRef
            .collection('installments')
            .where('paymentType', isEqualTo: 'Regular EMI')
            .get();
        final paidCount = instSnap.docs.length;
        final alreadyClosed =
            (data['status']?.toString().toLowerCase() == 'closed');
        debugPrint(
            'Confetti check: totalPeriods=$totalPeriods, paidCount=$paidCount, alreadyClosed=$alreadyClosed, loanId=${loanRef.id}');
        if (!alreadyClosed && paidCount >= totalPeriods && totalPeriods > 0) {
          debugPrint(
              'Confetti condition met! Updating loan status and triggering celebration.');

          // Batch the loan status update
          batch.update(loanRef, {
            'status': 'Closed',
            'closedAt': Timestamp.fromDate(DateTime.now()),
          });

          // Commit the batch
          await batch.commit();

          debugPrint('Loan "$loanName" marked as closed');
        } else {
          debugPrint('Loan completion condition NOT met. No status update.');
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Installment saved for "$loanName"')),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to save installment: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save installment: $e')),
      );
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main/models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize the service and check for past-due reminders
  Future<void> initialize() async {
    await completePastDueReminders();
  }

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _remindersCollection {
    return _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('reminders')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (value, _) => value,
        );
  }

  // Check if user has premium access to reminders
  Future<bool> hasPremiumAccess() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final isPremium = data['isPremium'] == true;
      final premiumFeatures = data['premiumFeatures'] as Map<String, dynamic>?;

      return isPremium || (premiumFeatures?['reminders'] == true);
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  // Add a new reminder with premium check
  Future<void> addReminder(Reminder reminder) async {
    if (!await hasPremiumAccess()) {
      throw Exception('Premium subscription required to create reminders');
    }

    final data = reminder.toMap();
    // Remove ID as Firestore will generate it
    data.remove('id');

    await _remindersCollection.add(data);
  }

  // Update an existing reminder with premium check
  Future<void> updateReminder(Reminder reminder) async {
    if (reminder.id.isEmpty) {
      throw Exception('Reminder ID is required for update');
    }

    if (!await hasPremiumAccess()) {
      throw Exception('Premium subscription required to update reminders');
    }

    final data = reminder.toMap();
    // Don't update these fields
    data.remove('id');
    data.remove('userId');
    data.remove('createdAt');

    // Update the timestamp
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _remindersCollection.doc(reminder.id).update(data);
  }

  // Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _remindersCollection.doc(reminderId).delete();
  }

  // Get all reminders for the current user
  Stream<List<Reminder>> getReminders() {
    return _remindersCollection
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reminder.fromMap(doc.data(), doc.id))
            .toList())
        .asyncMap((reminders) async {
      // Check for any past-due reminders that need to be marked as completed
      final now = DateTime.now();
      final batch = FirebaseFirestore.instance.batch();
      bool needsUpdate = false;

      for (final reminder in reminders) {
        if (!reminder.isCompleted && reminder.dateTime.isBefore(now)) {
          final docRef = _remindersCollection.doc(reminder.id);
          batch.update(docRef, {
            'isCompleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        try {
          await batch.commit();
          debugPrint('✅ Updated past-due reminders to completed status');
        } catch (e) {
          debugPrint('⚠️ Error updating past-due reminders: $e');
        }

        // Return the updated list with completed status
        return reminders
            .map((r) => !r.isCompleted && r.dateTime.isBefore(now)
                ? r.copyWith(isCompleted: true)
                : r)
            .toList();
      }

      return reminders;
    });
  }

  // Get upcoming reminders (next 7 days)
  Stream<List<Reminder>> getUpcomingReminders() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    return _remindersCollection
        .where('dateTime', isGreaterThanOrEqualTo: now)
        .where('dateTime', isLessThanOrEqualTo: nextWeek)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reminder.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Toggle reminder completion status
  Future<void> toggleReminderCompletion(Reminder reminder) async {
    if (reminder.id.isEmpty) return;

    final now = DateTime.now();
    final isPastDue = reminder.dateTime.isBefore(now);

    await _remindersCollection.doc(reminder.id).update({
      'isCompleted': !reminder.isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
      // If marking as incomplete but the reminder is past due, keep it as completed
      'isActive': !isPastDue && !reminder.isCompleted,
    });
  }

  // Helper method to mark all past-due reminders as completed
  Future<void> completePastDueReminders() async {
    try {
      final now = Timestamp.now();
      final user = _auth.currentUser;
      if (user == null) return;

      final pastDueReminders = await _remindersCollection
          .where('dateTime', isLessThan: now)
          .where('isCompleted', isEqualTo: false)
          .get(const GetOptions(source: Source.server));

      if (pastDueReminders.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in pastDueReminders.docs) {
        batch.update(doc.reference, {
          'isCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint(
          '✅ Marked ${pastDueReminders.docs.length} past due reminders as completed');
    } catch (e) {
      debugPrint('⚠️ Error completing past due reminders: $e');
    }
  }
}

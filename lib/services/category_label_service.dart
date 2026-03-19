import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryLabelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // Categories Collection Reference
  CollectionReference get _categoriesCollection => _firestore
      .collection('users')
      .doc(userId)
      .collection('categories');

  // Labels Collection Reference
  CollectionReference get _labelsCollection => _firestore
      .collection('users')
      .doc(userId)
      .collection('labels');

  // Get all categories stream
  Stream<QuerySnapshot> getCategories() {
    if (userId == null) throw Exception('User not logged in');
    return _categoriesCollection.orderBy('name').snapshots();
  }

  // Get all labels stream
  Stream<QuerySnapshot> getLabels() {
    if (userId == null) throw Exception('User not logged in');
    return _labelsCollection.orderBy('name').snapshots();
  }

  // Add a new category
  Future<void> addCategory({
    required String name,
    required String type, // 'expense', 'income', or 'both'
    String? icon,
    String? color,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    
    await _categoriesCollection.add({
      'name': name,
      'type': type,
      'icon': icon ?? 'category',
      'color': color ?? '#2196F3',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Add a new label
  Future<void> addLabel({
    required String name,
    String? color,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    
    await _labelsCollection.add({
      'name': name,
      'color': color ?? '#9E9E9E',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get category by ID
  Future<DocumentSnapshot> getCategory(String id) {
    if (userId == null) throw Exception('User not logged in');
    return _categoriesCollection.doc(id).get();
  }

  // Get label by ID
  Future<DocumentSnapshot> getLabel(String id) {
    if (userId == null) throw Exception('User not logged in');
    return _labelsCollection.doc(id).get();
  }

  // Get categories by type
  Stream<QuerySnapshot> getCategoriesByType(String type) {
    if (userId == null) throw Exception('User not logged in');
    return _categoriesCollection
        .where('type', whereIn: [type, 'both'])
        .orderBy('name')
        .snapshots();
  }

  // Update category
  Future<void> updateCategory({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    await _categoriesCollection.doc(id).update(data);
  }

  // Update label
  Future<void> updateLabel({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (userId == null) throw Exception('User not logged in');
    await _labelsCollection.doc(id).update(data);
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    if (userId == null) throw Exception('User not logged in');
    await _categoriesCollection.doc(id).delete();
  }

  // Delete label
  Future<void> deleteLabel(String id) async {
    if (userId == null) throw Exception('User not logged in');
    await _labelsCollection.doc(id).delete();
  }
}

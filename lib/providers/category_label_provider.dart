import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/category_label_service.dart';

class CategoryLabelProvider with ChangeNotifier {
  final CategoryLabelService _service = CategoryLabelService();
  
  List<DocumentSnapshot> _categories = [];
  List<DocumentSnapshot> _labels = [];
  
  List<DocumentSnapshot> get categories => _categories;
  List<DocumentSnapshot> get labels => _labels;
  
  // Initialize streams
  void initialize() {
    _service.getCategories().listen((snapshot) {
      _categories = snapshot.docs;
      notifyListeners();
    });
    
    _service.getLabels().listen((snapshot) {
      _labels = snapshot.docs;
      notifyListeners();
    });
  }
  
  // Get categories by type
  List<DocumentSnapshot> getCategoriesByType(String type) {
    return _categories.where((cat) {
      final catType = cat['type'] as String?;
      return catType == type || catType == 'both';
    }).toList();
  }
  
  // Add new category
  Future<void> addCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
  }) async {
    await _service.addCategory(
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
  }
  
  // Add new label
  Future<void> addLabel({
    required String name,
    String? color,
  }) async {
    await _service.addLabel(name: name, color: color);
  }
  
  // Update category
  Future<void> updateCategory({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _service.updateCategory(id: id, data: data);
  }
  
  // Update label
  Future<void> updateLabel({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _service.updateLabel(id: id, data: data);
  }
  
  // Delete category
  Future<void> deleteCategory(String id) async {
    await _service.deleteCategory(id);
  }
  
  // Delete label
  Future<void> deleteLabel(String id) async {
    await _service.deleteLabel(id);
  }
}

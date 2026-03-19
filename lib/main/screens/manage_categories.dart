import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _categoriesStream = _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('categories')
        .orderBy('name')
        .snapshots();
  }

  Future<void> _editCategory(DocumentSnapshot categoryDoc, String newName) async {
    if (newName.trim().isEmpty) return;
    
    try {
      await categoryDoc.reference.update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update category: $e', style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    }
  }

  Future<void> _deleteCategory(DocumentSnapshot categoryDoc) async {
    try {
      await categoryDoc.reference.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete category: $e', style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    }
  }

  void _showEditDialog(DocumentSnapshot categoryDoc) {
    final controller = TextEditingController(text: categoryDoc['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category', style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Reduced proportionally
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != categoryDoc['name']) {
                _editCategory(categoryDoc, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(fontSize: 14))); // Reduced proportionally
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data?.docs ?? [];

          if (categories.isEmpty) {
            return const Center(child: Text('No categories found', style: TextStyle(fontSize: 14))); // Reduced proportionally
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20), // Reduced proportionally
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                key: ValueKey(category.id),
                color: cs.surface.withValues(alpha: 0.9),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(10)), // Reduced from 12 proportionally
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: Icon(Icons.category_rounded, color: cs.onSurface, size: 20), // Reduced proportionally
                  title: Text(
                    category['name'],
                    style: theme.textTheme.titleSmall?.copyWith(color: cs.onSurface, fontSize: 14), // Reduced proportionally
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced proportionally
                  trailing: Wrap(spacing: 6, children: [ // Reduced from 8 proportionally
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _showEditDialog(category),
                      icon: Icon(Icons.edit_rounded, color: cs.onSurface, size: 18), // Reduced proportionally
                      padding: EdgeInsets.zero, // Reduced padding
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32), // Compact touch target
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Category?', style: TextStyle(fontSize: 18)), // Reduced proportionally
                          content: Text('Delete "${category['name']}"?', style: TextStyle(fontSize: 14)), // Reduced proportionally
                          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
                          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14)), // Reduced proportionally
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteCategory(category);
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)), // Reduced proportionally
                            ),
                          ],
                        ),
                      ),
                      icon: Icon(Icons.delete_outline_rounded, color: cs.onSurface, size: 18), // Reduced proportionally
                      padding: EdgeInsets.zero, // Reduced padding
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32), // Compact touch target
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ctrl = TextEditingController();
          final res = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add Category', style: TextStyle(fontSize: 18)), // Reduced proportionally
              content: TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  prefixIcon: Icon(Icons.category_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Reduced proportionally
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
              actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)), // Reduced proportionally
                ),
                FilledButton(
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(ctx).pop(name);
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 14)), // Reduced proportionally
                ),
              ],
            ),
          );

          if (!context.mounted) {
            ctrl.dispose();
            return;
          }

          if (res != null && res.isNotEmpty) {
            try {
              final user = _auth.currentUser;
              if (user == null) throw Exception('User not authenticated');

              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('categories')
                  .add({
                    'name': res.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add category: $e', style: TextStyle(fontSize: 13))), // Reduced proportionally
                );
              }
            }
          }
          ctrl.dispose();
        },
        icon: const Icon(Icons.add_rounded, size: 18), // Reduced proportionally
        label: const Text('Add Category', style: TextStyle(fontSize: 13)), // Reduced proportionally
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/app_input.dart';

class ManageLabelsScreen extends StatefulWidget {
  const ManageLabelsScreen({super.key});

  @override
  State<ManageLabelsScreen> createState() => _ManageLabelsScreenState();
}

class _ManageLabelsScreenState extends State<ManageLabelsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _labelsStream;
  final TextEditingController _addLabelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _labelsStream = _firestore
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .collection('labels')
        .orderBy('name')
        .snapshots();
  }

  @override
  void dispose() {
    _addLabelController.dispose();
    super.dispose();
  }

  Future<void> _addLabel() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _addLabelController.text.trim();
    if (name.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('labels')
          .add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _addLabelController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Label added',
                  style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add label: $e',
                  style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    }
  }

  Future<void> _editLabel(DocumentSnapshot labelDoc, String newName) async {
    if (newName.trim().isEmpty) return;

    try {
      await labelDoc.reference.update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update label: $e',
                  style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    }
  }

  Future<void> _deleteLabel(DocumentSnapshot labelDoc) async {
    try {
      await labelDoc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Label deleted',
                  style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete label: $e',
                  style: TextStyle(fontSize: 13))), // Reduced proportionally
        );
      }
    }
  }

  void _showEditDialog(DocumentSnapshot labelDoc) {
    final controller = TextEditingController(text: labelDoc['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Label',
            style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label Name',
            hintText: 'Enter label name',
            contentPadding: EdgeInsets.symmetric(
                horizontal: 12, vertical: 12), // Reduced proportionally
          ),
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != labelDoc['name']) {
                _editLabel(labelDoc, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(DocumentSnapshot labelDoc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Label',
            style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: Text('Are you sure you want to delete "${labelDoc['name']}"?',
            style: TextStyle(fontSize: 14)), // Reduced proportionally
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          TextButton(
            onPressed: () {
              _deleteLabel(labelDoc);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
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
        title: const Text('Manage Labels'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Add new label form
          Padding(
            padding:
                const EdgeInsets.all(12.0), // Reduced from 16 proportionally
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppInput(
                      controller: _addLabelController,
                      label: 'New Label',
                      hint: 'Enter label name',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a label name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Update the UI if needed when text changes
                        setState(() {});
                      },
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 6), // Reduced from 8 proportionally
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 4), // Align with input field
                    child: FilledButton.icon(
                      onPressed: _addLabelController.text.trim().isEmpty
                          ? null
                          : _addLabel,
                      icon: const Icon(Icons.add_rounded,
                          size: 16), // Reduced proportionally
                      label: const Text('Add',
                          style: TextStyle(
                              fontSize: 13)), // Reduced proportionally
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size(0, 44), // Reduced from 48 proportionally
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12), // Reduced proportionally
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Labels list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _labelsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style:
                            TextStyle(fontSize: 14)), // Reduced proportionally
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final labels = snapshot.data?.docs ?? [];
                if (labels.isEmpty) {
                  return const Center(
                    child: Text('No labels yet. Add your first label above!',
                        style:
                            TextStyle(fontSize: 14)), // Reduced proportionally
                  );
                }

                return ListView.builder(
                  itemCount: labels.length,
                  itemBuilder: (context, index) {
                    final label = labels[index];
                    return ListTile(
                      leading: const Icon(Icons.label_rounded,
                          size: 16), // Reduced proportionally
                      title: Text(label['name'] ?? 'Unnamed',
                          style: TextStyle(
                              fontSize: 12)), // Reduced proportionally
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3), // Reduced proportionally
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                size: 16), // Reduced proportionally
                            onPressed: () => _showEditDialog(label),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero, // Reduced padding
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28), // Compact touch target
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16), // Reduced proportionally
                            onPressed: () => _showDeleteConfirmation(label),
                            tooltip: 'Delete',
                            color: Theme.of(context).colorScheme.error,
                            padding: EdgeInsets.zero, // Reduced padding
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28), // Compact touch target
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

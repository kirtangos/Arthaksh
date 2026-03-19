import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:arthaksh/ui/app_input.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_categories.dart';
import 'package:arthaksh/providers/category_label_provider.dart';
import 'package:provider/provider.dart';
import 'manage_labels_screen.dart';
import 'package:arthaksh/notifications/notification_service.dart';
import 'package:arthaksh/widgets/premium_upsell_dialog.dart';
import '../../services/settings_service.dart';
import '../../services/currency_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen>
    with WidgetsBindingObserver {
  final _f = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _payee = TextEditingController();
  final FocusNode _payeeFocus = FocusNode();
  final _label = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isScheduled = false;
  DateTime? _scheduledTime;
  String _scheduleType = 'One-Time'; // 'One-Time', 'Weekly', 'Monthly'
  String _category = 'General';
  String _method = 'Cash';
  String _type = 'Expense';
  final List<String> _categories = <String>['General'];
  static const String _kAddNewCategory = '__ADD_NEW__';
  // Labels
  String? _selectedLabel;
  late final CategoryLabelProvider _labelProvider;

  // Cached suggestions
  final List<String> _allPayees = <String>[];

  // Currency-related state
  String _currencyCode = 'INR';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _labelProvider = Provider.of<CategoryLabelProvider>(context, listen: false);
    _labelProvider.initialize();
  }

  @override
  void initState() {
    super.initState();
    _bootstrapSuggestions();
    _loadCurrency();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _payeeFocus.dispose();
    _amount.dispose();
    _note.dispose();
    _payee.dispose();
    _label.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh currency when app becomes active (user might have changed settings)
      _loadCurrency();
    }
  }

  // Show dialog to add a new category
  Future<void> _promptAddCategory() async {
    final ctrl = TextEditingController();

    // Snapshot of existing category names to prevent duplicates
    final existingNames = <String>{
      ..._categories.map((e) => e.toLowerCase()),
      ...Provider.of<CategoryLabelProvider>(context, listen: false)
          .categories
          .map((d) => (d['name'] as String? ?? '').toLowerCase()),
    }..removeWhere((e) => e.isEmpty);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.add_rounded),
                SizedBox(width: 8),
                Text('Add New Category'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: 'Category name',
                    hintText: 'e.g., Groceries, Fuel, Rent',
                    helperText: 'For this entry type: ${_type.toLowerCase()}',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: const OutlineInputBorder(),
                    errorText: error,
                    counterText: '',
                  ),
                  onSubmitted: (value) {
                    final v = value.trim();
                    if (v.isEmpty) {
                      setD(() => error = 'Please enter a name');
                      return;
                    }
                    if (existingNames.contains(v.toLowerCase())) {
                      setD(() => error = 'Category already exists');
                      return;
                    }
                    Navigator.of(ctx).pop(v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () {
                        final v = ctrl.text.trim();
                        if (v.isEmpty) {
                          setD(() => error = 'Please enter a name');
                          return;
                        }
                        if (existingNames.contains(v.toLowerCase())) {
                          setD(() => error = 'Category already exists');
                          return;
                        }
                        setD(() => saving = true);
                        Navigator.of(ctx).pop(v);
                      },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Map current entry type to category 'type' expected by Firestore
      final mappedType = () {
        final t = _type.toLowerCase();
        if (t == 'income') return 'income';
        if (t == 'expense') return 'expense';
        return 'both'; // for transfer or others
      }();

      try {
        // Persist to Firestore
        await _labelProvider.addCategory(name: result, type: mappedType);
        // Optimistic UI update (Stream will update too)
        if (!_categories.contains(result)) {
          setState(() {
            _categories.add(result);
            _category = result;
          });
        } else {
          setState(() => _category = result);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add category: $e')),
          );
        }
      }
    }
    ctrl.dispose();
  }

  // Build label selector widget
  Widget _buildLabelSelector() {
    return Consumer<CategoryLabelProvider>(
      builder: (context, labelProvider, _) {
        final labels = labelProvider.labels;
        // Ensure unique label names to avoid duplicate DropdownMenuItem values
        final labelNames = labels
            .map((doc) => doc['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toSet() // dedupe
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        // Find the currently selected label document
        DocumentSnapshot? selectedLabelDoc;
        if (_selectedLabel != null) {
          try {
            selectedLabelDoc = labels.firstWhere(
              (doc) => doc['name'] == _selectedLabel,
            );
          } catch (e) {
            // Label not found, reset selection
            _selectedLabel = null;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedLabel,
              decoration: InputDecoration(
                labelText: 'Label (optional)',
                prefixIcon: const Icon(Icons.label_outline_rounded),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: Theme.of(context).colorScheme.primary.a * 0.6,
                        ),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.0,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.25),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(
                          alpha: Theme.of(context).colorScheme.primary.a * 0.6,
                        ),
                    width: 1.0,
                  ),
                ),
                labelStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                    fontSize: 14),
                // Inline quick actions when a label is selected
                suffixIcon: selectedLabelDoc != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit label',
                            icon: const Icon(Icons.edit_rounded,
                                size: 18), // Reduced from 20 proportionally
                            onPressed: () => _showEditLabelDialog(
                                context, selectedLabelDoc!),
                          ),
                          IconButton(
                            tooltip: 'Delete label',
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors
                                    .red), // Reduced from 20 proportionally
                            onPressed: () =>
                                _confirmDeleteLabel(context, selectedLabelDoc!),
                          ),
                        ],
                      )
                    : null,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '', // sentinel for no label
                  child: Row(
                    children: [
                      Icon(Icons.label_off_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant), // Reduced from 18 proportionally
                      const SizedBox(width: 6), // Reduced from 8 proportionally
                      Text('No Label',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14)), // Reduced proportionally
                    ],
                  ),
                ),
                ...labelNames.map((label) => DropdownMenuItem<String>(
                      value: label,
                      child: Text(label,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14)), // Reduced proportionally
                    )),
                DropdownMenuItem<String>(
                  value: '__add_new_label__',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .primary), // Reduced from 18 proportionally
                      const SizedBox(width: 6), // Reduced from 8 proportionally
                      Text('Add New Label',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14)), // Reduced proportionally
                    ],
                  ),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue == '__add_new_label__') {
                  _showAddLabelDialog(context);
                } else {
                  setState(() => _selectedLabel = newValue);
                }
              },
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
              dropdownColor: Theme.of(context).colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(12), // Reduced from 12 proportionally
              icon: Icon(Icons.arrow_drop_down_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to add a new label
  Future<void> _showAddLabelDialog(BuildContext context) async {
    final ctrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Label',
            style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12), // Reduced proportionally
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(ctx).pop({'name': value.trim()});
                }
              },
            ),
          ],
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop({'name': name});
              }
            },
            child: const Text('Add',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );

    if (result != null && result['name']?.isNotEmpty == true) {
      final context = this.context;
      final name = result['name']!;
      try {
        await _labelProvider.addLabel(name: name);
        if (!mounted) return;
        setState(() => _selectedLabel = name);
      } catch (e) {
        if (!mounted) return;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add label: $e')),
        );
      }
    }
    ctrl.dispose();
  }

  // Show dialog to edit a label
  Future<void> _showEditLabelDialog(
      BuildContext context, DocumentSnapshot labelDoc) async {
    final ctrl = TextEditingController(text: labelDoc['name']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Label',
            style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Label name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12), // Reduced proportionally
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(ctx).pop({
                    'name': value.trim(),
                    'id': labelDoc.id,
                  });
                }
              },
            ),
          ],
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop({
                  'name': name,
                  'id': labelDoc.id,
                });
              }
            },
            child: const Text('Save',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );

    if (result != null && result['name']?.isNotEmpty == true) {
      // Capture context before async operation
      final currentContext = context;
      try {
        await _labelProvider.updateLabel(
          id: result['id']!,
          data: {
            'name': result['name'],
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        if (mounted) {
          setState(() => _selectedLabel = result['name']);
        }
      } catch (e) {
        if (mounted && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Failed to update label: $e')),
          );
        }
      }
    }
    ctrl.dispose();
  }

  // Confirm before deleting a label
  Future<void> _confirmDeleteLabel(
      BuildContext context, DocumentSnapshot labelDoc) async {
    // Capture context and values before async gap
    final currentContext = context;
    final labelName = labelDoc['name'] as String?;
    final labelId = labelDoc.id;

    final confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Delete "$labelName"? This action cannot be undone.'),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced proportionally
        actionsPadding:
            const EdgeInsets.fromLTRB(12, 8, 12, 12), // Reduced proportionally
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _labelProvider.deleteLabel(labelId);
        if (!mounted) return;
        if (_selectedLabel == labelName) {
          setState(() => _selectedLabel = null);
        }
      } catch (e) {
        if (!mounted || !currentContext.mounted) return;
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Failed to delete label: $e')),
        );
      }
    }
  }

  void _showAuthRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required',
            style: TextStyle(fontSize: 18)), // Reduced proportionally
        content: const Text('You need to be logged in to perform this action.'),
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
              Navigator.pop(context);
              // Navigate to login screen
              // Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
            child: const Text('Log In',
                style: TextStyle(fontSize: 14)), // Reduced proportionally
          ),
        ],
      ),
    );
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    PremiumUpsellDialog.show(
      context,
      featureName: 'Schedule Transactions',
      description:
          'Set up recurring payments and never miss a bill again. Upgrade to Premium to unlock this feature.',
      onUpgrade: () {
        // Navigator.of(context).push(MaterialPageRoute(
        //   builder: (_) => const PremiumSubscriptionScreen(),
        // ));
      },
    );
  }

  Future<bool> _isUserPremium(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final isPremium = data['isPremium'] == true;
      final premiumFeatures = data['premiumFeatures'] is Map
          ? Map<String, dynamic>.from(data['premiumFeatures'] as Map)
          : null;

      return isPremium || (premiumFeatures?['scheduledPayments'] == true);
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  Future<void> _bootstrapSuggestions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get();
      final set = <String>{};
      for (final d in snap.docs) {
        final p = (d.data()['payeeItem'] ?? '').toString().trim();
        if (p.isNotEmpty) set.add(p);
      }
      setState(() {
        _allPayees
          ..clear()
          ..addAll(set.toList()..sort());
      });
    } catch (_) {
      // ignore silently; suggestions are optional
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Adds months to a date, handling edge cases like month ends
  DateTime _addMonths(DateTime date, int months) {
    // Get the day of the month we want to land on
    final day = date.day;

    // Add the months
    var newDate = DateTime(
      date.year + (date.month + months - 1) ~/ 12,
      (date.month + months - 1) % 12 + 1,
      1, // Start at first day of month
      date.hour,
      date.minute,
    );

    // Handle end of month cases (e.g., Jan 31 -> Feb 28/29)
    final lastDayOfMonth = DateTime(newDate.year, newDate.month + 1, 0).day;
    newDate = newDate.add(
        Duration(days: (day <= lastDayOfMonth ? day : lastDayOfMonth) - 1));

    return newDate;
  }

  void _resetAll() {
    setState(() {
      _f.currentState?.reset();
      _payee.clear();
      _amount.clear();
      _note.clear();
      _date = DateTime.now();
      _category = 'General';
      _method = 'Cash';
      _type = 'Expense';
      _selectedLabel = null;
      _isScheduled = false;
      _scheduledTime = null;
      _scheduleType = 'One-Time';
    });
  }

  Future<void> _saveScheduledExpense() async {
    if (_scheduledTime == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be logged in to schedule expenses.')),
        );
      }
      return;
    }

    try {
      final amountNum = double.parse(_amount.text.replaceAll(',', ''));
      final now = DateTime.now();
      final scheduledTime = _scheduledTime!;

      // Calculate next run time based on schedule type
      DateTime nextRun;
      if (_scheduleType == 'Weekly') {
        nextRun = scheduledTime.isBefore(now)
            ? scheduledTime.add(const Duration(days: 7))
            : scheduledTime;
      } else if (_scheduleType == 'Monthly') {
        // For monthly, we want the same date next month
        nextRun = scheduledTime.isBefore(now)
            ? _addMonths(scheduledTime, 1)
            : scheduledTime;
      } else {
        // One-Time
        nextRun = scheduledTime;
      }

      // Guard: if One-Time and nextRun already in the past or now, immediately mark as completed
      final bool isOneTime = _scheduleType == 'One-Time';
      final bool pastDueOneTime = isOneTime && !nextRun.isAfter(now);

      final data = {
        'amount': amountNum,
        'category': _category,
        'createdAt': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(_date),
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'scheduleType': _scheduleType,
        'label': _selectedLabel,
        'notes': _note.text.trim(),
        'payeeItem': _payee.text.trim(),
        'paymentMethod': _method,
        'type': _type,
        'status': pastDueOneTime ? 'completed' : 'scheduled',
        'userId': user.uid,
        'nextRun': pastDueOneTime ? null : Timestamp.fromDate(nextRun),
        'lastProcessed': pastDueOneTime ? FieldValue.serverTimestamp() : null,
        'endDate': null,
        'occurrenceCount': 0,
        'maxOccurrences': null,
        'isActive': !pastDueOneTime,
        'timezone': 'Asia/Kolkata',
        'currency': _currencyCode, // Add currency field
      };

      // Get Firestore instance
      final firestore = FirebaseFirestore.instance;

      // Save to schedules collection
      final docRef = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .add(data);

      if (!mounted) return;

      // Format date for notification
      String formattedDate;
      if (_scheduleType == 'One-Time') {
        formattedDate = DateFormat('MMM d, y').format(_scheduledTime!);
      } else if (_scheduleType == 'Weekly') {
        formattedDate = 'Every ${DateFormat('EEEE').format(_scheduledTime!)}';
      } else {
        // Monthly
        formattedDate =
            'Monthly on the ${_scheduledTime!.day}${_getDaySuffix(_scheduledTime!.day)}';
      }

      // Set notification title and body based on transaction type
      String title;
      String body;

      switch (_type) {
        case 'Income':
          title = '💰 Income Reminder !';
          body = '${_payee.text} to credit ${_amount.text} on $formattedDate';
          break;
        case 'Transfer':
          title = '🔄 Transfer Reminder!';
          body = 'Move ${_amount.text} to ${_payee.text} on $formattedDate';
          break;
        case 'Expense':
        default:
          title = '💡 Expense Reminder!';
          body =
              '${_amount.text} to be paid to ${_payee.text} on $formattedDate';
      }

      // Schedule notification only if not past-due one-time
      if (!pastDueOneTime) {
        await NotificationService.instance.scheduleExpenseNotification(
          expenseId: docRef.id,
          title: title,
          body: body,
          scheduledTime: _scheduledTime!,
          payload: {
            'type': _type.toLowerCase(),
            'amount': amountNum,
            'payee': _payee.text,
            'category': _category,
            'date': _scheduledTime!.toIso8601String(),
            'scheduleId': docRef.id, // Add scheduleId to update status later
          },
        );
      }

      // Show success message
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (!pastDueOneTime) {
          final formattedDateTime =
              DateFormat('MMM d, y hh:mm a').format(_scheduledTime!);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('$_type scheduled for $formattedDateTime'),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'One-Time schedule created and marked completed (past due time).'),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Reset form and close if needed
        _resetAll();
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving scheduled expense: $e\n$stackTrace');
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule expense. Please try again.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManageCategoriesScreen(),
      ),
    );
    // The categories will be updated automatically via the Firestore stream
    // No need to handle the return value as the stream will update the UI
  }

  Future<void> _openManageLabels() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManageLabelsScreen(),
      ),
    );
    // The labels will be updated automatically via the Firestore stream
    // No need to handle the return value as the stream will update the UI
  }

  Future<void> _loadCurrency() async {
    final code = await SettingsService.getSelectedCurrency();
    if (mounted) {
      setState(() {
        _currencyCode = code;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _date = d);
  }

  String? _vAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.replaceAll(',', ''));
    if (x == null || !x.isFinite || x <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _vNonEmpty(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;

    if (_isScheduled && _scheduledTime != null) {
      // Handle scheduled expense
      _saveScheduledExpense();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add expenses.')),
      );
      return;
    }

    try {
      final amountNum = double.parse(_amount.text.replaceAll(',', ''));
      final data = {
        'amount': amountNum,
        'category': _category,
        'createdAt': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(_date),
        'label': _selectedLabel,
        'notes': _note.text.trim(),
        'payeeItem': _payee.text.trim(),
        'paymentMethod': _method,
        'type': _type,
        'currency': _currencyCode, // Add currency field
      };

      // Ensure parent user doc exists (some security rules require it)
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.set({
        'exists': true,
        'email': user.email,
        'name': user.displayName ??
            (user.providerData.isNotEmpty
                ? user.providerData.first.displayName
                : null),
        'emailVerified': user.emailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await userRef.collection('expenses').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved')),
      );
      Navigator.of(context).maybePop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save expense: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense: $e')),
      );
    }
  }

  Future<void> _pickScheduleTime() async {
    // Check premium status
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isPremium = await _isUserPremium(user.uid);
      if (!isPremium) {
        if (!mounted) return;
        _showPremiumRequiredDialog(context);
        return;
      }
    } else {
      if (!mounted) return;
      _showAuthRequiredDialog(context);
      return;
    }

    final now = DateTime.now();

    // Show date picker
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (date == null) return;

    // Show time picker
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    // Combine date and time
    final scheduledTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Check if the scheduled time is in the future
    if (scheduledTime.isBefore(now)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Time'),
          content: const Text('Scheduled time must be in the future.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Set the scheduled state
    setState(() {
      _isScheduled = true;
      _scheduledTime = scheduledTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themed = Theme.of(context);
    final cs = themed.colorScheme;
    const double kRadius = 12.0; // Reduced from 14 proportionally

    // (Payment icons used inline in dropdown items below.)

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(kRadius)),
          borderSide: BorderSide(
              color: c, width: 1.0), // Reduced from 1.2 proportionally
        );

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 12), // Consistent with all fields
      border: border(cs.primary.withValues(alpha: 0.6)),
      enabledBorder: border(cs.primary.withValues(alpha: 0.6)),
      focusedBorder: border(cs.primary),
      prefixIconColor: cs.onSurface,
      suffixIconColor: cs.onSurface,
      labelStyle:
          TextStyle(color: cs.onSurface.withValues(alpha: 0.8), fontSize: 14),
      hintStyle:
          TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 14),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _resetAll();
      },
      child: Theme(
        data: themed.copyWith(inputDecorationTheme: inputDecorationTheme),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Add Expense'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                _resetAll();
                Navigator.of(context).maybePop();
              },
            ),
            actions: [
              // Manage Categories button
              IconButton(
                tooltip: 'Manage Categories',
                onPressed: _openManageCategories,
                icon: const Icon(Icons.category_rounded),
              ),
              // Manage Labels button
              IconButton(
                tooltip: 'Manage Labels',
                onPressed: _openManageLabels,
                icon: const Icon(Icons.label_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Builder(builder: (ctx) {
                  final cs2 = Theme.of(ctx).colorScheme;
                  return IconButton(
                    tooltip: 'Why track expenses?',
                    style: IconButton.styleFrom(backgroundColor: cs2.primary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: ctx,
                        backgroundColor: cs2.primary,
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 20), // Reduced proportionally
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        color: cs2.onPrimary),
                                    const SizedBox(
                                        width:
                                            6), // Reduced from 8 proportionally
                                    Text('Why track expenses?',
                                        style: TextStyle(
                                            color: cs2.onPrimary,
                                            fontSize:
                                                16, // Reduced from 18 proportionally
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                const SizedBox(
                                    height: 6), // Reduced from 8 proportionally
                                Text(
                                  'Adding expenses helps you monitor spending, categorize costs, and stay on budget.',
                                  style: TextStyle(
                                      color: cs2.onPrimary,
                                      height: 1.35,
                                      fontSize: 13), // Reduced proportionally
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    icon:
                        Icon(Icons.info_outline_rounded, color: cs2.onPrimary),
                  );
                }),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Card(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(
                        Radius.circular(10)), // Reduced from 12 proportionally
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12), // Reduced from 16,16 proportionally
                    child: Form(
                      key: _f,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense Details',
                            style: themed.textTheme.titleLarge?.copyWith(
                              fontSize: 18, // Reduced from 20 proportionally
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          DropdownButtonFormField<String>(
                            value: _type,
                            decoration: InputDecoration(
                              labelText: 'Type',
                              prefixIcon:
                                  const Icon(Icons.compare_arrows_rounded),
                              enabledBorder:
                                  border(cs.primary.withValues(alpha: 0.6)),
                              focusedBorder: border(cs.primary),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: border(cs.primary.withValues(alpha: 0.6)),
                            ),
                            iconEnabledColor: cs.onSurface,
                            iconDisabledColor: cs.onSurface,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Expense',
                                  child: Text('Expense',
                                      style: TextStyle(
                                          fontSize:
                                              14))), // Reduced proportionally
                              DropdownMenuItem(
                                  value: 'Income',
                                  child: Text('Income',
                                      style: TextStyle(
                                          fontSize:
                                              14))), // Reduced proportionally
                              DropdownMenuItem(
                                  value: 'Transfer',
                                  child: Text('Transfer',
                                      style: TextStyle(
                                          fontSize:
                                              14))), // Reduced proportionally
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'Expense'),
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          AppInput(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _vAmount,
                            label: 'Amount',
                            hint: '0.00',
                            prefixText: CurrencyService.getCurrencySymbol(
                                _currencyCode),
                            enabledBorderColor:
                                cs.primary.withValues(alpha: 0.6),
                            focusedBorderColor: cs.primary,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 8),
                          // Payee with smart suggestions
                          RawAutocomplete<String>(
                            optionsBuilder: (TextEditingValue tev) {
                              final q = tev.text.trim().toLowerCase();
                              if (q.isEmpty) {
                                return _allPayees.take(8);
                              }
                              return _allPayees
                                  .where((p) => p.toLowerCase().contains(q))
                                  .take(8);
                            },
                            textEditingController: _payee,
                            focusNode: _payeeFocus,
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                validator: _vNonEmpty,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Payee / Item',
                                  hintText: 'e.g., Grocery Store, Uber, Rent',
                                  prefixIcon:
                                      const Icon(Icons.shopping_bag_rounded),
                                  enabledBorder:
                                      border(cs.primary.withValues(alpha: 0.6)),
                                  focusedBorder: border(cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.25),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border:
                                      border(cs.primary.withValues(alpha: 0.6)),
                                  hintStyle: TextStyle(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6),
                                      fontSize: 14),
                                  labelStyle: TextStyle(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.8),
                                      fontSize: 14),
                                ),
                                onFieldSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              final opts = options.toList();
                              if (opts.isEmpty) return const SizedBox.shrink();
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(
                                          6)), // Reduced from 8 proportionally
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxHeight: 180,
                                        minWidth:
                                            240), // Reduced from 200,280 proportionally
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: opts.length,
                                      itemBuilder: (context, index) {
                                        final o = opts[index];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(
                                              Icons.history_rounded,
                                              size:
                                                  16), // Reduced proportionally
                                          title: Text(o,
                                              style: TextStyle(
                                                  fontSize:
                                                      12)), // Reduced proportionally
                                          onTap: () => onSelected(o),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: () {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return null;
                              return FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('categories')
                                  .orderBy('name')
                                  .snapshots();
                            }(),
                            builder: (context, snapshot) {
                              // Start with local list (includes 'General') and merge Firestore names
                              final List<String> items = [..._categories];
                              if (snapshot.hasData) {
                                for (final doc in snapshot.data!.docs) {
                                  final name = (doc.data()['name'] ?? '')
                                      .toString()
                                      .trim();
                                  if (name.isNotEmpty &&
                                      !items.contains(name)) {
                                    items.add(name);
                                  }
                                }
                              }

                              return DropdownButtonFormField<String>(
                                value: _category,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon:
                                      const Icon(Icons.category_rounded),
                                  enabledBorder:
                                      border(cs.primary.withValues(alpha: 0.6)),
                                  focusedBorder: border(cs.primary),
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.25),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border:
                                      border(cs.primary.withValues(alpha: 0.6)),
                                  labelStyle: TextStyle(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.8),
                                      fontSize: 14),
                                ),
                                iconEnabledColor: cs.onSurface,
                                iconDisabledColor: cs.onSurface,
                                items: [
                                  ...items.map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(c,
                                          style: TextStyle(
                                              fontSize:
                                                  14)), // Reduced proportionally
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: _kAddNewCategory,
                                    child: Row(
                                      children: const [
                                        Icon(Icons.add_rounded),
                                        SizedBox(
                                            width:
                                                6), // Reduced from 8 proportionally
                                        Text('Add new category',
                                            style: TextStyle(
                                                fontSize:
                                                    14)), // Reduced proportionally
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (v) async {
                                  if (v == _kAddNewCategory) {
                                    await _promptAddCategory();
                                  } else {
                                    setState(() => _category = v ?? 'General');
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          DropdownButtonFormField<String>(
                            value: _method,
                            decoration: InputDecoration(
                              labelText: 'Payment Method',
                              enabledBorder:
                                  border(cs.primary.withValues(alpha: 0.6)),
                              focusedBorder: border(cs.primary),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.25),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: border(cs.primary.withValues(alpha: 0.6)),
                              labelStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.8),
                                  fontSize: 14),
                            ),
                            iconEnabledColor: cs.onSurface,
                            iconDisabledColor: cs.onSurface,
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Row(children: [
                                  Icon(Icons.payments_rounded),
                                  SizedBox(
                                      width:
                                          6), // Reduced from 8 proportionally
                                  Text('Cash',
                                      style: TextStyle(
                                          fontSize:
                                              14)) // Reduced proportionally
                                ]),
                              ),
                              DropdownMenuItem(
                                value: 'Card',
                                child: Row(children: [
                                  Icon(Icons.credit_card_rounded),
                                  SizedBox(
                                      width:
                                          6), // Reduced from 8 proportionally
                                  Text('Card',
                                      style: TextStyle(
                                          fontSize:
                                              14)) // Reduced proportionally
                                ]),
                              ),
                              DropdownMenuItem(
                                value: 'UPI',
                                child: Row(children: [
                                  Icon(Icons.qr_code_rounded),
                                  SizedBox(
                                      width:
                                          6), // Reduced from 8 proportionally
                                  Text('UPI',
                                      style: TextStyle(
                                          fontSize:
                                              14)) // Reduced proportionally
                                ]),
                              ),
                              DropdownMenuItem(
                                value: 'Net Banking',
                                child: Row(children: [
                                  Icon(Icons.account_balance_rounded),
                                  SizedBox(
                                      width:
                                          6), // Reduced from 8 proportionally
                                  Text('Net Banking',
                                      style: TextStyle(
                                          fontSize:
                                              14)) // Reduced proportionally
                                ]),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _method = v ?? 'Cash'),
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          // Date Picker
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: const BorderRadius.all(
                                Radius.circular(
                                    12)), // Reduced from 14 proportionally
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon: const Icon(Icons.event_rounded),
                                enabledBorder:
                                    border(cs.primary.withValues(alpha: 0.6)),
                                focusedBorder: border(cs.primary),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12), // Reduced proportionally
                                border:
                                    border(cs.primary.withValues(alpha: 0.6)),
                                labelStyle: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.8),
                                    fontSize: 14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical:
                                        3), // Reduced from 4 proportionally
                                child: Text(
                                  DateFormat.yMMMd().format(_date),
                                  style: TextStyle(
                                      color: cs.onSurface, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          AppInput(
                            controller: _note,
                            label: 'Notes (optional)',
                            prefixIcon: const Icon(Icons.note_alt_rounded),
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          _buildLabelSelector(),
                          const SizedBox(
                              height: 14), // Reduced from 18 proportionally
                          // Reset Button (full width in its own row)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _resetAll,
                              style: FilledButton.styleFrom(
                                side: BorderSide(
                                  color: cs.outlineVariant,
                                  width: 1.0, // Reduced from 1.2 proportionally
                                ),
                                foregroundColor: cs.onSurfaceVariant,
                                backgroundColor: cs.surface,
                                minimumSize: const Size(
                                    0, 44), // Reduced from 48 proportionally
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14), // Reduced proportionally
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      10), // Reduced from 12 proportionally
                                ),
                                elevation: 0,
                              ),
                              icon: Icon(Icons.refresh_rounded,
                                  size: 18,
                                  color: cs
                                      .primary), // Reduced from 20 proportionally
                              label: const Text('Reset Form',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14)), // Reduced proportionally
                            ),
                          ),
                          const SizedBox(
                              height: 10), // Reduced from 12 proportionally
                          // Save and Schedule Buttons Row
                          Row(
                            children: [
                              // Schedule Button
                              if (!_isScheduled)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickScheduleTime,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.primary,
                                      side: BorderSide(
                                        color: cs.primary,
                                        width: 1.0,
                                      ),
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.schedule_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Schedule',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!_isScheduled) const SizedBox(width: 6),
                              // Save Button
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _save,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        _isScheduled ? cs.tertiary : cs.primary,
                                    foregroundColor: _isScheduled
                                        ? cs.onTertiary
                                        : cs.onPrimary,
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    _isScheduled
                                        ? Icons.schedule_rounded
                                        : Icons.save_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _isScheduled ? 'Scheduled' : 'Save',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isScheduled) const SizedBox(width: 6),
                              // Cancel/Unschedule Button
                              if (_isScheduled)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isScheduled = false;
                                        _scheduledTime = null;
                                        _scheduleType = 'One-Time';
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.error,
                                      side: BorderSide(
                                        color: cs.error,
                                        width: 1.0,
                                      ),
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

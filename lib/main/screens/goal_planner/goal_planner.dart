import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../calculator/sip_calculator.dart';
import 'package:confetti/confetti.dart';
import '../../../ui/theme_extensions.dart';
import '../../../services/settings_service.dart';
import '../../../services/currency_service.dart';
import 'new_goal_sheet.dart';
import 'add_contribution_sheet.dart';
import 'contributions_sheet.dart';
import 'edit_goal_sheet.dart';

class GoalPlannerScreen extends StatefulWidget {
  const GoalPlannerScreen({super.key});

  @override
  State<GoalPlannerScreen> createState() => _GoalPlannerScreenState();
}

class _GoalPlannerScreenState extends State<GoalPlannerScreen> {
  final _nf = NumberFormat.decimalPattern();
  late final ConfettiController _confetti;
  String _currentCurrency = 'INR';

  CollectionReference<Map<String, dynamic>> _col(User user) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals');

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _loadCurrencyAndRates();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _celebrate() {
    _confetti.play();
  }

  Future<void> _loadCurrencyAndRates() async {
    final currency = await SettingsService.getSelectedCurrency();
    if (!mounted) return;
    setState(() {
      _currentCurrency = currency;
    });

    // Ensure currency cache is initialized for conversions (used across app)
    await CurrencyService.ensureCacheInitialized();
  }

  double _convertAmount(double amount, {String originalCurrency = 'INR'}) {
    if (originalCurrency == _currentCurrency) return amount;
    return CurrencyService.convertAmountSync(
        amount, originalCurrency, _currentCurrency);
  }

  Future<void> _showCompletionPopup() async {
    final ctrl = ConfettiController(duration: const Duration(seconds: 2));
    ctrl.play();
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Stack(
          children: [
            // Soft scrim + blur background
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
            // Dialog content
            Dialog(
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Icon(Icons.emoji_events_rounded,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 10),
                        Text('Goal Completed!',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                            'Amazing work reaching your target. Keep up the momentum!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                )),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).maybePop(),
                          child: const Text('Celebrate 🎉'),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ConfettiWidget(
                        confettiController: ctrl,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.05,
                        numberOfParticles: 25,
                        gravity: 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
  }

  Future<void> _showInfo() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text('Goal Planner',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  )),
            ]),
            const SizedBox(height: 10),
            Text(
              'Create targets like Emergency Fund, Vacation, Gadget, or Education. Track your progress with contributions and get monthly suggestions to hit your target on time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    // Dynamic currency formatting based on selected currency
    final displayCurrencySymbol =
        CurrencyService.getCurrencySymbol(_currentCurrency);
    final displayCurrencyLocale =
        CurrencyService.getCurrencyLocale(_currentCurrency);
    final displayFormatter = NumberFormat.currency(
        symbol: displayCurrencySymbol,
        locale: displayCurrencyLocale,
        decimalDigits: 2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Planner'),
        actions: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: 'What is this?',
              icon: const Icon(Icons.info_outline_rounded, size: 22),
              onPressed: _showInfo,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateGoal(context),
        icon: const Icon(Icons.add_task_rounded, size: 20),
        label: const Text('New Goal', style: TextStyle(fontSize: 14)),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Intro card removed per request
                      if (user == null)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('Please log in to manage your goals.',
                              style: Theme.of(context).textTheme.bodyMedium),
                        )
                      else
                        Expanded(
                          child: StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: _col(user)
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final docs = snap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return _EmptyState(
                                    onCreate: () => _openCreateGoal(context));
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.only(
                                    bottom: 80, left: 8, right: 8),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, i) {
                                  final d = docs[i];
                                  final data = d.data();
                                  final name =
                                      (data['title'] as String?)?.trim() ??
                                          (data['name'] as String?)?.trim() ??
                                          'Untitled';
                                  final target = (data['targetAmount'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final saved = (data['currentSavings'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final ts = data['targetDate'] as Timestamp?;
                                  final targetDate = ts?.toDate();
                                  final status = (data['status'] as String?)
                                          ?.toLowerCase()
                                          .trim() ??
                                      'active';

                                  // Progress
                                  final prog = target <= 0
                                      ? 0.0
                                      : (saved / target).clamp(0.0, 1.0);
                                  final now = DateTime.now();
                                  final monthsLeft = targetDate == null
                                      ? null
                                      : ((targetDate.year - now.year) * 12 +
                                          (targetDate.month - now.month));
                                  final rem = (target - saved)
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  double? perMonth;
                                  if (monthsLeft != null && monthsLeft > 0) {
                                    perMonth = rem / monthsLeft;
                                  }

                                  // Convert amounts for display in user currency
                                  final displaySaved = _convertAmount(saved);
                                  final displayTarget = _convertAmount(target);
                                  final displayRem = _convertAmount(rem);
                                  double? displayPerMonth;
                                  if (perMonth != null) {
                                    displayPerMonth = _convertAmount(perMonth);
                                  }

                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side:
                                          BorderSide(color: cs.outlineVariant),
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(12)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title row with optional status chip
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              if (status != 'active')
                                                _statusChip(context,
                                                    status: status),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Progress bar
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(6)),
                                            child: LinearProgressIndicator(
                                              value: prog,
                                              minHeight: 8,
                                              backgroundColor: cs
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Amounts row: Saved / Target / Remaining
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Saved',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall),
                                                    Text(
                                                        displayFormatter.format(
                                                            displaySaved),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text('Target',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall),
                                                    Text(
                                                        displayFormatter.format(
                                                            displayTarget),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text('Remaining',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall),
                                                    Text(
                                                        displayFormatter
                                                            .format(displayRem),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Optional due date and monthly suggestion
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              if (targetDate != null)
                                                Text(
                                                    'By ${DateFormat.yMMMd().format(targetDate)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              if (perMonth != null)
                                                Text(
                                                    'Suggest: ${displayFormatter.format(displayPerMonth!)} / month',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                            color: cs.primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Actions
                                          SizedBox(
                                            height: 40,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: IconButton(
                                                    tooltip: 'Add contribution',
                                                    onPressed: () =>
                                                        _openAddContribution(
                                                            context,
                                                            d.reference),
                                                    icon: const Icon(
                                                        Icons.add_card_rounded,
                                                        size: 18),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: IconButton(
                                                    tooltip: 'History',
                                                    onPressed: () =>
                                                        _openContributions(
                                                            context,
                                                            d.reference,
                                                            name,
                                                            target),
                                                    icon: const Icon(
                                                        Icons.history_rounded,
                                                        size: 18),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: IconButton(
                                                    tooltip: 'Edit goal',
                                                    onPressed: () =>
                                                        _openEditGoal(context,
                                                            d.reference, data),
                                                    icon: const Icon(
                                                        Icons.edit_rounded,
                                                        size: 18),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: IconButton(
                                                    tooltip: 'Plan via SIP',
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                            builder: (_) =>
                                                                const SIPCalculatorScreen()),
                                                      );
                                                    },
                                                    icon: const Icon(
                                                        Icons
                                                            .ssid_chart_rounded,
                                                        size: 18),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.05,
                  numberOfParticles: 30,
                  gravity: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, {required String status}) {
    final cs = Theme.of(context).colorScheme;
    final success = Theme.of(context).extension<SuccessColors>();
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'completed':
        bg = (success?.success ?? cs.primary).withValues(alpha: 0.18);
        fg = success?.success ?? cs.primary;
        label = 'Completed';
        break;
      case 'paused':
        bg = cs.secondary.withValues(alpha: 0.18);
        fg = cs.secondary;
        label = 'Paused';
        break;
      default:
        bg = cs.outlineVariant.withValues(alpha: 0.25);
        fg = cs.onSurfaceVariant;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: bg,
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _openCreateGoal(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const NewGoalSheet(),
    );
  }

  Future<void> _openAddContribution(BuildContext context,
      DocumentReference<Map<String, dynamic>> goalRef) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => AddContributionSheet(
          goalRef: goalRef,
          onCompleted: () {
            _celebrate();
            _showCompletionPopup();
          }),
    );
  }

  Future<void> _openContributions(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> goalRef,
      String name,
      double target) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ContributionsSheet(
        goalRef: goalRef,
        goalName: name,
        target: target,
      ),
    );
  }

  Future<void> _openEditGoal(
      BuildContext context,
      DocumentReference<Map<String, dynamic>> goalRef,
      Map<String, dynamic> data) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => EditGoalSheet(goalRef: goalRef, data: data),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.15),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.flag_rounded, color: cs.primary, size: 36),
          ),
          const SizedBox(height: 8),
          Text('No goals yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Create your first goal and start tracking progress.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create a goal'),
          ),
        ],
      ),
    );
  }
}

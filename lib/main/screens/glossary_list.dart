import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/noise_decoration.dart';

class GlossaryListScreen extends StatefulWidget {
  const GlossaryListScreen({super.key});

  @override
  State<GlossaryListScreen> createState() => _GlossaryListScreenState();
}

class _GlossaryListScreenState extends State<GlossaryListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId; // null = All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _categoryIconFor(String id, dynamic nameRaw) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final name = (nameRaw ?? id).toString().toLowerCase().replaceAll('_', ' ');
    final size = 24.0; // Reduced from 28 proportionally
    final iconColor = isDark ? const Color(0xFF00897b) : cs.primary;

    if (name.contains('bank'))
      return _BankingIcon(size: size, color: iconColor);
    if (name.contains('econom'))
      return _EconomicsIcon(size: size, color: iconColor);
    if (name.contains('insur'))
      return _InsuranceIcon(size: size, color: iconColor);
    if (name.contains('invest'))
      return _InvestmentIcon(size: size, color: iconColor);
    if (name.contains('personal'))
      return _PersonalFinanceIcon(size: size, color: iconColor);
    return Icon(Icons.category_rounded, size: size, color: iconColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Apply refined dark theme for Learn feature
    final learnScheme = isDark
        ? ColorScheme.dark(
            surface: const Color(0xFF1A1A1A),
            surfaceContainer: const Color(0xFF2A2A2A),
            surfaceContainerHigh: const Color(0xFF3A3A3A),
            onSurface: Colors.white.withValues(alpha: 0.9),
            onSurfaceVariant: Colors.white.withValues(alpha: 0.7),
            outline: Colors.white.withValues(alpha: 0.3),
            outlineVariant: Colors.white.withValues(alpha: 0.2),
            primary: const Color(0xFF00897b),
            secondary: const Color(0xFF00564d),
          )
        : ColorScheme.fromSeed(
            seedColor: cs.primary,
            brightness: Brightness.light,
          );

    final learnTheme = theme.copyWith(
      colorScheme: learnScheme,
      textTheme: GoogleFonts.poppinsTextTheme(theme.textTheme).copyWith(
        titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black), // Dark theme support
        titleMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black), // Dark theme support
        titleSmall: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black), // Dark theme support
        bodyMedium: GoogleFonts.poppins(
            fontSize: 13, height: 1.5), // Reduced from 14 proportionally
        bodySmall: GoogleFonts.poppins(
            fontSize: 11, height: 1.45), // Reduced from 12 proportionally
        labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: isDark ? learnScheme.surfaceContainer : learnScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark
              ? BorderSide(
                  color: learnScheme.outline.withValues(alpha: 0.2), width: 0.5)
              : BorderSide(
                  color: learnScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize:
              const Size(100, 36), // Reduced from 110,40 proportionally
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(
              color: learnScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: learnScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10), // Reduced from 12 proportionally
          borderSide: BorderSide(
              color: learnScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10), // Reduced from 12 proportionally
          borderSide: BorderSide(
              color: learnScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 10), // Reduced from 12,12 proportionally
      ),
    );

    return Theme(
      data: learnTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learn'),
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : null,
        ),
        body: Container(
          decoration: isDark
              ? const NoiseDecoration(
                  color: Color(0xFF00897b),
                  opacity: 0.02,
                )
              : null,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  12, 10, 12, 20), // Reduced from 16,12,16,24 proportionally
              children: [
                // Search bar with merged category filter (suffix popup)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('glossary')
                      .snapshots(),
                  builder: (context, snap) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search financial terms... ',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                            const SizedBox(
                                width:
                                    8), // Add some spacing after the clear button
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10), // Reduced from 12 proportionally
                _allCategoriesList(
                  context,
                  selectedCategoryId: _selectedCategoryId,
                  onCategoryChanged: (id) =>
                      setState(() => _selectedCategoryId = id),
                  searchQuery: _searchQuery,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _featuredFromFirestore(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final docRef = FirebaseFirestore.instance
        .collection('glossary')
        .doc('investment')
        .collection('terms')
        .doc('Compound Interest');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Could not load glossary. ${snap.error}',
            style: textTheme.bodySmall?.copyWith(color: cs.error),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data();
        if (data == null) {
          return Text('No data for Compound Interest',
              style: textTheme.bodyMedium);
        }
        final term = (data['term'] ?? 'Compound Interest').toString();
        final category = (data['category'] ?? 'Investment').toString();
        final definition =
            (data['defination'] ?? data['definition'] ?? '').toString();
        final example = (data['example'] ?? '').toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Featured', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _termCard(
              context,
              term: term,
              category: category,
              definition: definition,
              example: example,
            ),
          ],
        );
      },
    );
  }

  Widget _allCategoriesList(
    BuildContext context, {
    required String? selectedCategoryId,
    required void Function(String? id) onCategoryChanged,
    required String searchQuery,
  }) {
    // Stream top-level categories under glossary
    final catStream =
        FirebaseFirestore.instance.collection('glossary').snapshots();
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: catStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Text(
              'Could not load categories. ${snap.error}',
              style: textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(10.0), // Reduced from 12.0 proportionally
            child: Center(child: CircularProgressIndicator()),
          );
        }
        var docs = (snap.data?.docs ?? []).toList();
        // Client-side sort by label (name field or doc id)
        docs.sort((a, b) {
          final an = (a.data()['name'] ?? a.id).toString().toLowerCase();
          final bn = (b.data()['name'] ?? b.id).toString().toLowerCase();
          return an.compareTo(bn);
        });
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Text(
                'No categories found under glossary/. Add category docs such as investment, banking.',
                style: textTheme.bodyMedium),
          );
        }

        // Build filter dropdown using categories
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category list (filter control moved into search bar)
            for (final d in docs) ...[
              if (selectedCategoryId != null &&
                  selectedCategoryId.isNotEmpty &&
                  selectedCategoryId != d.id)
                const SizedBox.shrink()
              else ...[
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: d.id.toLowerCase() == 'investment',
                    tilePadding: EdgeInsets.zero,
                    iconColor: Theme.of(context).colorScheme.primary,
                    collapsedIconColor: Theme.of(context).colorScheme.primary,
                    title: Row(
                      children: [
                        // Make category icons more noticeable and actionable
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            onCategoryChanged(d.id);
                            final label = _titleCase(
                                (d.data()['name'] ?? d.id).toString());
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Filtering: $label')),
                            );
                          },
                          child: Tooltip(
                            message:
                                'Filter by ${_titleCase((d.data()['name'] ?? d.id).toString())}',
                            child: _categoryIconFor(d.id, d.data()['name']),
                          ),
                        ),
                        const SizedBox(
                            width: 6), // Reduced from 8 proportionally
                        Expanded(
                          child: Text(
                            _titleCase((d.data()['name'] ?? d.id).toString()),
                            style: textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.only(
                        top: 6, bottom: 6), // Reduced from 8,8 proportionally
                    children: [
                      _categoryList(
                        context,
                        categoryId: d.id,
                        categoryLabel:
                            _titleCase((d.data()['name'] ?? d.id).toString()),
                        searchQuery: searchQuery,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6), // Reduced from 8 proportionally
              ],
            ]
          ],
        );
      },
    );
  }

  Widget _categoryList(BuildContext context,
      {required String categoryId,
      required String categoryLabel,
      required String searchQuery}) {
    final stream = FirebaseFirestore.instance
        .collection('glossary')
        .doc(categoryId)
        .collection('terms')
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Text(
              'Could not load $categoryLabel. ${snap.error}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(10.0), // Reduced from 12.0 proportionally
            child: Center(child: CircularProgressIndicator()),
          );
        }
        var docs = (snap.data?.docs ?? []).toList();
        // Client-side sort by display term (term/title/doc id)
        docs.sort((a, b) {
          final at = (a.data()['term'] ?? a.data()['title'] ?? a.id)
              .toString()
              .toLowerCase();
          final bt = (b.data()['term'] ?? b.data()['title'] ?? b.id)
              .toString()
              .toLowerCase();
          return at.compareTo(bt);
        });
        // Filter by search query (term, definition, example)
        final q = searchQuery.trim().toLowerCase();
        if (q.isNotEmpty) {
          docs = docs.where((doc) {
            final m = doc.data();
            final term =
                (m['term'] ?? m['title'] ?? doc.id).toString().toLowerCase();
            final def = (m['defination'] ??
                    m['definition'] ??
                    m['shortDefinition'] ??
                    '')
                .toString()
                .toLowerCase();
            final ex = (m['example'] ?? '').toString().toLowerCase();
            return term.contains(q) || def.contains(q) || ex.contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 proportionally
            child: Text(
              'No $categoryLabel terms yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 6), // Reduced from 8 proportionally
          itemBuilder: (context, i) {
            final m = docs[i].data();
            var term =
                (m['term'] ?? m['title'] ?? docs[i].id).toString().trim();
            final category = (m['category'] ?? categoryLabel).toString();
            final definition = (m['defination'] ??
                    m['definition'] ??
                    m['shortDefinition'] ??
                    '')
                .toString();
            final example = (m['example'] ?? '').toString();
            return _termCard(context,
                term: term,
                category: category,
                definition: definition,
                example: example);
          },
        );
      },
    );
  }

  Widget _termCard(
    BuildContext context, {
    required String term,
    required String category,
    required String definition,
    required String example,
  }) {
    return _AnimatedTermCard(
      term: term,
      category: category,
      definition: definition,
      example: example,
    );
  }
}

// Animated card with Hero + subtle glow + animated icon
class _AnimatedTermCard extends StatefulWidget {
  const _AnimatedTermCard({
    required this.term,
    required this.category,
    required this.definition,
    required this.example,
  });

  final String term;
  final String category;
  final String definition;
  final String example;

  @override
  State<_AnimatedTermCard> createState() => _AnimatedTermCardState();
}

class _AnimatedTermCardState extends State<_AnimatedTermCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _iconCtrl;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _iconScale = Tween<double>(begin: 1.0, end: 1.08)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_iconCtrl);
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  void _openDetail() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, a, __) => FadeTransition(
          opacity: a,
          child: _GlossaryDetailPage(
            term: widget.term,
            category: widget.category,
            definition: widget.definition,
            example: widget.example,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag =
        'term-card-${widget.term.toLowerCase()}-${widget.category.toLowerCase()}';

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _iconCtrl.forward(from: 0);
      },
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _openDetail();
      },
      child: Hero(
        tag: tag,
        flightShuttleBuilder: (
          BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext,
        ) {
          final child = flightDirection == HeroFlightDirection.push
              ? fromHeroContext.widget
              : toHeroContext.widget;
          return Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.02).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(10), // Reduced from 12 proportionally
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                BorderRadius.circular(12), // Reduced from 14 proportionally
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.16),
                      blurRadius: 14, // Reduced from 16 proportionally
                      spreadRadius: 0.5, // Reduced from 1 proportionally
                      offset:
                          const Offset(0, 5), // Reduced from 6 proportionally
                    ),
                  ]
                : [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.06),
                      blurRadius: 8, // Reduced from 10 proportionally
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _iconScale,
                child: Container(
                  width: 32, // Reduced from 36 proportionally
                  height: 32, // Reduced from 36 proportionally
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
                ),
              ),
              const SizedBox(width: 10), // Reduced from 12 proportionally
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.term,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1), // Reduced from 2 proportionally
                    Text(
                      _titleCase(widget.category),
                      style: textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6), // Reduced from 8 proportionally
              Icon(Icons.chevron_right_rounded, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlossaryDetailPage extends StatelessWidget {
  const _GlossaryDetailPage({
    required this.term,
    required this.category,
    required this.definition,
    required this.example,
  });

  final String term;
  final String category;
  final String definition;
  final String example;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tag = 'term-card-${term.toLowerCase()}-${category.toLowerCase()}';
    return Scaffold(
      appBar: AppBar(title: Text(term)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              12, 12, 12, 20), // Reduced from 16,16,16,24 proportionally
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: tag,
                child: Container(
                  padding: const EdgeInsets.all(
                      14), // Reduced from 16 proportionally
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(
                        14), // Reduced from 16 proportionally
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(
                              0, 3)), // Reduced from 12,4 proportionally
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, // Reduced from 42 proportionally
                        height: 38, // Reduced from 42 proportionally
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.auto_awesome_rounded, color: cs.primary),
                      ),
                      const SizedBox(
                          width: 10), // Reduced from 12 proportionally
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(term,
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(
                                height: 3), // Reduced from 4 proportionally
                            Text(_titleCase(category),
                                style: textTheme.labelMedium
                                    ?.copyWith(color: cs.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14), // Reduced from 16 proportionally
              _SectionAppear(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Definition',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6), // Reduced from 8 proportionally
                    _buildHighlightedText(
                      definition,
                      base:
                          textTheme.bodyLarge ?? const TextStyle(fontSize: 14),
                      accent: cs.primary,
                      keywords: [term],
                    ),
                  ],
                ),
              ),
              if (example.trim().isNotEmpty)
                _SectionAppear(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                          height: 18), // Reduced from 20 proportionally
                      Text('Example',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(
                          height: 6), // Reduced from 8 proportionally
                      _buildHighlightedText(
                        example,
                        base: (textTheme.bodyLarge ??
                                const TextStyle(fontSize: 14))
                            .copyWith(color: cs.onSurfaceVariant),
                        accent: cs.primary,
                        keywords: [term],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
void _showTermBottomSheet(
  BuildContext context, {
  required String term,
  required String category,
  required String definition,
  required String example,
}) {
  final cs = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.48,
        minChildSize: 0.32,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
                14, 10, 14, 20), // Reduced from 16,12,16,24 proportionally
            child: ListView(
              controller: controller,
              children: [
                Row(
                  children: [
                    Container(
                      height: 36, // Reduced from 40 proportionally
                      width: 36, // Reduced from 40 proportionally
                      decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle),
                      child: Icon(Icons.menu_book_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 10), // Reduced from 12 proportionally
                    Expanded(
                      child: Text(term,
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // Reduced from 12 proportionally
                if (category.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(category, style: textTheme.labelLarge),
                        backgroundColor: cs.secondaryContainer,
                        labelStyle: textTheme.labelLarge
                            ?.copyWith(color: cs.onSecondaryContainer),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                const SizedBox(height: 10), // Reduced from 12 proportionally
                if (definition.isNotEmpty) ...[
                  Text('Definition', style: textTheme.titleSmall),
                  const SizedBox(height: 6), // Reduced from 6 proportionally
                  Text(definition, style: textTheme.bodyMedium),
                ],
                if (example.isNotEmpty) ...[
                  const SizedBox(height: 10), // Reduced from 12 proportionally
                  Text('Example', style: textTheme.titleSmall),
                  const SizedBox(height: 6), // Reduced from 6 proportionally
                  Text(example,
                      style: textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

String _titleCase(String input) {
  final cleaned = input.replaceAll('_', ' ').trim().toLowerCase();
  if (cleaned.isEmpty) return input;
  return cleaned
      .split(RegExp(r"\s+"))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class _SectionAppear extends StatelessWidget {
  const _SectionAppear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 160);
    const offset = 8.0; // Reduced from 10.0 proportionally
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offset),
            child: child,
          ),
        );
      },
    );
  }
}

Widget _buildHighlightedText(
  String input, {
  required TextStyle base,
  required Color accent,
  List<String> keywords = const [],
}) {
  if (input.isEmpty) return Text(input, style: base);

  final escaped = keywords
      .where((k) => k.trim().isNotEmpty)
      .map((k) => RegExp.escape(k))
      .toList();
  final keywordPattern =
      escaped.isEmpty ? null : '(?:\\b(?:${escaped.join('|')})\\b)';
  final numberPattern = r'(?:\b\d+(?:[\.,]\d+)?%?)';
  final pattern = keywordPattern == null
      ? numberPattern
      : '(?:$keywordPattern)|$numberPattern';
  final reg = RegExp(pattern, caseSensitive: false);

  final spans = <TextSpan>[];
  int index = 0;
  for (final m in reg.allMatches(input)) {
    if (m.start > index) {
      spans.add(TextSpan(text: input.substring(index, m.start), style: base));
    }
    final matched = input.substring(m.start, m.end);
    spans.add(TextSpan(
      text: matched,
      style: base.copyWith(color: accent, fontWeight: FontWeight.w700),
    ));
    index = m.end;
  }
  if (index < input.length) {
    spans.add(TextSpan(text: input.substring(index), style: base));
  }

  return RichText(text: TextSpan(children: spans));
}

// Lightweight, looped micro-animated category icons
class _BankingIcon extends StatefulWidget {
  const _BankingIcon({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  State<_BankingIcon> createState() => _BankingIconState();
}

class _BankingIconState extends State<_BankingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle halo
              Opacity(
                opacity: 0.15 + 0.10 * t,
                child: Container(
                  width: widget.size *
                      (1.0 + 0.04 * t), // Reduced from 0.05 proportionally
                  height: widget.size *
                      (1.0 + 0.04 * t), // Reduced from 0.05 proportionally
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.18),
                  ),
                ),
              ),
              // Base recognizable piggy bank glyph
              Icon(Icons.savings_rounded,
                  size: widget.size * 0.92, color: widget.color),
              // Animated coin overlay dropping into the slot area
              CustomPaint(
                size: Size.square(widget.size),
                painter: _CoinDropPainter(progress: t, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }
}

// (Removed old _PiggyBankPainter; using Material glyph + _CoinDropPainter overlay)

// Simple coin drop overlay for the Material piggy bank glyph
class _CoinDropPainter extends CustomPainter {
  _CoinDropPainter({required this.progress, required this.color});
  final double progress; // 0..1 eased
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = Curves.easeInOut.transform(progress);
    // Coin path: drop from above into slot region over the glyph
    final startY = h * 0.10;
    final endY = h * 0.46;
    // simple bounce ease near end
    final drop = (t < 0.7) ? (t / 0.7) : (1.0 - (t - 0.7) / 0.3 * 0.2);
    final cy = startY +
        (endY - startY) * Curves.easeIn.transform(drop.clamp(0.0, 1.0));
    final cx = w * 0.48;
    final r = w * 0.10;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset(cx, cy), r, fill);
    canvas.drawCircle(Offset(cx, cy), r, stroke);
    // vertical mark on coin
    canvas.drawLine(
        Offset(cx, cy - r * 0.45), Offset(cx, cy + r * 0.45), stroke);
  }

  @override
  bool shouldRepaint(covariant _CoinDropPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _EconomicsIcon extends StatefulWidget {
  const _EconomicsIcon({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  State<_EconomicsIcon> createState() => _EconomicsIconState();
}

class _EconomicsIconState extends State<_EconomicsIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return CustomPaint(
            painter: _TrendPainter(progress: _c.value, color: widget.color),
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.progress, required this.color});
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final w = size.width;
    final h = size.height;
    // Slow fluid line hinting trends
    final points = 16;
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final x = t * w;
      final phase = (t * 2 * 3.1415) + progress * 2 * 3.1415;
      final y = h * (0.65 - 0.18 * math.sin(phase));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p);

    // Moving point at the latest value
    final tipT = 1.0;
    final tipX = tipT * w;
    final tipPhase = (tipT * 2 * 3.1415) + progress * 2 * 3.1415;
    final tipY = h * (0.65 - 0.18 * math.sin(tipPhase));
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final r = 1.8 + 0.6 * math.sin(progress * 2 * 3.1415);
    canvas.drawCircle(Offset(tipX, tipY), r, dot);
    canvas.drawCircle(Offset(tipX, tipY), r + 0.8, ring);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _InsuranceIcon extends StatefulWidget {
  const _InsuranceIcon({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  State<_InsuranceIcon> createState() => _InsuranceIconState();
}

class _InsuranceIconState extends State<_InsuranceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final glow = 6.0 + 4.0 * Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: 0.22),
                  blurRadius: glow,
                  spreadRadius: 0.2),
            ],
          ),
          child: Icon(Icons.health_and_safety_rounded,
              size: widget.size * 0.95, color: widget.color),
        );
      },
    );
  }
}

class _InvestmentIcon extends StatefulWidget {
  const _InvestmentIcon({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  State<_InvestmentIcon> createState() => _InvestmentIconState();
}

class _InvestmentIconState extends State<_InvestmentIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return CustomPaint(
            painter:
                _StockChartPainter(progress: _c.value, color: widget.color),
          );
        },
      ),
    );
  }
}

class _StockChartPainter extends CustomPainter {
  _StockChartPainter({required this.progress, required this.color});
  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final axis = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final wick = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final bull = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final bear = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Chart frame (bottom and left axes)
    final left = w * 0.08;
    final right = w * 0.92;
    final top = h * 0.18;
    final bottom = h * 0.86;
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), axis);
    canvas.drawLine(Offset(left, bottom), Offset(left, top), axis);

    // Generate oscillating prices
    const int points = 7; // small but readable in icon size
    final dx = (right - left) / (points - 1);
    final path = Path();

    double phase(double i) => (progress * 2 * math.pi) + i * 0.9;
    double price(double i) {
      // base curve + oscillation
      final t = i / (points - 1);
      final start = bottom - h * 0.20;
      final end = top + h * 0.12;
      final base = start + (end - start) * t; // general up slope
      final osc = math.sin(phase(i)) * (h * 0.06);
      return (base + osc).clamp(top + 2.0, bottom - 2.0);
    }

    // Build line path
    for (int i = 0; i < points; i++) {
      final x = left + dx * i;
      final y = price(i.toDouble());
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    // Draw candlesticks at each point
    for (int i = 0; i < points; i++) {
      final x = left + dx * i;
      double idxOpen = (i - 0.6).toDouble();
      idxOpen = idxOpen.clamp(0.0, (points - 1).toDouble()).toDouble();
      final open = price(idxOpen);
      double idxClose = (i + 0.4).toDouble();
      idxClose = idxClose.clamp(0.0, (points - 1).toDouble()).toDouble();
      final close = price(idxClose);
      final high = math.min(open, close) -
          h * (0.03 + 0.01 * math.cos(phase(i.toDouble())));
      final low = math.max(open, close) +
          h * (0.03 + 0.01 * math.sin(phase(i.toDouble())));
      final up = close < open; // y smaller = higher value on canvas

      // Wick
      canvas.drawLine(Offset(x, high), Offset(x, low), wick);

      // Body
      final bodyTop = up ? close : open;
      final bodyBottom = up ? open : close;
      final bw = dx * 0.38;
      final rect = Rect.fromCenter(
        center: Offset(x, (bodyTop + bodyBottom) / 2),
        width: bw,
        height: (bodyBottom - bodyTop).abs() + 1.2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bw * 0.28)),
        up ? bull : bear,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(bw * 0.28)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Moving highlight dot on latest price
    final tipX = left + dx * (points - 1);
    final tipY = price((points - 1).toDouble());
    canvas.drawCircle(Offset(tipX, tipY), 1.8, line);
  }

  @override
  bool shouldRepaint(covariant _StockChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _PersonalFinanceIcon extends StatefulWidget {
  const _PersonalFinanceIcon({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  State<_PersonalFinanceIcon> createState() => _PersonalFinanceIconState();
}

class _PersonalFinanceIconState extends State<_PersonalFinanceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        // Pencil wiggle parameters
        final wiggle = (t - 0.5) * 2; // -1..1
        final angle = 0.18 * wiggle; // small rotation
        final offset = Offset(2.0 * wiggle, 1.5 * wiggle);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Paper base
              Icon(Icons.description_rounded,
                  size: widget.size * 0.96, color: widget.color),
              // Animated pencil overlay
              Align(
                alignment: Alignment(0.60, 0.40),
                child: Transform.translate(
                  offset: offset,
                  child: Transform.rotate(
                    angle: angle,
                    child: Icon(Icons.create_rounded,
                        size: widget.size * 0.62, color: widget.color),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// (Removed old _PencilPaperPainter; using Material paper + animated pencil wiggle)

import 'package:flutter/material.dart';
import 'dart:math';

class FactCard extends StatelessWidget {
  const FactCard({super.key});

  @override
  Widget build(BuildContext context) {
    final facts = [
      'Did you know? Saving just ₹100 a day can grow to over ₹36,000 in a year!',
      'Tip: Tracking expenses helps identify unnecessary spending patterns.',
      'Fun fact: The first credit card was introduced in 1950 by Diners Club.',
      'Smart move: Having an emergency fund can prevent debt during tough times.',
      'Did you know? The 50/30/20 rule suggests spending 50% on needs, 30% on wants, and saving 20%.',
    ];
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final fact = facts[random.nextInt(facts.length)];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  fact,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

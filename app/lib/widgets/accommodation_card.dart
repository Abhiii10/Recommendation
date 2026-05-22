import 'package:flutter/material.dart';

import '../models/accommodation_model.dart';

class AccommodationCard extends StatelessWidget {
  final AccommodationModel accommodation;

  const AccommodationCard({
    super.key,
    required this.accommodation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final budgetColor = switch (accommodation.priceRange) {
      'budget' => isDark ? const Color(0xFF8FD694) : Colors.green.shade800,
      'medium' => isDark ? const Color(0xFFFFB067) : Colors.orange.shade900,
      'premium' => isDark ? const Color(0xFFD6A8FF) : Colors.deepPurple,
      _ => cs.onSurfaceVariant,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hotel,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accommodation.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if ((accommodation.priceRange ?? '').isNotEmpty)
                  Chip(
                    label: Text(
                      accommodation.priceRange!,
                      style: TextStyle(color: budgetColor),
                    ),
                    backgroundColor: budgetColor.withValues(alpha: 0.12),
                  ),
              ],
            ),
            if ((accommodation.accommodationType ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                accommodation.accommodationType!,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
            if ((accommodation.locationNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(child: Text(accommodation.locationNote!)),
                ],
              ),
            ],
            if (accommodation.amenities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: accommodation.amenities.take(5).map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

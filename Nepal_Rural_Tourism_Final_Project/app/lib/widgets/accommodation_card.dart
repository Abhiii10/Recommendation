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
    final budgetColor = switch (accommodation.priceRange) {
      'budget' => Colors.green,
      'medium' => Colors.orange,
      'premium' => Colors.deepPurple,
      _ => Colors.grey,
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
                const Icon(
                  Icons.hotel,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accommodation.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if ((accommodation.priceRange ?? '').isNotEmpty)
                  Chip(
                    label: Text(
                      accommodation.priceRange!,
                      style: TextStyle(color: budgetColor),
                    ),
                    backgroundColor: budgetColor.withOpacity(0.12),
                  ),
              ],
            ),
            if ((accommodation.accommodationType ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                accommodation.accommodationType!,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if ((accommodation.locationNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
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
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
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

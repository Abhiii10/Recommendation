import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_data_service.dart';
import 'rating_widget.dart';

Future<void> showReviewBottomSheet({
  required BuildContext context,
  required String destinationId,
  VoidCallback? onSubmitted,
}) {
  HapticFeedback.selectionClick();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) {
      return _ReviewBottomSheet(
        destinationId: destinationId,
        onSubmitted: onSubmitted,
      );
    },
  );
}

class _ReviewBottomSheet extends StatefulWidget {
  final String destinationId;
  final VoidCallback? onSubmitted;

  const _ReviewBottomSheet({
    required this.destinationId,
    this.onSubmitted,
  });

  @override
  State<_ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<_ReviewBottomSheet> {
  static const int _maxReviewLength = 200;

  final TextEditingController _controller = TextEditingController();

  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() => _rating = value);
  }

  void _submitTapped() {
    HapticFeedback.selectionClick();
    unawaited(_submit());
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;

    setState(() => _submitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await LocalDataService.instance.saveReview(
      widget.destinationId,
      _rating,
      _controller.text,
    );
    if (!mounted) return;

    widget.onSubmitted?.call();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Review submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Write a Review',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share a quick note to help future travellers choose wisely.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          RatingWidget(
            rating: _rating,
            size: 34,
            onRatingChanged: _setRating,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: _maxReviewLength,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Optional review',
              hintText: 'What should others know?',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _rating == 0 || _submitting ? null : _submitTapped,
              icon: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Submitting...' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

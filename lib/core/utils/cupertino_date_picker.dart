import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<DateTime?> showCupertinoDateDialog({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime selected = initialDate ?? DateTime.now();
  final result = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Header with Done button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Anuluj'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Gotowe',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => Navigator.pop(ctx, selected),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Picker
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: selected,
              minimumDate: firstDate ?? DateTime(2020),
              maximumDate: lastDate ?? DateTime.now(),
              onDateTimeChanged: (date) => selected = date,
              use24hFormat: true,
            ),
          ),
        ],
      ),
    ),
  );
  return result;
}

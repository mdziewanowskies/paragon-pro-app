import 'package:flutter/material.dart';
import '../widgets/advanced_export.dart';
import '../widgets/monthly_report.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eksport danych',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const AdvancedExport(),
          const SizedBox(height: 24),
          Text(
            'Raport miesięczny',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const MonthlyReport(),
        ],
      ),
    );
  }
}

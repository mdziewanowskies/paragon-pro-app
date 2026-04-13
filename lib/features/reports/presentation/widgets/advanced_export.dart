import 'package:flutter/material.dart';

class AdvancedExport extends StatelessWidget {
  const AdvancedExport({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.file_download_rounded),
                const SizedBox(width: 8),
                Text(
                  'Zaawansowany eksport',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.table_chart_rounded,
              title: 'Eksport CSV',
              subtitle: 'Paragony i wydatki w formacie CSV',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generowanie CSV...')),
                );
              },
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Raport PDF',
              subtitle: 'Pełny raport z wykresami',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generowanie PDF...')),
                );
              },
            ),
            const SizedBox(height: 8),
            _ExportOption(
              icon: Icons.code_rounded,
              title: 'Eksport XML (KSeF)',
              subtitle: 'Faktury w formacie XML KSeF',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generowanie XML...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

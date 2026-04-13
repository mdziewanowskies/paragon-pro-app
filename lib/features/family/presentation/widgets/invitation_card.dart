import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const InvitationCard({
    super.key,
    required this.invitation,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final familyName =
        (invitation['families'] as Map?)?['name'] as String? ?? 'Rodzina';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_rounded,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zaproszenie do rodziny',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    familyName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDecline,
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.lightDestructive),
              tooltip: 'Odrzuć',
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Dołącz'),
            ),
          ],
        ),
      ),
    );
  }
}

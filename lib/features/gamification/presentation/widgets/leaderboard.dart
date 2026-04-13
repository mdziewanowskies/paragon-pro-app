import 'package:flutter/material.dart';

class Leaderboard extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const Leaderboard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Brak danych rankingu')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: entries.map((entry) {
            final rank = entry['rank'] as int;
            final isCurrentUser = entry['isCurrentUser'] as bool? ?? false;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 36,
                    child: rank <= 3
                        ? Text(
                            rank == 1
                                ? '\u{1F947}'
                                : rank == 2
                                    ? '\u{1F948}'
                                    : '\u{1F949}',
                            style: const TextStyle(fontSize: 22),
                          )
                        : Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      (entry['username'] as String?)?.characters.first.toUpperCase() ??
                          '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry['username'] as String? ?? 'Użytkownik',
                          style: TextStyle(
                            fontWeight:
                                isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Poziom ${entry['level']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Points
                  Text(
                    '${entry['points']} pkt',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

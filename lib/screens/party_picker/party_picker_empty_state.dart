import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ---------- Empty States / Helpers ----------

class NoSpeciesOwnedWrapper extends StatelessWidget {
  const NoSpeciesOwnedWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "You don't own any creatures yet.",
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class NoResultsFound extends StatelessWidget {
  final FactionTheme theme;
  const NoResultsFound({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: theme.textMuted.withOpacity(.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No species found',
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(
              color: theme.textMuted.withOpacity(.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

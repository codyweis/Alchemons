import 'package:flutter/material.dart';

/// A null amount denotes a local guest reset. A verified zero is an account
/// reset, and must still explain that the account's old backups are retired.
class ResetProgressDialog extends StatelessWidget {
  const ResetProgressDialog({super.key, this.purchasedGold});
  final int? purchasedGold;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Are you sure you want to reset your progress?'),
    content: Text(
      purchasedGold == null
          ? 'Your creatures, inventory, upgrades, currencies, and game progress on this device will be erased. This cannot be undone.\n\nTo restore purchased gold, sign in to the account that bought it before resetting. Account backups are not changed by a local reset.'
          : 'Your creatures, inventory, upgrades, currencies, and game progress will be erased. Your previous account backups and transfer codes will no longer work.\n\nYou’ll stay signed in. Your $purchasedGold purchased gold will be restored, including gold you previously spent, along with the normal starting gold.\n\nThis cannot be undone.',
    ),
    actions: [
      if (purchasedGold == null)
        TextButton(
          onPressed: () => Navigator.pop(context, 'sign-in'),
          child: const Text('Sign In'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, 'reset'),
        child: Text(
          purchasedGold == null ? 'Reset Local Progress' : 'Reset Progress',
        ),
      ),
    ],
  );
}

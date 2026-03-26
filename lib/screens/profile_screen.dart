// lib/screens/profile_screen.dart
//
// REDESIGNED PROFILE / SETTINGS SCREEN
// Aesthetic: Scorched Forge — matches boss_intro_screen / survival_game_screen
// Dark metal panels, amber reagent accents, monospace tactical typography.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/story/story_intro_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/account_cloud_save_service.dart';
import 'package:alchemons/services/account_session_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:alchemons/utils/app_scaffold_messenger.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/theme_switch_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY HELPERS  (colors resolved at runtime via ForgeTokens)
// ──────────────────────────────────────────────────────────────────────────────

TextStyle _heading(ForgeTokens t) => TextStyle(
  fontFamily: 'monospace',
  color: t.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 2.0,
);

TextStyle _label(ForgeTokens t) => TextStyle(
  fontFamily: 'monospace',
  color: t.textSecondary,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.6,
);

TextStyle _body(ForgeTokens t) =>
    TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5);

// ──────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: t.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: _label(t)),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: t.borderMid)),
      ],
    );
  }
}

/// Flat forge-panel card with optional left accent bar.
class _ForgePanel extends StatelessWidget {
  final Widget child;
  final Color? accentBar;
  final EdgeInsetsGeometry padding;

  const _ForgePanel({
    required this.child,
    this.accentBar,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentBar != null)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentBar,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact forge action button — matches boss/survival style.
class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ForgeButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: isDisabled ? t.borderDim : t.borderAccent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isDisabled ? t.textMuted : t.amber),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: isDisabled ? t.textMuted : t.amberBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(void Function() param0, {super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _load;
  late final PageController _cosmicHintsController;
  final NotificationPreferencesService _notificationPrefs =
      NotificationPreferencesService();
  final CinematicQualityService _cinematicQualityService =
      CinematicQualityService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  bool _cultivationsEnabled = true;
  bool _wildernessEnabled = true;
  bool _extractionsEnabled = true;
  bool _notificationPrefsLoaded = false;
  CinematicQuality _cinematicQuality = CinematicQuality.high;
  bool _cinematicQualityLoaded = false;
  bool _saveTransferBusy = false;
  int _cosmicHintPage = 0;

  @override
  void initState() {
    super.initState();
    _cosmicHintsController = PageController();
    _load = _fetch();
    _loadNotificationPrefs();
    _loadCinematicQuality();
  }

  @override
  void dispose() {
    _cosmicHintsController.dispose();
    super.dispose();
  }

  Future<_ProfileData> _fetch() async {
    final svc = context.read<FactionService>();
    final fid = svc.current;
    final prefs = await SharedPreferences.getInstance();
    final noteIds = deserialiseContestHintIds(
      prefs.getString('cosmic_trait_hint_notes_v1') ?? '',
    );
    final cosmicHints = kCosmicContestHintLore
        .where((h) => noteIds.contains(h.id))
        .toList();

    if (fid == null) return _ProfileData(null, 0, cosmicHints);
    final discovered = await svc.discoveredCount();
    return _ProfileData(fid, discovered, cosmicHints);
  }

  Future<void> _replayStory() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StoryIntroScreen()),
    );
  }

  Future<void> _openEncyclopedia() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );
  }

  Future<void> _loadNotificationPrefs() async {
    final cultivations = await _notificationPrefs.isCultivationsEnabled();
    final wilderness = await _notificationPrefs.isWildernessEnabled();
    final extractions = await _notificationPrefs.isExtractionsEnabled();
    if (!mounted) return;
    setState(() {
      _cultivationsEnabled = cultivations;
      _wildernessEnabled = wilderness;
      _extractionsEnabled = extractions;
      _notificationPrefsLoaded = true;
    });
  }

  Future<void> _toggleCultivations(bool value) async {
    setState(() => _cultivationsEnabled = value);
    await _notificationPrefs.setCultivationsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelEggNotification();
    }
  }

  Future<void> _toggleWilderness(bool value) async {
    setState(() => _wildernessEnabled = value);
    await _notificationPrefs.setWildernessEnabled(value);
    if (!value) {
      await _pushNotifications.cancelWildernessNotifications();
    }
  }

  Future<void> _toggleExtractions(bool value) async {
    setState(() => _extractionsEnabled = value);
    await _notificationPrefs.setExtractionsEnabled(value);
    if (!value) {
      await _pushNotifications.cancelHarvestNotification();
    }
  }

  Future<void> _loadCinematicQuality() async {
    final quality = await _cinematicQualityService.getQuality();
    if (!mounted) return;
    setState(() {
      _cinematicQuality = quality;
      _cinematicQualityLoaded = true;
    });
  }

  Future<void> _setCinematicQuality(CinematicQuality value) async {
    setState(() => _cinematicQuality = value);
    await _cinematicQualityService.setQuality(value);
  }

  Future<void> _reloadProfileState() async {
    if (!mounted) return;
    setState(() {
      _load = _fetch();
    });
    await _loadNotificationPrefs();
    await _loadCinematicQuality();
  }

  String _formatCosmicHintText(String text) {
    final separator = text.indexOf(':');
    final raw = separator < 0
        ? text.trim()
        : text.substring(separator + 1).trim();
    return raw
        .replaceFirst(RegExp(r'^[\"\u201C\u201D]+'), '')
        .replaceFirst(RegExp(r'[\"\u201C\u201D]+$'), '')
        .trim();
  }

  Widget _buildCosmicHintsCarousel(
    ForgeTokens t,
    List<CosmicContestHintLore> cosmicHints,
  ) {
    if (cosmicHints.isEmpty) {
      return Text(
        'No cosmic hint notes discovered yet.',
        style: _body(t).copyWith(fontSize: 11),
      );
    }

    final hints = cosmicHints.take(6).toList(growable: false);
    final currentPage = _cosmicHintPage.clamp(0, hints.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: PageView.builder(
            controller: _cosmicHintsController,
            itemCount: hints.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _cosmicHintPage = index);
            },
            itemBuilder: (context, index) {
              final hint = hints[index];
              return SizedBox.expand(
                child: Text(
                  _formatCosmicHintText(hint.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: _body(t).copyWith(fontSize: 10, height: 1.35),
                ),
              );
            },
          ),
        ),
        if (hints.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(hints.length, (index) {
              final selected = index == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? t.teal : t.borderDim,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Future<void> _createAccount() async {
    final result = await _showCredentialDialog(
      title: 'Create Account',
      submitLabel: 'CREATE',
      includeDisplayName: true,
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'CREATING ACCOUNT',
      message: 'Setting up your transfer account.',
    );

    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    try {
      await accountService.createAccount(
        email: result.email,
        password: result.password,
        displayName: result.displayName,
      );
      await sessionService.claimCurrentDevice(force: true);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account created. Save transfer is now unlocked.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account creation failed: $error', isError: true);
    }
  }

  Future<void> _signInAccount() async {
    final result = await _showCredentialDialog(
      title: 'Sign In',
      submitLabel: 'SIGN IN',
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'SIGNING IN',
      message: 'Verifying your account for save transfer.',
    );

    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    try {
      await accountService.signIn(
        email: result.email,
        password: result.password,
      );
      await sessionService.refresh();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Signed in.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Sign in failed: $error', isError: true);
    }
  }

  Future<void> _renameAccount(AccountService account) async {
    final controller = TextEditingController(text: account.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return AlertDialog(
          backgroundColor: t.bg2,
          title: Text('Update Account Name', style: _heading(t)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              hintText: 'Display name',
              hintStyle: TextStyle(color: t.textMuted),
              filled: true,
              fillColor: t.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: t.borderDim),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: _label(t).copyWith(color: t.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(
                'SAVE',
                style: _label(t).copyWith(color: t.amberBright),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || name == null || name.isEmpty) return;

    _showProgressDialog(
      title: 'UPDATING ACCOUNT',
      message: 'Saving your new account name.',
    );
    try {
      await account.updateDisplayName(name);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account name updated.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _changePassword(AccountService account) async {
    final result = await _showPasswordDialog(
      title: 'Change Password',
      submitLabel: 'UPDATE',
      includeNewPassword: true,
      message: 'Re-enter your current password, then choose a new one.',
    );
    if (!mounted || result == null) return;

    _showProgressDialog(
      title: 'CHANGING PASSWORD',
      message: 'Updating your account security.',
    );
    try {
      await account.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Password updated.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _deleteAccount(AccountService account) async {
    final result = await _showPasswordDialog(
      title: 'Delete Account',
      submitLabel: 'DELETE',
      message:
          'This removes your Firebase account. Local game progress on this device is not deleted automatically.',
    );
    if (!mounted || result == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return AlertDialog(
          backgroundColor: t.bg2,
          title: Text('Delete account permanently?', style: _heading(t)),
          content: Text(
            'You will lose account-based save transfer access until you create another account.',
            style: _body(t),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'CANCEL',
                style: _label(t).copyWith(color: t.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'DELETE',
                style: _label(t).copyWith(color: Colors.red.shade300),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    _showProgressDialog(
      title: 'DELETING ACCOUNT',
      message: 'Removing your account credentials.',
    );
    try {
      await account.deleteAccount(currentPassword: result.currentPassword);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account deleted.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _signOutAccount(AccountService account) async {
    try {
      await account.signOut();
      _showTransferSnack('Signed out.');
    } on AccountException catch (error) {
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _exportSave() async {
    if (_saveTransferBusy) return;
    final account = context.read<AccountService>();
    final session = context.read<AccountSessionService>();
    if (!account.isSignedIn) {
      _showTransferSnack(
        'Sign in with an account before backing up this save.',
        isError: true,
      );
      return;
    }
    if (!session.state.activeOnThisDevice) {
      _showTransferSnack(
        'This device is not the active device for the signed-in account.',
        isError: true,
      );
      return;
    }
    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'BACKING UP SAVE',
      message: 'Uploading this device save to your account.',
    );

    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      final transfer = SaveTransferService(db);
      final saveCode = await transfer.exportSaveCode(
        ownerAccountId: account.user!.uid,
      );
      final snapshot = await cloudSave.uploadSave(
        uid: account.user!.uid,
        sourceDeviceId: session.deviceId!,
        saveCode: saveCode,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(
        'Account backup uploaded${snapshot.revision > 0 ? ' (revision ${snapshot.revision})' : ''}. Sign into this account on another device and restore it there.',
      );
    } on SaveTransferException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } on AccountCloudSaveException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Save export failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saveTransferBusy = false);
    }
  }

  Future<void> _importSave() async {
    if (_saveTransferBusy) return;
    final account = context.read<AccountService>();
    final session = context.read<AccountSessionService>();
    if (!account.isSignedIn) {
      _showTransferSnack(
        'Sign in with an account before restoring a cloud save.',
        isError: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return AlertDialog(
          backgroundColor: t.bg2,
          title: Text('Restore account backup?', style: _heading(t)),
          content: Text(
            'This overwrites the progress stored on this device with the latest backup from this account.',
            style: _body(t),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'CANCEL',
                style: _label(t).copyWith(color: t.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'RESTORE',
                style: _label(t).copyWith(color: t.amberBright),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'RESTORING BACKUP',
      message:
          'Downloading the latest account save and moving this account here.',
    );
    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      await session.rotateCurrentDeviceId();
      final transferCode = await cloudSave.downloadSaveCode(account.user!.uid);
      final transfer = SaveTransferService(db);
      await transfer.importSaveCode(
        transferCode,
        ownerAccountId: account.user!.uid,
      );
      await session.claimCurrentDevice(force: true);
      await session.refresh();
      await _reloadProfileState();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Account backup restored. This device is now active.');
    } on SaveTransferException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } on AccountCloudSaveException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Save import failed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saveTransferBusy = false);
    }
  }

  Future<void> _activateThisDevice(AccountSessionService session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return AlertDialog(
          backgroundColor: t.bg2,
          title: Text('Make this the active device?', style: _heading(t)),
          content: Text(
            'This will disable account-based transfer actions on the previously active device.',
            style: _body(t),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'CANCEL',
                style: _label(t).copyWith(color: t.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'TAKE OVER',
                style: _label(t).copyWith(color: t.amberBright),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    _showProgressDialog(
      title: 'ACTIVATING DEVICE',
      message: 'Marking this device as the only active device for the account.',
    );

    try {
      await session.rotateCurrentDeviceId();
      await session.claimCurrentDevice(force: true);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('This device is now active for the account.');
    } on AccountSessionException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    } catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(
        'Could not activate this device: $error',
        isError: true,
      );
    }
  }

  void _showTransferSnack(String message, {bool isError = false}) {
    showAppSnack(message, isError: isError, fallbackContext: context);
  }

  void _showProgressDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: t.bg2,
            title: Text(title, style: _heading(t)),
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.amberBright,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(message, style: _body(t))),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_CredentialDialogResult?> _showCredentialDialog({
    required String title,
    required String submitLabel,
    bool includeDisplayName = false,
  }) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    var obscure = true;

    return showDialog<_CredentialDialogResult>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: t.bg2,
              title: Text(title, style: _heading(t)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (includeDisplayName) ...[
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: t.textPrimary),
                        decoration: _inputDecoration(t, 'Account name'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: TextStyle(color: t.textPrimary),
                      decoration: _inputDecoration(t, 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      autocorrect: false,
                      style: TextStyle(color: t.textPrimary),
                      decoration: _inputDecoration(
                        t,
                        'Password',
                        suffix: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: _label(t).copyWith(color: t.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _CredentialDialogResult(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        displayName: nameController.text.trim(),
                      ),
                    );
                  },
                  child: Text(
                    submitLabel,
                    style: _label(t).copyWith(color: t.amberBright),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<_PasswordDialogResult?> _showPasswordDialog({
    required String title,
    required String submitLabel,
    required String message,
    bool includeNewPassword = false,
  }) async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    var obscureCurrent = true;
    var obscureNew = true;

    return showDialog<_PasswordDialogResult>(
      context: context,
      builder: (context) {
        final t = ForgeTokens(context.read<FactionTheme>());
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: t.bg2,
              title: Text(title, style: _heading(t)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: _body(t)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      autocorrect: false,
                      style: TextStyle(color: t.textPrimary),
                      decoration: _inputDecoration(
                        t,
                        'Current password',
                        suffix: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (includeNewPassword) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: nextController,
                        obscureText: obscureNew,
                        autocorrect: false,
                        style: TextStyle(color: t.textPrimary),
                        decoration: _inputDecoration(
                          t,
                          'New password',
                          suffix: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscureNew = !obscureNew;
                              });
                            },
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: _label(t).copyWith(color: t.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _PasswordDialogResult(
                        currentPassword: currentController.text,
                        newPassword: nextController.text,
                      ),
                    );
                  },
                  child: Text(
                    submitLabel,
                    style: _label(t).copyWith(color: t.amberBright),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    ForgeTokens t,
    String hint, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: t.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: t.bg3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: t.borderDim),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: t.borderDim),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: t.borderAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final audio = context.watch<AudioController>();
    final account = context.watch<AccountService>();
    final accountSession = context.watch<AccountSessionService>();
    final t = ForgeTokens(factionTheme);
    final brightness = Theme.of(context).brightness;

    return ParticleBackgroundScaffold(
      whiteBackground: Theme.of(context).brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingCloseButton(
          onTap: () => Navigator.pop(context),
          theme: factionTheme,
        ),
        body: FutureBuilder<_ProfileData>(
          future: _load,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.amber,
                  ),
                ),
              );
            }

            final data = snap.data!;
            if (data.faction == null) {
              return Center(
                child: Text(
                  'NO FACTION ASSIGNED',
                  style: _label(t).copyWith(color: t.textMuted),
                ),
              );
            }

            final accentColor = _accentFor(data.faction!, brightness);
            final perks = FactionService.catalog[data.faction!]!.perks;

            return SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // ── Screen title ─────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        color: accentColor,
                        margin: const EdgeInsets.only(right: 10),
                      ),
                      Text('PROFILE', style: _heading(t)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openEncyclopedia,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.borderAccent.withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 28,
                            color: t.amberBright,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Faction header ────────────────────────────────────────
                  _ForgePanel(
                    accentBar: accentColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DIVISION: ${data.faction!.name.toUpperCase()}',
                              style: _heading(t).copyWith(color: accentColor),
                            ),
                          ],
                        ),
                        Container(
                          height: 1,
                          color: t.borderDim,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.catching_pokemon_rounded,
                              size: 12,
                              color: t.teal,
                            ),
                            const SizedBox(width: 6),
                            Text('CREATURES DISCOVERED', style: _label(t)),
                            const Spacer(),
                            Text(
                              '${data.discoveredCount}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'DIVISION PERKS'),
                  const SizedBox(height: 14),

                  for (var i = 0; i < perks.length; i++) ...[
                    _ForgePanel(
                      accentBar: accentColor.withValues(alpha: 0.75),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  perks[i].title.toUpperCase(),
                                  style: _label(t).copyWith(
                                    color: accentColor,
                                    fontSize: 11,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(perks[i].description, style: _body(t)),
                        ],
                      ),
                    ),
                    if (i < perks.length - 1) const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'GENERAL SETTINGS'),
                  const SizedBox(height: 14),

                  // ── Appearance ────────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.brightness_4_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Text('APPEARANCE', style: _label(t)),
                        const Spacer(),
                        ThemeModeSelector(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Font style ────────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_fields_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Text('FONT STYLE', style: _label(t)),
                        const Spacer(),
                        _FontSelectorWidget(t: t),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  _ForgePanel(
                    accentBar: t.amber,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.movie_filter_rounded,
                          size: 14,
                          color: t.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CINEMATIC QUALITY', style: _label(t)),
                              const SizedBox(height: 2),
                              Text(
                                'Extraction and hatch visual intensity',
                                style: _body(t).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CinematicQualitySelector(
                          t: t,
                          value: _cinematicQuality,
                          enabled: _cinematicQualityLoaded,
                          onChanged: _setCinematicQuality,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'AUDIO'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.amber,
                    child: Column(
                      children: [
                        _NotificationToggleRow(
                          icon: Icons.volume_up_rounded,
                          title: 'ALL AUDIO',
                          subtitle: 'Master toggle for all music and sound FX',
                          value: audio.masterEnabled,
                          enabled: audio.isLoaded,
                          onChanged: (v) => audio.setMasterEnabled(v),
                          accent: t.amberBright,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.music_note_rounded,
                          title: 'MUSIC',
                          subtitle: 'Looped background tracks',
                          value: audio.musicEnabled,
                          enabled: audio.isLoaded,
                          onChanged: (v) => audio.setMusicEnabled(v),
                          accent: t.amberBright,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.graphic_eq_rounded,
                          title: 'SOUND FX',
                          subtitle: 'Future UI and gameplay sounds',
                          value: audio.soundsEnabled,
                          enabled: audio.isLoaded,
                          onChanged: (v) => audio.setSoundsEnabled(v),
                          accent: t.amberBright,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'NOTIFICATIONS'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.teal,
                    child: Column(
                      children: [
                        _NotificationToggleRow(
                          icon: Icons.science_rounded,
                          title: 'CULTIVATIONS',
                          subtitle: 'Egg ready and extraction-ready alerts',
                          value: _cultivationsEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleCultivations,
                          accent: t.teal,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.explore_rounded,
                          title: 'WILDERNESS',
                          subtitle: 'Wild spawn alerts across biomes',
                          value: _wildernessEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleWilderness,
                          accent: t.teal,
                        ),
                        const SizedBox(height: 8),
                        _NotificationToggleRow(
                          icon: Icons.science_outlined,
                          title: 'EXTRACTIONS',
                          subtitle: 'Biome harvest completion alerts',
                          value: _extractionsEnabled,
                          enabled: _notificationPrefsLoaded,
                          onChanged: _toggleExtractions,
                          accent: t.teal,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'ACCOUNT'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: account.isSignedIn ? t.teal : t.amber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              account.isSignedIn
                                  ? Icons.verified_user_rounded
                                  : Icons.login_rounded,
                              size: 14,
                              color: account.isSignedIn ? t.teal : t.amber,
                            ),
                            const SizedBox(width: 8),
                            Text('TRANSFER ACCOUNT', style: _label(t)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!account.initialized)
                          Text('Loading account services...', style: _body(t))
                        else if (!account.isConfigured)
                          Text(
                            account.configurationError ??
                                'Firebase Auth is not configured yet.',
                            style: _body(t).copyWith(color: t.textMuted),
                          )
                        else if (!account.isSignedIn) ...[
                          Text(
                            'Sign in to unlock cross-device save transfer. This account is only used for transfer and account recovery.',
                            style: _body(t),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ForgeButton(
                                label: 'SIGN IN',
                                icon: Icons.login_rounded,
                                onTap: _signInAccount,
                              ),
                              _ForgeButton(
                                label: 'CREATE ACCOUNT',
                                icon: Icons.person_add_alt_1_rounded,
                                onTap: _createAccount,
                              ),
                            ],
                          ),
                        ] else ...[
                          _AccountValueRow(
                            label: 'ACCOUNT NAME',
                            value: account.displayName,
                          ),
                          const SizedBox(height: 8),
                          _AccountValueRow(
                            label: 'EMAIL',
                            value: account.email,
                          ),
                          const SizedBox(height: 12),
                          _AccountValueRow(
                            label: 'DEVICE STATUS',
                            value: accountSession.state.activeOnThisDevice
                                ? 'ACTIVE ON THIS DEVICE'
                                : 'ACTIVE ON ANOTHER DEVICE',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!accountSession.state.activeOnThisDevice)
                                _ForgeButton(
                                  label: 'USE THIS DEVICE',
                                  icon: Icons.phonelink_lock_rounded,
                                  onTap: () =>
                                      _activateThisDevice(accountSession),
                                ),
                              _ForgeButton(
                                label: 'RENAME',
                                icon: Icons.badge_rounded,
                                onTap: () => _renameAccount(account),
                              ),
                              _ForgeButton(
                                label: 'PASSWORD',
                                icon: Icons.password_rounded,
                                onTap: () => _changePassword(account),
                              ),
                              _ForgeButton(
                                label: 'SIGN OUT',
                                icon: Icons.logout_rounded,
                                onTap: () => _signOutAccount(account),
                              ),
                              _ForgeButton(
                                label: 'DELETE ACCOUNT',
                                icon: Icons.delete_forever_rounded,
                                onTap: () => _deleteAccount(account),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'ACCOUNT BACKUP'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.amberBright,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_upload_rounded,
                              size: 14,
                              color: t.amberBright,
                            ),
                            const SizedBox(width: 8),
                            Text('CLOUD SAVE', style: _label(t)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !account.isSignedIn
                              ? 'Sign in with your transfer account before backing up or restoring saves.'
                              : !accountSession.state.activeOnThisDevice
                              ? 'This account is active on another device. Move the account here from the account-moved screen to restore the latest cloud backup.'
                              : 'Back up this device save to your account. Then sign into the same account on another device and restore it there.',
                          style: _body(t),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ForgeButton(
                              label: _saveTransferBusy
                                  ? 'WORKING...'
                                  : 'BACK UP',
                              icon: Icons.cloud_upload_rounded,
                              onTap:
                                  _saveTransferBusy ||
                                      !account.initialized ||
                                      !account.isConfigured ||
                                      !account.isSignedIn ||
                                      !accountSession.state.activeOnThisDevice
                                  ? null
                                  : _exportSave,
                            ),
                            _ForgeButton(
                              label: _saveTransferBusy
                                  ? 'WORKING...'
                                  : 'RESTORE',
                              icon: Icons.cloud_download_rounded,
                              onTap:
                                  _saveTransferBusy ||
                                      !account.initialized ||
                                      !account.isConfigured ||
                                      !account.isSignedIn ||
                                      !accountSession.state.activeOnThisDevice
                                  ? null
                                  : _importSave,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _EtchedDivider(label: 'STORY'),
                  const SizedBox(height: 14),

                  _ForgePanel(
                    accentBar: t.teal,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COSMIC NOTES',
                          style: _label(t).copyWith(color: t.teal),
                        ),
                        const SizedBox(height: 8),
                        _buildCosmicHintsCarousel(t, data.cosmicHints),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Replay intro ──────────────────────────────────────────
                  _ForgePanel(
                    accentBar: t.teal,
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.movie_filter_rounded,
                          size: 14,
                          color: t.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('REPLAY INTRO', style: _label(t)),
                              const SizedBox(height: 2),
                              Text(
                                'Watch the origin story again',
                                style: _body(t).copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ForgeButton(
                          label: 'WATCH',
                          icon: Icons.play_arrow_rounded,
                          onTap: _replayStory,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _accentFor(FactionId id, Brightness brightness) =>
      factionThemeFor(id, brightness: brightness).accent;
}

// ──────────────────────────────────────────────────────────────────────────────
// FONT SELECTOR
// ──────────────────────────────────────────────────────────────────────────────

class _FontSelectorWidget extends StatelessWidget {
  final ForgeTokens t;
  const _FontSelectorWidget({required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final fontKeys = appFontMap.keys.toList();
    final currentValue = fontKeys.contains(theme.fontName)
        ? theme.fontName
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          icon: Icon(Icons.arrow_drop_down, color: t.amber, size: 18),
          dropdownColor: t.bg2,
          isDense: true,
          onChanged: (String? newValue) {
            if (newValue != null) {
              context.read<ThemeNotifier>().setFont(newValue);
            }
          },
          items: fontKeys.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: GoogleFonts.getFont(
                  value,
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (context) => fontKeys.map((String value) {
            return Center(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CinematicQualitySelector extends StatelessWidget {
  final ForgeTokens t;
  final CinematicQuality value;
  final bool enabled;
  final Future<void> Function(CinematicQuality value) onChanged;

  const _CinematicQualitySelector({
    required this.t,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  String _labelFor(CinematicQuality quality) {
    return switch (quality) {
      CinematicQuality.high => 'HIGH',
      CinematicQuality.balanced => 'BALANCED',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderDim),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<CinematicQuality>(
            value: value,
            icon: Icon(Icons.arrow_drop_down, color: t.amber, size: 18),
            dropdownColor: t.bg2,
            isDense: true,
            onChanged: enabled
                ? (next) {
                    if (next == null) return;
                    HapticFeedback.selectionClick();
                    onChanged(next);
                  }
                : null,
            items: CinematicQuality.values
                .map(
                  (q) => DropdownMenuItem<CinematicQuality>(
                    value: q,
                    child: Text(
                      _labelFor(q),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Future<void> Function(bool value) onChanged;
  final Color accent;

  const _NotificationToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _label(t)),
              const SizedBox(height: 2),
              Text(subtitle, style: _body(t).copyWith(fontSize: 10)),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Switch.adaptive(
              value: value,
              activeColor: accent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _AccountValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _label(t)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────────
// DATA
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileData {
  final FactionId? faction;
  final int discoveredCount;
  final List<CosmicContestHintLore> cosmicHints;
  const _ProfileData(this.faction, this.discoveredCount, this.cosmicHints);
}

class _CredentialDialogResult {
  final String email;
  final String password;
  final String displayName;

  const _CredentialDialogResult({
    required this.email,
    required this.password,
    this.displayName = '',
  });
}

class _PasswordDialogResult {
  final String currentPassword;
  final String newPassword;

  const _PasswordDialogResult({
    required this.currentPassword,
    this.newPassword = '',
  });
}

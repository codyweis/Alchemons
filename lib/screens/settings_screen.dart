// lib/screens/settings_screen.dart
//
// SETTINGS, from the gear in the profile's top bar: how the game is set up.
//
//   Display, sound, notifications, the account and its save, a fresh
//   start, the privacy policy, and — in a debug build or on a developer's
//   account — the developer switches.
//
// Until 2026-11-23 these were the lower half of the profile, under the
// journal; the profile is now who you are and who you know. A part of the
// profile's library, so it is laid out with the profile's own sections,
// rows, buttons and dialogs.

part of 'profile_screen.dart';

const Color _kDanger = Color(0xFFE57373);

/// "4 minutes ago": when the game last went up to the account.
String _savedAgo(DateTime at) {
  final d = DateTime.now().difference(at);
  String ago(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return ago(d.inMinutes, 'minute');
  if (d.inDays < 1) return ago(d.inHours, 'hour');
  return ago(d.inDays, 'day');
}

// ──────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationPreferencesService _notificationPrefs =
      NotificationPreferencesService();
  final CinematicQualityService _cinematicQualityService =
      CinematicQualityService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  bool _cultivationsEnabled = true;
  bool _wildernessEnabled = true;
  bool _extractionsEnabled = true;
  bool _notificationPrefsLoaded = false;
  CinematicQuality _cinematicQuality = CinematicQuality.cinematic;
  bool _cinematicQualityLoaded = false;
  final DebugSettingsService _debugSettings = DebugSettingsService();
  bool _debugToolsEnabled = false;
  bool _debugToolsLoaded = false;
  bool _freeShop = false;
  bool _saveTransferBusy = false;

  /// The account this device's game belongs to (null: a guest game).
  String? _saveOwner;

  /// Signed in, but the game on this device is another account's: it can't
  /// be made active, backed up or bought into from this account.
  bool _ownedElsewhere(AccountService account) =>
      _saveOwner != null &&
      account.user != null &&
      account.user!.uid != _saveOwner;

  Future<void> _loadSaveOwner() async {
    final owner = await SaveGenerationService.owner(
      context.read<AlchemonsDatabase>(),
    );
    if (mounted) setState(() => _saveOwner = owner);
  }

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
    _loadCinematicQuality();
    _loadDebugTools();
    _loadSaveOwner();
    DebugSettingsService.allowedNotifier.addListener(_onDebugToolsAllowed);
  }

  /// Signing in or out of a developer's account shows or hides the
  /// DEVELOPER section, and the switch takes effect with it.
  void _onDebugToolsAllowed() {
    if (!mounted) return;
    setState(() => _debugToolsEnabled = DebugSettingsService.toolsVisible);
  }

  @override
  void dispose() {
    DebugSettingsService.allowedNotifier.removeListener(_onDebugToolsAllowed);
    super.dispose();
  }

  BracketPalette get _palette =>
      BracketPalette.fromTheme(context.read<FactionTheme>());

  Color get _accent => bracketReadableAccent(context.read<FactionTheme>());

  /// Reopens the faction picker so it can be seen again.
  ///
  /// The picker is normally the first thing in the game and runs exactly
  /// once per save, which makes it the hardest screen here to look at
  /// twice. This is a bypass of the shop's paid faction change on purpose:
  /// it is for looking at the picker, not for playing.
  Future<void> _openFactionTester() async {
    final before = context.read<FactionService>().current;
    final selected = await showDialog<FactionId>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FactionPickerDialog(),
    );
    if (!mounted || selected == null) return;
    showGameSnack(
      context,
      selected == before
          ? 'Faction unchanged — ${selected.name}'
          : 'Faction set to ${selected.name}',
    );
  }

  Future<void> _bringWeather(
    String sceneId,
    WeatherKind kind,
    String what,
  ) async {
    HapticFeedback.mediumImpact();
    final came = await context.read<WildernessSpawnService>().debugBringWeather(
      sceneId,
      kind,
    );
    if (!mounted) return;
    showGameSnack(
      context,
      came ? '$what has come' : 'No $what — that region is not open yet',
    );
  }

  Future<void> _advanceVolcano() async {
    HapticFeedback.mediumImpact();
    final next = await context
        .read<WildernessSpawnService>()
        .debugAdvanceFieldStage('volcano', volcanoScene);
    if (!mounted) return;
    final mood = switch (next) {
      VolcanoField.smoking => 'smoking',
      VolcanoField.erupting => 'erupting',
      _ => 'quiet',
    };
    showGameSnack(context, 'The next visit finds the Volcano $mood');
  }

  Future<void> _owedAftermath(String sceneId, String message) async {
    HapticFeedback.mediumImpact();
    await context.read<WildernessSpawnService>().debugSetAftermath(sceneId);
    if (!mounted) return;
    showGameSnack(context, message);
  }

  Future<void> _openAbilityLab() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AbilityLabScreen()),
    );
  }

  Future<void> _openAbilityReel() => AbilityReelScreen.open(context);

  /// The first descent's cinematic again, over a planet picked at random
  /// (any finished one but Blood, the last), with the space party. It is
  /// the real descent's page: the portal is its loading screen while the
  /// realms are pictured, then the run goes on as any run does. Seeing it
  /// again is not saved.
  Future<void> _playFirstDescent() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Alchemons to take down with you.')),
      );
      return;
    }
    final planets = [
      for (final e in kPolishedDungeons)
        if (e != kBloodPlanetElement && kPlanetDungeonLayouts.containsKey(e)) e,
    ];
    final element = planets[math.Random().nextInt(planets.length)];
    final ready = ValueNotifier<bool>(false);
    final revealed = ValueNotifier<bool>(false);
    // The portal opens onto the page once it is ready; the cinematic's
    // first seconds are the Valley alone, so it may begin as it opens.
    void shown() {
      if (ready.value) revealed.value = true;
    }

    ready.addListener(shown);
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: PlanetDungeonScreen(
        element: element,
        party: party.take(3).toList(),
        replayReveal: true,
        revealReady: ready,
        revealed: revealed,
      ),
      title: kPlanetDungeonLayouts[element]?.descentTitle ?? element,
      label: 'DESCENDING',
      element: element,
      ready: ready,
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
    ready.removeListener(shown);
    ready.dispose();
    revealed.dispose();
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// The finale again, after the Blood Ring's ritual: the space party's
  /// first Alchemon offered, the credits over the census of this save.
  /// Nothing happens to the Alchemon and nothing is saved.
  Future<void> _playFinale() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No Alchemons to offer.')));
      return;
    }
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: BloodFinalePage(offering: party.first),
      title: 'The Blood Ring',
      label: 'ENTERING',
      element: 'Blood',
      orientation: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// The Bloodborn Vial and its extraction, for the space party's first
  /// Alchemon, without the ending. Not saved.
  Future<void> _openBloodbornVial() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    if (party.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No Alchemons to offer.')));
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BloodbornVialDebugScreen(instanceId: party.first.instanceId),
      ),
    );
  }

  Future<void> _openDungeonDebug() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const DungeonDebugScreen()),
    );
  }

  /// The stadium, turned on its side as it is from space; home's music
  /// again after.
  Future<void> _openStadium() async {
    HapticFeedback.mediumImpact();
    final party = await stadiumPartyFromSave(context);
    if (!mounted) return;
    await VoidPortal.pushThroughGlyphs<void>(
      context,
      page: StadiumScreen(party: party),
      title: 'The Trials',
      element: 'Light',
    );
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  /// A battle against the computer; home's music again after.
  Future<void> _openBattle() async {
    HapticFeedback.mediumImpact();
    await openBattleAgainstComputer(context);
    if (!mounted) return;
    unawaited(context.read<AudioController>().playHomeMusic());
  }

  Future<void> _openAltars() async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AltarLevelsScreen()),
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

  Future<void> _loadDebugTools() async {
    final enabled = await _debugSettings.isEnabled();
    final freeShop = await _debugSettings.isFreeShop();
    // Hydrates the notifier the WILD MUTATION row listens to.
    await _debugSettings.forcedWildMutation();
    if (!mounted) return;
    setState(() {
      _debugToolsEnabled = enabled;
      _freeShop = freeShop;
      _debugToolsLoaded = true;
    });
  }

  Future<void> _setDebugTools(bool value) async {
    setState(() => _debugToolsEnabled = value);
    await _debugSettings.setEnabled(value);
  }

  Future<void> _setFreeShop(bool value) async {
    setState(() => _freeShop = value);
    await _debugSettings.setFreeShop(value);
  }

  Future<void> _setForcedMutation(String? id) =>
      _debugSettings.setForcedWildMutation(id);

  /// After a restore: everything here is read again from the new save.
  Future<void> _reloadSettings() async {
    if (!mounted) return;
    await _loadSaveOwner();
    await _loadNotificationPrefs();
    await _loadCinematicQuality();
  }

  // ───────────────────────────── account ──────────────────────────────────

  Future<void> _createAccount() async {
    await _loadSaveOwner();
    if (!mounted) return;
    if (_saveOwner != null) {
      // A new account can't take over a game another account owns.
      _showTransferSnack(
        'The game on this device belongs to another account. Sign into that '
        'account to keep playing it, or reset progress to start a new game, '
        'then create your new account.',
        isError: true,
      );
      return;
    }
    final accountService = context.read<AccountService>();
    final sessionService = context.read<AccountSessionService>();
    final autosave = context.read<CloudAutosaveService>();
    final done = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _CredentialDialog(
        title: 'CREATE ACCOUNT',
        submitLabel: 'CREATE',
        includeDisplayName: true,
        message:
            'The game on this device becomes the account\'s save, and saves '
            'to it from now on.',
        submit: (result) async {
          try {
            await accountService.createAccount(
              email: result.email,
              password: result.password,
              displayName: result.displayName,
            );
          } on AccountException catch (error) {
            return error.message;
          }
          try {
            await sessionService.claimCurrentDevice(force: true);
          } catch (error) {
            // Signed in should always mean this device plays the account.
            await accountService.signOut();
            return 'Your account was created, but this device could not be '
                'linked to it: $error Use SIGN IN to finish.';
          }
          return null;
        },
      ),
    );
    if (done != true || !mounted) return;
    unawaited(autosave.save());
    await _loadSaveOwner();
    _showTransferSnack('Account created. Your game now saves to it.');
  }

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://alchemons.com/privacy/',
  );

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      _privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showTransferSnack(
        'Couldn\'t open the browser. The policy is at alchemons.com/privacy.',
        isError: true,
      );
    }
  }

  bool _resetBusy = false;

  Future<void> _resetProgress() async {
    if (_resetBusy) return;
    setState(() => _resetBusy = true);
    final account = context.read<AccountService>();
    final store = context.read<MobileStoreService>();
    final reset = ProgressResetService(context.read<AlchemonsDatabase>());
    final uid = account.user?.uid;
    try {
      if (!account.initialized) {
        throw StateError('Please wait for your account to finish loading.');
      }
      final deviceId = await context
          .read<DeviceIdentityService>()
          .getDeviceId();
      await _loadSaveOwner();
      // Another account's game is reset locally only: the server reset belongs
      // to the account that owns the game. The fresh game is a guest game this
      // account can then make its own.
      final serverUid = _ownedElsewhere(account) ? null : uid;
      await store.pauseForReset();
      final preview = serverUid == null ? null : await reset.preview(deviceId);
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => ResetProgressDialog(
          purchasedGold: (preview?['goldAmount'] as num?)?.toInt(),
        ),
      );
      if (!mounted) return;
      if (choice == 'sign-in') {
        store.cancelResetPause();
        await _signInAccount();
      } else if (choice == 'reset') {
        if (account.user?.uid != uid) {
          throw StateError('Your account changed. Review the reset again.');
        }
        await store.pauseForReset();
        await reset.request(
          uid: serverUid,
          deviceId: deviceId,
          preview: preview,
        );
      }
    } catch (error) {
      if (mounted) {
        _showTransferSnack('Reset could not start: $error', isError: true);
      }
    } finally {
      store.cancelResetPause();
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Future<void> _signInAccount() async {
    final done = await _signInWithDialog(context);
    if (done == null || !mounted) return;
    await _loadSaveOwner();
    if (done.result == SignInResult.restored) await _reloadSettings();
    _showTransferSnack(_signedInText(done.result));
  }

  Future<void> _renameAccount(AccountService account) async {
    final controller = TextEditingController(text: account.displayName);
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _FormDialog(
        title: 'ACCOUNT NAME',
        submitLabel: 'SAVE',
        onSubmit: () => Navigator.pop(context, controller.text.trim()),
        children: [
          _FormField(
            controller: controller,
            hint: 'Display name',
            autofocus: true,
          ),
        ],
      ),
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
      title: 'CHANGE PASSWORD',
      submitLabel: 'UPDATE',
      includeNewPassword: true,
      message: 'Enter your current password, then choose a new one.',
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
      title: 'DELETE ACCOUNT',
      submitLabel: 'DELETE',
      message:
          'This removes your Firebase account. Local game progress on this device is not deleted automatically.',
    );
    if (!mounted || result == null) return;

    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _kDanger,
      title: 'DELETE ACCOUNT?',
      message:
          'You will lose account-based save transfer until you create another account.',
      warning: 'This cannot be undone.',
      confirmLabel: 'DELETE',
    );

    if (!confirmed || !mounted) return;

    _showProgressDialog(
      title: 'DELETING ACCOUNT',
      message: 'Removing your account credentials.',
    );
    try {
      final friends = context.read<FriendService>();
      final trades = context.read<TradeService>();
      await account.deleteAccount(
        currentPassword: result.currentPassword,
        // What they have up on trade tables comes back, their planet and
        // home come down, and they leave every friend's list; a failure
        // there must not keep the account from going.
        beforeDelete: () async {
          await trades.forget().timeout(const Duration(seconds: 20)).catchError(
            (Object e) {
              debugPrint('Trades cleanup before account deletion failed: $e');
            },
          );
          await friends
              .forget()
              .timeout(const Duration(seconds: 20))
              .catchError((Object e) {
                debugPrint(
                  'Friends cleanup before account deletion failed: $e',
                );
              });
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack('Account deleted.');
    } on AccountException catch (error) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _signOutAccount(AccountService account) async {
    final autosave = context.read<CloudAutosaveService>();
    if (autosave.enabled) {
      _showProgressDialog(
        title: 'SIGNING OUT',
        message: 'Saving your game to your account first.',
      );
      final saved = await autosave.save();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (!saved) {
        final confirmed = await showBracketConfirm(
          context,
          palette: _palette,
          accent: _kDanger,
          title: 'SIGN OUT WITHOUT SAVING?',
          message:
              autosave.error ?? 'Your game could not be saved to your account.',
          warning: 'Progress since the last save stays only on this device.',
          confirmLabel: 'SIGN OUT',
        );
        if (!confirmed || !mounted) return;
      }
    }
    try {
      await account.signOut();
      await _loadSaveOwner();
      _showTransferSnack('Signed out.');
    } on AccountException catch (error) {
      _showTransferSnack(error.message, isError: true);
    }
  }

  Future<void> _saveNow() async {
    final autosave = context.read<CloudAutosaveService>();
    final saved = await autosave.save(force: true);
    if (!mounted) return;
    _showTransferSnack(
      saved
          ? 'Saved to your account.'
          : autosave.error ?? 'Could not save to your account.',
      isError: !saved,
    );
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
    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _accent,
      title: 'RESTORE HERE?',
      message:
          'This replaces the game on this device with the account\'s latest save, and makes this the account\'s device.',
      warning:
          'Progress on this device is lost unless it has been backed up somewhere else.',
      confirmLabel: 'RESTORE',
    );

    if (!confirmed || !mounted) return;

    setState(() => _saveTransferBusy = true);
    _showProgressDialog(
      title: 'RESTORING',
      message: 'Bringing the account\'s latest save to this device.',
    );
    try {
      final db = context.read<AlchemonsDatabase>();
      final cloudSave = context.read<AccountCloudSaveService>();
      await context.read<CloudAutosaveService>().hold(() async {
        final transferCode = await cloudSave.downloadSaveCode(
          account.user!.uid,
        );
        await SaveTransferService(
          db,
        ).importSaveCode(transferCode, ownerAccountId: account.user!.uid);
        if (mounted) await reloadStateAfterSaveRestore(context);
        // A fresh device identity only once the backup is in: rotating first
        // left a failed download with this device silently deactivated.
        await session.rotateCurrentDeviceId();
        await session.claimCurrentDevice(force: true);
        await session.refresh();
      });
      if (!mounted) return;
      await _reloadSettings();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showTransferSnack('Your account\'s save is on this device now.');
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

  void _showTransferSnack(String message, {bool isError = false}) {
    showAppSnack(message, isError: isError, fallbackContext: context);
  }

  void _showProgressDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => PopScope(
        canPop: false,
        child: _DialogShell(
          title: title,
          children: [
            Row(
              children: [
                GrainLoader(size: 18, color: _accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(message, style: _prose(context, _palette.ink)),
                ),
              ],
            ),
          ],
        ),
      ),
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

    return showDialog<_PasswordDialogResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _FormDialog(
        title: title,
        message: message,
        submitLabel: submitLabel,
        onSubmit: () => Navigator.pop(
          context,
          _PasswordDialogResult(
            currentPassword: currentController.text,
            newPassword: nextController.text,
          ),
        ),
        children: [
          _FormField(
            controller: currentController,
            hint: 'Current password',
            secret: true,
          ),
          if (includeNewPassword) ...[
            const SizedBox(height: 10),
            _FormField(
              controller: nextController,
              hint: 'New password',
              secret: true,
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final factionTheme = context.watch<FactionTheme>();
    final audio = context.watch<AudioController>();
    final account = context.watch<AccountService>();
    final accountSession = context.watch<AccountSessionService>();
    final palette = BracketPalette.fromTheme(factionTheme);
    final accent = bracketReadableAccent(factionTheme);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: palette.bg0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
            child: Row(
              children: [
                BracketIconButton(
                  icon: AppIcons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  palette: palette,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('SETTINGS', style: _mono(13, palette.ink)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 40),
              children: [
                _Section(
                  label: 'DISPLAY',
                  palette: palette,
                  children: [
                    _Row(
                      title: 'FONT',
                      description: 'The typeface for names and text',
                      palette: palette,
                      below: _FontChoice(palette: palette, accent: accent),
                    ),
                    _Row(
                      title: 'VISUAL EFFECTS',
                      description:
                          'Performance trims the fusion, hatch and '
                          'essence cinematics for slower phones',
                      palette: palette,
                      below: Opacity(
                        opacity: _cinematicQualityLoaded ? 1 : 0.45,
                        child: IgnorePointer(
                          ignoring: !_cinematicQualityLoaded,
                          child: _Choice<CinematicQuality>(
                            options: const [
                              (CinematicQuality.cinematic, 'CINEMATIC'),
                              (CinematicQuality.performance, 'PERFORMANCE'),
                            ],
                            value: _cinematicQuality,
                            onChanged: _setCinematicQuality,
                            palette: palette,
                            accent: accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                _Section(
                  label: 'SOUND',
                  palette: palette,
                  children: [
                    BracketToggleRow(
                      title: 'ALL SOUND',
                      description: 'Music and sound effects together',
                      value: audio.masterEnabled,
                      enabled: audio.isLoaded,
                      onChanged: audio.setMasterEnabled,
                      palette: palette,
                      accent: accent,
                    ),
                    BracketToggleRow(
                      title: 'MUSIC',
                      description: 'Background tracks',
                      value: audio.musicEnabled,
                      enabled: audio.isLoaded,
                      onChanged: audio.setMusicEnabled,
                      palette: palette,
                      accent: accent,
                    ),
                    BracketToggleRow(
                      title: 'SOUND EFFECTS',
                      description: 'Taps, alchemy and creatures',
                      value: audio.soundsEnabled,
                      enabled: audio.isLoaded,
                      onChanged: audio.setSoundsEnabled,
                      palette: palette,
                      accent: accent,
                    ),
                    BracketToggleRow(
                      title: 'HAPTICS',
                      description:
                          'Vibration when you act, get hit or earn a star',
                      value: audio.hapticsEnabled,
                      enabled: audio.isLoaded,
                      onChanged: audio.setHapticsEnabled,
                      palette: palette,
                      accent: accent,
                    ),
                  ],
                ),

                _Section(
                  label: 'NOTIFICATIONS',
                  palette: palette,
                  children: [
                    BracketToggleRow(
                      title: 'CULTIVATIONS',
                      description: 'When a vial is ready to extract',
                      value: _cultivationsEnabled,
                      enabled: _notificationPrefsLoaded,
                      onChanged: _toggleCultivations,
                      palette: palette,
                      accent: accent,
                    ),
                    BracketToggleRow(
                      title: 'WILDERNESS',
                      description: 'When wild Alchemons appear',
                      value: _wildernessEnabled,
                      enabled: _notificationPrefsLoaded,
                      onChanged: _toggleWilderness,
                      palette: palette,
                      accent: accent,
                    ),
                    BracketToggleRow(
                      title: 'ESSENCE',
                      description: 'When a chamber of essence is full',
                      value: _extractionsEnabled,
                      enabled: _notificationPrefsLoaded,
                      onChanged: _toggleExtractions,
                      palette: palette,
                      accent: accent,
                    ),
                  ],
                ),

                _Section(
                  label: 'ACCOUNT',
                  palette: palette,
                  children: [
                    _accountRow(account, accountSession, palette, accent),
                    _cloudSaveRow(
                      account,
                      accountSession,
                      context.watch<CloudAutosaveService>(),
                      palette,
                      accent,
                    ),
                  ],
                ),

                _Section(
                  label: 'FRESH START',
                  palette: palette,
                  children: [
                    _Row(
                      title: 'RESET PROGRESS',
                      description:
                          'Start a new game. Your account and verified '
                          'gold purchases are kept.',
                      palette: palette,
                      trailing: _QuietButton(
                        label: _resetBusy ? 'CHECKING…' : 'RESET',
                        enabled: !_resetBusy,
                        palette: palette,
                        accent: accent,
                        onTap: _resetProgress,
                      ),
                    ),
                  ],
                ),

                _Section(
                  label: 'ABOUT',
                  palette: palette,
                  children: [
                    _Row(
                      title: 'PRIVACY POLICY',
                      description: 'What the game stores and why',
                      palette: palette,
                      trailing: _QuietButton(
                        label: 'OPEN',
                        palette: palette,
                        accent: accent,
                        onTap: _openPrivacyPolicy,
                      ),
                    ),
                  ],
                ),

                // Every debug or profile build; in a release build only
                // a developer's account (DebugSettingsService).
                if (DebugSettingsService.toolsAllowed)
                  _Section(
                    label: 'DEVELOPER',
                    palette: palette,
                    children: [
                      BracketToggleRow(
                        title: 'DEBUG TOOLS',
                        description:
                            'Testing shortcuts in the cosmos: unseal a '
                            'gate, and descend with a planet\'s ideal trio',
                        value: _debugToolsEnabled,
                        enabled: _debugToolsLoaded,
                        onChanged: _setDebugTools,
                        palette: palette,
                        accent: accent,
                      ),
                      // Gated on the switch above rather than on
                      // DebugSettingsService.toolsVisible: these rows sit
                      // directly under the control that governs them, so
                      // appearing in a debug build with the switch OFF
                      // would read as the switch being broken.
                      if (_debugToolsEnabled) ...[
                        BracketToggleRow(
                          title: 'FREE SHOP',
                          description:
                              'Every shop purchase costs nothing while the '
                              'debug tools are on',
                          value: _freeShop,
                          enabled: _debugToolsLoaded,
                          onChanged: _setFreeShop,
                          palette: palette,
                          accent: accent,
                        ),
                        // Re-reads the setting when a fusion spends it, so
                        // the row goes back to OFF on its own.
                        ValueListenableBuilder<String?>(
                          valueListenable:
                              DebugSettingsService.forcedWildMutationNotifier,
                          builder: (context, forced, _) => _Row(
                            title: 'WILD MUTATION',
                            description:
                                'The next successful wilderness fusion '
                                'comes out mutated, then this turns off',
                            palette: palette,
                            trailing: _WildMutationSelector(
                              palette: palette,
                              accent: accent,
                              value: forced,
                              enabled: _debugToolsLoaded,
                              onChanged: _setForcedMutation,
                            ),
                          ),
                        ),
                        for (final tool in _debugActions())
                          _Row(
                            title: tool.title,
                            description: tool.description,
                            palette: palette,
                            trailing: _QuietButton(
                              label: tool.action,
                              height: 34,
                              palette: palette,
                              accent: accent,
                              onTap: tool.onTap,
                            ),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(
    AccountService account,
    AccountSessionService session,
    BracketPalette palette,
    Color accent,
  ) {
    if (!account.initialized) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description: 'Loading account services…',
        palette: palette,
      );
    }
    if (!account.isConfigured) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description:
            account.configurationError ??
            'Firebase Auth is not configured yet.',
        palette: palette,
      );
    }
    if (!account.isSignedIn) {
      return _Row(
        title: 'TRANSFER ACCOUNT',
        description:
            'Sign in to move your save between devices. The account is only '
            'used for transfer and recovery.',
        palette: palette,
        below: Row(
          children: [
            Expanded(
              child: BracketButton(
                label: 'SIGN IN',
                height: 40,
                palette: palette,
                accent: accent,
                onTap: _signInAccount,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuietButton(
                label: 'CREATE ACCOUNT',
                height: 40,
                palette: palette,
                accent: accent,
                onTap: _createAccount,
              ),
            ),
          ],
        ),
      );
    }

    final activeHere = session.state.activeOnThisDevice;
    final ownedElsewhere = _ownedElsewhere(account);
    return _Row(
      title: 'TRANSFER ACCOUNT',
      palette: palette,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Reading(label: 'NAME', value: account.displayName, palette: palette),
          _Reading(label: 'EMAIL', value: account.email, palette: palette),
          _Reading(
            label: 'THIS DEVICE',
            value: !session.state.initialized
                ? 'Checking…'
                : activeHere
                ? 'Active · saving to your account'
                : ownedElsewhere
                ? 'Not active · this game belongs to another account'
                : 'Not active · the account is on another device',
            palette: palette,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Each as wide as its word: a wrap would stretch them.
              for (final button in [
                _QuietButton(
                  label: 'RENAME',
                  palette: palette,
                  accent: accent,
                  onTap: () => _renameAccount(account),
                ),
                _QuietButton(
                  label: 'PASSWORD',
                  palette: palette,
                  accent: accent,
                  onTap: () => _changePassword(account),
                ),
                _QuietButton(
                  label: 'SIGN OUT',
                  palette: palette,
                  accent: accent,
                  onTap: () => _signOutAccount(account),
                ),
                _QuietButton(
                  label: 'DELETE ACCOUNT',
                  palette: palette,
                  accent: accent,
                  onTap: () => _deleteAccount(account),
                ),
              ])
                IntrinsicWidth(child: button),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cloudSaveRow(
    AccountService account,
    AccountSessionService session,
    CloudAutosaveService autosave,
    BracketPalette palette,
    Color accent,
  ) {
    if (!account.isSignedIn) {
      return _Row(
        title: 'CLOUD SAVE',
        description:
            'Sign in to keep your game saved to an account, for a lost phone '
            'or a new one.',
        palette: palette,
      );
    }
    if (!session.state.initialized) {
      return _Row(
        title: 'CLOUD SAVE',
        description: 'Checking your account…',
        palette: palette,
      );
    }
    final ownedElsewhere = _ownedElsewhere(account);
    if (ownedElsewhere || !session.state.activeOnThisDevice) {
      return _Row(
        title: 'CLOUD SAVE',
        description: ownedElsewhere
            ? 'The game on this device belongs to a different account, so it '
                  'doesn\'t save to this one. Restore brings this account\'s '
                  'save here and replaces it.'
            : 'Your account is playing on another device, so progress here '
                  'doesn\'t save to it. Restore brings the account\'s latest '
                  'save here and replaces this game.',
        palette: palette,
        below: BracketButton(
          label: _saveTransferBusy ? 'WORKING…' : 'RESTORE',
          height: 40,
          enabled: !_saveTransferBusy && account.isConfigured,
          palette: palette,
          accent: accent,
          onTap: _importSave,
        ),
      );
    }
    final savedAt = autosave.savedAt;
    final error = autosave.saving ? null : autosave.error;
    return _Row(
      title: 'CLOUD SAVE',
      description: 'Your game saves to your account when you leave the app.',
      palette: palette,
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Reading(
            label: 'LAST SAVED',
            value: autosave.saving
                ? 'Saving…'
                : savedAt == null
                ? 'Not yet'
                : _savedAgo(savedAt),
            palette: palette,
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: _prose(context, _kDanger)),
          ],
          const SizedBox(height: 12),
          IntrinsicWidth(
            child: _QuietButton(
              label: 'SAVE NOW',
              enabled: !autosave.saving,
              palette: palette,
              accent: accent,
              onTap: _saveNow,
            ),
          ),
        ],
      ),
    );
  }

  /// 99 → full → empty → 99: the meter's three useful states, in turn.
  Future<void> _cycleMutationMeter() async {
    final dao = context.read<AlchemonsDatabase>().settingsDao;
    final now = await dao.getMutationMeter();
    final next = now >= kMutationMeterNotches
        ? 0
        : now == kMutationMeterNotches - 1
        ? kMutationMeterNotches
        : kMutationMeterNotches - 1;
    await dao.setMutationMeter(next);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Mutation meter: $next / $kMutationMeterNotches')),
    );
  }

  List<_DebugAction> _debugActions() => [
    _DebugAction(
      'MUTATION METER',
      'Set the meter to one short of full, so the next wild fusion has 10%; '
          'tap again to fill it, then to empty it. Needs its node',
      'CYCLE',
      _cycleMutationMeter,
    ),
    _DebugAction(
      'BATTLE',
      'Fight the computer, two at a time from four: tap specials, call in '
          'the bench, two swaps',
      'OPEN',
      _openBattle,
    ),
    _DebugAction(
      'TRIALS',
      'Open the Trials with your space party, without flying there',
      'OPEN',
      _openStadium,
    ),
    _DebugAction(
      'ALCHEMY',
      'Fusion puzzles in levels, chapter by chapter through the realms',
      'OPEN',
      _openAltars,
    ),
    _DebugAction(
      'ABILITY LAB',
      'Test every Alchemon\'s attacks and special in the practice arena, '
          'at any stat band',
      'OPEN',
      _openAbilityLab,
    ),
    _DebugAction(
      'ABILITY REEL',
      'Every Alchemon\'s special, one after another in one arena: pause, '
          'step, cast again, filter by family, jump to any',
      'PLAY',
      _openAbilityReel,
    ),
    _DebugAction(
      'FIRST DESCENT',
      'Play the first descent\'s cinematic again: the realms fall away '
          'over a random planet, with your space party. Not saved',
      'PLAY',
      _playFirstDescent,
    ),
    _DebugAction(
      'FINALE',
      'Play the ending after the Blood Ring again: your space party\'s '
          'first Alchemon remade, the credits over your census. Not saved',
      'PLAY',
      _playFinale,
    ),
    _DebugAction(
      'BLOODBORN VIAL',
      'Your space party\'s first Alchemon as a Bloodborn Vial in its '
          'chamber, at four stages, and its extraction. Not saved',
      'OPEN',
      _openBloodbornVial,
    ),
    _DebugAction(
      'DUNGEON DEBUG',
      'Drop straight into any of the ${kPlanetDungeonLayouts.length} built '
          'dungeons with its ideal trio',
      'OPEN',
      _openDungeonDebug,
    ),
    _DebugAction(
      'SKY STORM',
      'Replace the Sky\'s spawns with a batch that comes with a lightning '
          'storm',
      'BRING',
      () => _bringWeather('sky', WeatherKind.storm, 'The storm'),
    ),
    _DebugAction(
      'VALLEY RAIN',
      'Replace the Valley\'s spawns with a batch that comes with rain',
      'BRING',
      () => _bringWeather('valley', WeatherKind.rain, 'The rain'),
    ),
    _DebugAction(
      'VALLEY SNOW',
      'Replace the Valley\'s spawns with a batch that comes with snow',
      'BRING',
      () => _bringWeather('valley', WeatherKind.snow, 'The snow'),
    ),
    _DebugAction(
      'VALLEY RAINBOW',
      'Make the next clear visit to the Valley find a rainbow',
      'SET',
      () => _owedAftermath(
        'valley',
        'The next clear visit to the Valley has a rainbow',
      ),
    ),
    _DebugAction(
      'SWAMP DRY',
      'Replace the Swamp\'s spawns with a batch that finds it dried out',
      'BRING',
      () => _bringWeather('swamp', WeatherKind.dry, 'The dry spell'),
    ),
    _DebugAction(
      'ARCANE METEORS',
      'Replace the Arcane\'s spawns with a batch that comes with a meteor '
          'shower',
      'BRING',
      () => _bringWeather('arcane', WeatherKind.meteors, 'The meteor shower'),
    ),
    _DebugAction(
      'ARCANE AURORA',
      'Replace the Arcane\'s spawns with a batch that comes with the '
          'northern lights',
      'BRING',
      () => _bringWeather('arcane', WeatherKind.aurora, 'The northern lights'),
    ),
    _DebugAction(
      'TIDAL FOG',
      'Replace the Tidal Shelf\'s spawns with a batch that comes with sea '
          'fog',
      'BRING',
      () => _bringWeather('tidal', WeatherKind.fog, 'Sea fog'),
    ),
    _DebugAction(
      'TIDAL SWELL',
      'Replace the Tidal Shelf\'s spawns with a batch that comes with a '
          'swell',
      'BRING',
      () => _bringWeather('tidal', WeatherKind.swell, 'A swell'),
    ),
    _DebugAction(
      'TIDAL SHELLS',
      'Make the next clear visit to the Tidal Shelf show what a swell left',
      'SET',
      () => _owedAftermath(
        'tidal',
        'The next clear visit to the Tidal Shelf shows what the swell left',
      ),
    ),
    _DebugAction(
      'GEODE FROSTFALL',
      'Replace Geode Hollow\'s spawns with a batch that comes with a '
          'frostfall',
      'BRING',
      () => _bringWeather('geode', WeatherKind.frostfall, 'A frostfall'),
    ),
    _DebugAction(
      'GEODE RIME',
      'Make the next clear visit to Geode Hollow show the rime after a '
          'frostfall',
      'SET',
      () => _owedAftermath(
        'geode',
        'The next clear visit to Geode Hollow shows the rime',
      ),
    ),
    _DebugAction(
      'DUNES SANDSTORM',
      'Replace the Glass Dunes\' spawns with a batch that comes with a '
          'sandstorm',
      'BRING',
      () => _bringWeather('dunes', WeatherKind.sandstorm, 'A sandstorm'),
    ),
    _DebugAction(
      'DUNES GLASS',
      'Make the next clear visit to the Glass Dunes show the glass after a '
          'storm',
      'SET',
      () => _owedAftermath(
        'dunes',
        'The next clear visit to the Glass Dunes shows the glass',
      ),
    ),
    _DebugAction(
      'VOLCANO STAGE',
      'Move the Volcano on a visit: quiet twice, smoking twice, then '
          'erupting',
      'NEXT',
      _advanceVolcano,
    ),
    _DebugAction(
      'FACTION TEST',
      'Reopen the picker and switch faction for free — the only way to '
          'watch the commit animation more than once per save',
      'PICK',
      _openFactionTester,
    ),
  ];
}

class _DebugAction {
  const _DebugAction(this.title, this.description, this.action, this.onTap);
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;
}

/// A few words to choose between, the chosen one lit from below.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.palette,
    required this.accent,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ChoiceCell(
              selected: options[i].$1 == value,
              palette: palette,
              accent: accent,
              onTap: () {
                if (options[i].$1 == value) return;
                HapticFeedback.selectionClick();
                onChanged(options[i].$1);
              },
              child: Text(
                options[i].$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(
                  11,
                  options[i].$1 == value ? palette.ink : palette.muted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every typeface, each written in itself.
class _FontChoice extends StatelessWidget {
  const _FontChoice({required this.palette, required this.accent});

  final BracketPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ThemeNotifier>().fontName;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in appFontMap.keys)
          _ChoiceCell(
            selected: name == current,
            palette: palette,
            accent: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            fill: false,
            onTap: () {
              if (name == current) return;
              HapticFeedback.selectionClick();
              context.read<ThemeNotifier>().setFont(name);
            },
            child: Text(
              name,
              style: GoogleFonts.getFont(
                name,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: name == current ? palette.ink : palette.muted,
              ),
            ),
          ),
      ],
    );
  }
}

/// A label over its value, for the account's name, email and device.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label, style: _mono(9.5, palette.muted)),
            ),
          ),
          Expanded(
            child: Text(value, style: _prose(context, palette.ink, size: 13)),
          ),
        ],
      ),
    );
  }
}

/// OFF, or the mutation the next wilderness fusion is forced to.
class _WildMutationSelector extends StatelessWidget {
  const _WildMutationSelector({
    required this.palette,
    required this.accent,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final BracketPalette palette;
  final Color accent;
  final String? value;
  final bool enabled;
  final Future<void> Function(String? id) onChanged;

  static const _off = 'off';

  @override
  Widget build(BuildContext context) {
    final current = AlchemonMutation.byId(value)?.id ?? _off;
    final items = <(String, String)>[
      (_off, 'OFF'),
      for (final m in AlchemonMutation.values) (m.id, m.label.toUpperCase()),
    ];
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4),
        color: current == _off
            ? palette.bg0
            : palette.accentWash(accent, darkAlpha: 0.18),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current,
            icon: Icon(AppIcons.arrow_drop_down, color: palette.muted),
            dropdownColor: palette.bg1,
            isDense: true,
            onChanged: enabled
                ? (next) {
                    if (next == null) return;
                    HapticFeedback.selectionClick();
                    onChanged(next == _off ? null : next);
                  }
                : null,
            items: [
              for (final (id, label) in items)
                DropdownMenuItem<String>(
                  value: id,
                  child: Text(label, style: _mono(11, palette.ink)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.children,
    this.message,
  });

  final String title;
  final String? message;
  final String submitLabel;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return _DialogShell(
      title: title,
      children: [
        if (message != null) ...[
          Text(message!, style: _prose(context, palette.ink, size: 13.5)),
          const SizedBox(height: 14),
        ],
        ...children,
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _QuietButton(
                label: 'CANCEL',
                height: 42,
                palette: palette,
                accent: accent,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BracketButton(
                label: submitLabel,
                height: 42,
                palette: palette,
                accent: accent,
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A text field sunk into the dialog: a darker well, its hint in the book
/// face, and a lit edge under it while it has the cursor.
class _FormField extends StatefulWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    this.secret = false,
    this.autofocus = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool secret;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    final edge = UnderlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: palette.bg0, width: 1.5),
    );
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      autofocus: widget.autofocus,
      autocorrect: false,
      keyboardType: widget.keyboardType,
      cursorColor: accent,
      style: _prose(context, palette.ink, size: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: _prose(context, palette.muted, size: 14),
        filled: true,
        fillColor: palette.bg0,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        border: edge,
        enabledBorder: edge,
        focusedBorder: edge.copyWith(
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        suffixIcon: widget.secret
            ? IconButton(
                onPressed: context.soundAction(
                  () => setState(() => _hidden = !_hidden),
                ),
                icon: Icon(
                  _hidden
                      ? AppIcons.visibility_rounded
                      : AppIcons.visibility_off_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              )
            : null,
      ),
    );
  }
}

/// The sign-in dialog, from SETTINGS' account or from FRIENDS on the
/// profile. Null when it was closed; otherwise what came of signing in.
Future<({SignInResult? result})?> _signInWithDialog(
  BuildContext context,
) async {
  SignInResult? signedIn;
  final done = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _CredentialDialog(
      title: 'SIGN IN',
      submitLabel: 'SIGN IN',
      message:
          'Your account\'s save comes to this device, and this becomes the '
          'account\'s device.',
      warning:
          'If the account has a save, it replaces the game here. Progress '
          'on this device that isn\'t in that account is lost.',
      submit: (result) async {
        try {
          signedIn = await signInAndBringSave(
            context,
            email: result.email,
            password: result.password,
          );
          return null;
        } catch (error) {
          return signInErrorText(error);
        }
      },
    ),
  );
  if (done != true) return null;
  return (result: signedIn);
}

/// What a finished sign-in says.
String _signedInText(SignInResult? result) => switch (result) {
  SignInResult.restored => 'Your account\'s save is on this device now.',
  SignInResult.savedHere => 'Signed in. This game now saves to your account.',
  _ => 'Signed in.',
};

/// Email and password, checked before it closes: a wrong password, or
/// anything else that goes wrong, shows under the fields and the dialog
/// stays for another try. Pops true once [submit] has worked.
class _CredentialDialog extends StatefulWidget {
  const _CredentialDialog({
    required this.title,
    required this.submitLabel,
    required this.submit,
    this.message,
    this.warning,
    this.includeDisplayName = false,
  });

  final String title;
  final String submitLabel;
  final String? message;
  final String? warning;
  final bool includeDisplayName;

  /// Null when it worked; otherwise what to show.
  final Future<String?> Function(_CredentialDialogResult result) submit;

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.submit(
      _CredentialDialogResult(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final palette = BracketPalette.fromTheme(theme);
    final accent = bracketReadableAccent(theme);
    return PopScope(
      canPop: !_busy,
      child: _DialogShell(
        title: widget.title,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: _prose(context, palette.ink, size: 13.5),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.warning != null) ...[
            Text(widget.warning!, style: _prose(context, _kDanger, size: 13)),
            const SizedBox(height: 14),
          ],
          if (widget.includeDisplayName) ...[
            _FormField(controller: _name, hint: 'Account name'),
            const SizedBox(height: 10),
          ],
          _FormField(
            controller: _email,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _FormField(controller: _password, hint: 'Password', secret: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: _prose(context, _kDanger, size: 13)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QuietButton(
                  label: 'CANCEL',
                  height: 42,
                  enabled: !_busy,
                  palette: palette,
                  accent: accent,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BracketButton(
                  label: _busy ? 'WORKING…' : widget.submitLabel,
                  height: 42,
                  enabled: !_busy,
                  palette: palette,
                  accent: accent,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

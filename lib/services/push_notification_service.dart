// lib/services/push_notification_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alchemons/services/notification_preferences_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final NotificationPreferencesService _prefs =
      NotificationPreferencesService();

  // Notification IDs - using separate ranges to prevent collisions
  static const int eggHatchingBaseId = 1000; // 1000-1099 for individual eggs
  static const int eggReadyConsolidatedId =
      1100; // Single ID for immediate consolidated "X eggs ready now"
  static const int eggHatchingConsolidatedBaseId =
      1200; // 1200-1299 for *scheduled* consolidated eggs by time window

  static const int wildernessSpawnBaseId =
      2000; // 2000-2099 for individual spawns
  static const int wildernessConsolidatedId =
      2100; // Single ID for consolidated
  static const int harvestReadyBaseId =
      3000; // 3000-3099 for individual harvests
  static const int harvestConsolidatedId = 3100; // Single ID for consolidated
  static const List<String> _wildernessBiomeOrder = [
    'valley',
    'sky',
    'volcano',
    'swamp',
    'arcane',
  ];

  // Tracking for egg hatch time windows (to suppress multi-spam)
  // Key: normalized hatch time (to minute, ISO string)
  // Value: list of slot indices that hatch in that minute
  final Map<String, List<int>> _eggHatchWindowSlots = {};
  // Key: normalized hatch time -> consolidated notification ID for that window
  final Map<String, int> _eggHatchWindowConsolidatedIds = {};

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Set local location
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(_resolveTimeZoneName(timeZoneName)));
    } catch (e) {
      debugPrint('⚠️ Could not set timezone to $timeZoneName, using UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for iOS/macOS
    if (Platform.isIOS || Platform.isMacOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
    debugPrint('✅ Push notification service initialized');
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // You can handle navigation here based on payload
  }

  // Helper: normalize a DateTime to the minute (for grouping hatch windows)
  DateTime _normalizeToMinute(DateTime time) {
    return DateTime(time.year, time.month, time.day, time.hour, time.minute);
  }

  String _resolveTimeZoneName(String raw) {
    const fallbackByAbbrev = <String, String>{
      'MDT': 'America/Denver',
      'MST': 'America/Denver',
      'CDT': 'America/Chicago',
      'CST': 'America/Chicago',
      'EDT': 'America/New_York',
      'EST': 'America/New_York',
      'PDT': 'America/Los_Angeles',
      'PST': 'America/Los_Angeles',
      'AKDT': 'America/Anchorage',
      'AKST': 'America/Anchorage',
      'HST': 'Pacific/Honolulu',
    };
    return fallbackByAbbrev[raw] ?? raw;
  }

  // ============================================================================
  // EGG HATCHING NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleEggHatchingNotification({
    required DateTime hatchTime,
    required String eggId,
    int? slotIndex,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isCultivationsEnabled()) return;

    final now = DateTime.now();
    if (hatchTime.isBefore(now)) {
      // Don't show individual notification - let the consolidated check handle it
      debugPrint(
        '⏭️  Egg $eggId already ready, skipping individual notification',
      );
      return;
    }

    // Use safe slot index (0-99 range)
    final safeSlotIndex = (slotIndex ?? 0).clamp(0, 99);

    // Group eggs that hatch in the same minute into a single scheduled
    // consolidated notification to prevent "4 eggs -> 4 notifications" spam.
    final normalized = _normalizeToMinute(hatchTime);
    final windowKey = normalized.toIso8601String();

    final windowSlots = _eggHatchWindowSlots.putIfAbsent(
      windowKey,
      () => <int>[],
    );
    if (!windowSlots.contains(safeSlotIndex)) {
      windowSlots.add(safeSlotIndex);
    }

    final scheduledDate = tz.TZDateTime.from(hatchTime, tz.local);

    if (windowSlots.length == 1) {
      // Only one egg in this time window -> schedule per-egg notification.
      await _notifications.zonedSchedule(
        eggHatchingBaseId + safeSlotIndex,
        'Cultivation Ready!',
        'Your specimen is ready for extraction',
        scheduledDate,
        _notificationDetails(
          channelId: 'egg_hatching',
          channelName: 'Cultivation',
          channelDescription:
              'Notifications when specimens are ready for extraction',
          importance: Importance.high,
          priority: Priority.high,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'egg_ready:$eggId',
      );

      debugPrint(
        '📅 Scheduled egg hatching notification for $scheduledDate '
        '(slot $safeSlotIndex, ID: ${eggHatchingBaseId + safeSlotIndex})',
      );
    } else {
      // 2+ eggs in the same minute window -> suppress multi-spam:
      //  - cancel all individual notifications in this window
      //  - schedule (or update) a single consolidated notification for the window

      // Cancel all individual notifications for this window
      for (final slot in windowSlots) {
        final id = eggHatchingBaseId + slot;
        await _notifications.cancel(id);
        debugPrint(
          '🔕 Cancelled individual egg notification for slot $slot '
          '(ID: $id) in window $windowKey',
        );
      }

      // Get / assign a consolidated ID for this window
      int consolidatedId;
      if (_eggHatchWindowConsolidatedIds.containsKey(windowKey)) {
        consolidatedId = _eggHatchWindowConsolidatedIds[windowKey]!;
        // Cancel previous consolidated so we can reschedule with updated count
        await _notifications.cancel(consolidatedId);
        debugPrint(
          '🔁 Updating consolidated egg notification for window $windowKey '
          '(old ID: $consolidatedId)',
        );
      } else {
        // Use a stable offset within 0-99 for consolidated window IDs
        final index = _eggHatchWindowConsolidatedIds.length % 100;
        consolidatedId = eggHatchingConsolidatedBaseId + index;
        _eggHatchWindowConsolidatedIds[windowKey] = consolidatedId;
        debugPrint(
          '🆕 Assigned consolidated egg window ID $consolidatedId '
          'for window $windowKey',
        );
      }

      final eggCount = windowSlots.length;
      final title = eggCount > 1
          ? '$eggCount Cultivations Ready!'
          : 'Cultivation Ready!';
      final body = eggCount > 1
          ? 'You have $eggCount specimens ready for extraction'
          : 'Your specimen is ready for extraction';

      await _notifications.zonedSchedule(
        consolidatedId,
        title,
        body,
        scheduledDate,
        _notificationDetails(
          channelId: 'egg_hatching',
          channelName: 'Cultivation',
          channelDescription:
              'Notifications when specimens are ready for extraction',
          importance: Importance.high,
          priority: Priority.high,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'eggs_window_ready:$eggCount',
      );

      debugPrint(
        '📅 Scheduled consolidated egg window notification for $scheduledDate '
        '(window $windowKey, count: $eggCount, ID: $consolidatedId)',
      );
    }
  }

  // Immediate consolidated "X eggs ready now" (e.g., called when app does a check)
  Future<void> showEggReadyNotification({
    required int count,
    bool silentUpdate = false,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isCultivationsEnabled()) return;

    await _notifications.show(
      eggReadyConsolidatedId,
      '${count > 1 ? '$count Cultivations' : 'Cultivation'} Ready!',
      count > 1
          ? 'You have $count specimens ready for extraction'
          : 'Your specimen is ready for extraction',
      _notificationDetails(
        channelId: 'egg_hatching',
        channelName: 'Cultivation',
        channelDescription:
            'Notifications when specimens are ready for extraction',
        importance: Importance.high,
        priority: Priority.high,
        silentUpdate: silentUpdate,
      ),
      payload: 'eggs_ready:$count',
    );

    debugPrint(
      '🔔 Showed egg ready notification (count: $count, ID: $eggReadyConsolidatedId, silent: $silentUpdate)',
    );
  }

  Future<void> cancelEggNotification({int? slotIndex}) async {
    if (slotIndex != null) {
      final safeSlotIndex = slotIndex.clamp(0, 99);
      await _notifications.cancel(eggHatchingBaseId + safeSlotIndex);
      debugPrint(
        '🔕 Cancelled egg notification for slot $safeSlotIndex '
        '(ID: ${eggHatchingBaseId + safeSlotIndex})',
      );

      // Note: we do not try to surgically update window consolidation here.
      // If you need that, you can extend this to also adjust _eggHatchWindowSlots.
    } else {
      // Cancel all egg notifications (individual + immediate consolidated
      // + scheduled consolidated windows)
      for (int i = 0; i < 100; i++) {
        await _notifications.cancel(eggHatchingBaseId + i);
      }
      await _notifications.cancel(eggReadyConsolidatedId);

      for (int i = 0; i < 100; i++) {
        await _notifications.cancel(eggHatchingConsolidatedBaseId + i);
      }

      _eggHatchWindowSlots.clear();
      _eggHatchWindowConsolidatedIds.clear();

      debugPrint(
        '🔕 Cancelled all egg notifications (individual + consolidated)',
      );
    }
  }

  Future<void> cancelEggReadySummaryNotification() async {
    if (!_initialized) await initialize();
    await _notifications.cancel(eggReadyConsolidatedId);
  }

  // ============================================================================
  // WILDERNESS SPAWN NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleWildernessSpawnNotification({
    required DateTime spawnTime,
    required String biomeId,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isWildernessEnabled()) return;

    final now = DateTime.now();
    if (spawnTime.isBefore(now)) {
      return;
    }

    final biomeNames = {
      'valley': 'Valley',
      'sky': 'Sky Peaks',
      'volcano': 'Volcano',
      'swamp': 'Swamp',
      'arcane': 'Arcane',
    };

    final biomeName = biomeNames[biomeId] ?? biomeId;
    final scheduledDate = tz.TZDateTime.from(spawnTime, tz.local);

    // Use a stable ID based on biome key, with a deterministic fallback.
    final biomeIndex = _notificationSlotForKey(
      key: biomeId,
      knownOrder: _wildernessBiomeOrder,
    );

    await _notifications.zonedSchedule(
      wildernessSpawnBaseId + biomeIndex,
      'Wild Creatures Detected!',
      'New specimens spotted in the $biomeName',
      scheduledDate,
      _notificationDetails(
        channelId: 'wilderness_spawns',
        channelName: 'Wilderness Spawns',
        channelDescription: 'Notifications when wild creatures spawn',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'wilderness_spawn:$biomeId',
    );

    debugPrint(
      '📅 Scheduled wilderness spawn notification for $biomeName at $scheduledDate '
      '(ID: ${wildernessSpawnBaseId + biomeIndex})',
    );
  }

  Future<void> cancelWildernessSpawnNotification({
    required String biomeId,
  }) async {
    if (!_initialized) await initialize();

    final biomeIndex = _notificationSlotForKey(
      key: biomeId,
      knownOrder: _wildernessBiomeOrder,
    );
    await _notifications.cancel(wildernessSpawnBaseId + biomeIndex);
    debugPrint(
      '🔕 Cancelled wilderness spawn notification for $biomeId '
      '(ID: ${wildernessSpawnBaseId + biomeIndex})',
    );
  }

  Future<void> showWildernessSpawnNotification({
    required int spawnCount,
    required int locationCount,
    bool silentUpdate = false,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isWildernessEnabled()) return;

    await _notifications.show(
      wildernessConsolidatedId,
      'Wild Creatures Detected!',
      'Specimens spotted in $locationCount location${locationCount > 1 ? 's' : ''}',
      _notificationDetails(
        channelId: 'wilderness_spawns',
        channelName: 'Wilderness Spawns',
        channelDescription: 'Notifications when wild creatures spawn',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        silentUpdate: silentUpdate,
      ),
      payload: 'wilderness_active:$spawnCount',
    );

    debugPrint(
      '🔔 Showed wilderness spawn notification (count: $spawnCount, ID: $wildernessConsolidatedId, silent: $silentUpdate)',
    );
  }

  Future<void> cancelWildernessNotifications() async {
    // Cancel all wilderness notifications (individual + consolidated)
    for (int i = 0; i < 100; i++) {
      await _notifications.cancel(wildernessSpawnBaseId + i);
    }
    await _notifications.cancel(wildernessConsolidatedId);
    debugPrint('🔕 Cancelled all wilderness notifications');
  }

  Future<void> cancelWildernessSummaryNotification() async {
    if (!_initialized) await initialize();
    await _notifications.cancel(wildernessConsolidatedId);
    debugPrint('🔕 Cancelled wilderness summary notification');
  }

  // ============================================================================
  // HARVEST NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleHarvestReadyNotification({
    required DateTime readyTime,
    required String biomeId,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isExtractionsEnabled()) return;

    final localReadyTime = readyTime.isUtc ? readyTime.toLocal() : readyTime;
    final now = DateTime.now();
    if (localReadyTime.isBefore(now)) {
      debugPrint('⏭️  Harvest for $biomeId already ready, skipping schedule');
      return;
    }
    final scheduledDate = tz.TZDateTime.from(localReadyTime, tz.local);

    // Use a stable ID based on biome type (0-99 range).
    final biomeNames = ['valley', 'sky', 'volcano', 'swamp'];
    final biomeIndex = _notificationSlotForKey(
      key: biomeId,
      knownOrder: biomeNames,
    );

    await _notifications.zonedSchedule(
      harvestReadyBaseId + biomeIndex,
      'Harvest Complete!',
      'Your alchemical harvest is ready for collection',
      scheduledDate,
      _notificationDetails(
        channelId: 'harvest_ready',
        channelName: 'Harvest Ready',
        channelDescription: 'Notifications when harvests are complete',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'harvest_ready:$biomeId',
    );

    debugPrint(
      '📅 Scheduled harvest ready notification for $biomeId at $scheduledDate '
      '(ID: ${harvestReadyBaseId + biomeIndex})',
    );
  }

  Future<void> showHarvestReadyNotification({
    required int count,
    bool silentUpdate = false,
  }) async {
    if (!_initialized) await initialize();
    if (!await _prefs.isExtractionsEnabled()) return;

    await _notifications.show(
      harvestConsolidatedId,
      '${count > 1 ? '$count Harvests' : 'Harvest'} Ready!',
      count > 1
          ? 'You have $count harvests ready for collection'
          : 'Your alchemical harvest is ready for collection',
      _notificationDetails(
        channelId: 'harvest_ready',
        channelName: 'Harvest Ready',
        channelDescription: 'Notifications when harvests are complete',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        silentUpdate: silentUpdate,
      ),
      payload: 'harvests_ready:$count',
    );

    debugPrint(
      '🔔 Showed harvest ready notification (count: $count, ID: $harvestConsolidatedId, silent: $silentUpdate)',
    );
  }

  Future<void> cancelHarvestSummaryNotification() async {
    if (!_initialized) await initialize();
    await _notifications.cancel(harvestConsolidatedId);
    debugPrint('🔕 Cancelled harvest summary notification');
  }

  Future<void> cancelHarvestNotification({String? biomeId}) async {
    if (biomeId != null) {
      final biomeNames = ['valley', 'sky', 'volcano', 'swamp'];
      final biomeIndex = _notificationSlotForKey(
        key: biomeId,
        knownOrder: biomeNames,
      );
      await _notifications.cancel(harvestReadyBaseId + biomeIndex);
      debugPrint(
        '🔕 Cancelled harvest notification for $biomeId '
        '(ID: ${harvestReadyBaseId + biomeIndex})',
      );
    } else {
      // Cancel all harvest notifications (individual + consolidated)
      for (int i = 0; i < 100; i++) {
        await _notifications.cancel(harvestReadyBaseId + i);
      }
      await _notifications.cancel(harvestConsolidatedId);
      debugPrint('🔕 Cancelled all harvest notifications');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  NotificationDetails _notificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Importance importance,
    required Priority priority,
    bool silentUpdate = false,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        playSound: !silentUpdate,
        enableVibration: !silentUpdate,
        onlyAlertOnce: silentUpdate,
        silent: silentUpdate,
        enableLights: true,
        color: const Color(0xFF6A1B9A),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: !silentUpdate,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: !silentUpdate,
      ),
    );
  }

  // Stable 0-99 notification slot for known keys, with deterministic fallback.
  int _notificationSlotForKey({
    required String key,
    required List<String> knownOrder,
  }) {
    final knownIndex = knownOrder.indexOf(key);
    if (knownIndex >= 0) return knownIndex;

    final knownCount = knownOrder.length.clamp(0, 99);
    final dynamicSlots = 100 - knownCount;
    final hash = key.codeUnits.fold<int>(0, (acc, u) => (acc * 31 + u) % 100);

    if (dynamicSlots <= 0) return hash;
    return knownCount + (hash % dynamicSlots);
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    _eggHatchWindowSlots.clear();
    _eggHatchWindowConsolidatedIds.clear();
    debugPrint('🔕 Cancelled all notifications');
  }

  // Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Debug helper to show what's scheduled
  Future<void> debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('📋 Pending notifications: ${pending.length}');
    for (final notification in pending) {
      debugPrint(
        '  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}',
      );
    }
  }
}

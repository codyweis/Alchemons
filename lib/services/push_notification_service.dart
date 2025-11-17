// lib/services/push_notification_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  // Notification IDs - using separate ranges to prevent collisions
  static const int eggHatchingBaseId = 1000; // 1000-1099 for individual eggs
  static const int eggReadyConsolidatedId = 1100; // Single ID for consolidated
  static const int wildernessSpawnBaseId =
      2000; // 2000-2099 for individual spawns
  static const int wildernessConsolidatedId =
      2100; // Single ID for consolidated
  static const int harvestReadyBaseId =
      3000; // 3000-3099 for individual harvests
  static const int harvestConsolidatedId = 3100; // Single ID for consolidated

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Set local location
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
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

  // ============================================================================
  // EGG HATCHING NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleEggHatchingNotification({
    required DateTime hatchTime,
    required String eggId,
    int? slotIndex,
  }) async {
    if (!_initialized) await initialize();

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
    final scheduledDate = tz.TZDateTime.from(hatchTime, tz.local);

    await _notifications.zonedSchedule(
      eggHatchingBaseId + safeSlotIndex,
      'Alchemon ready to extract!',
      'Your specimen is ready for extraction',
      scheduledDate,
      _notificationDetails(
        channelId: 'egg_hatching',
        channelName: 'Egg Hatching',
        channelDescription: 'Notifications when specimens are ready to extract',
        importance: Importance.high,
        priority: Priority.high,
        payload: 'egg_ready:$eggId',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '📅 Scheduled egg hatching notification for $scheduledDate (slot $safeSlotIndex, ID: ${eggHatchingBaseId + safeSlotIndex})',
    );
  }

  Future<void> showEggReadyNotification({required int count}) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      eggReadyConsolidatedId,
      '${count > 1 ? '$count Eggs' : 'Egg'} Ready!',
      count > 1
          ? 'You have $count specimens ready for extraction'
          : 'Your creature specimen is ready for extraction',
      _notificationDetails(
        channelId: 'egg_hatching',
        channelName: 'Egg Hatching',
        channelDescription: 'Notifications when eggs are ready to hatch',
        importance: Importance.high,
        priority: Priority.high,
        payload: 'eggs_ready:$count',
      ),
    );

    debugPrint(
      '🔔 Showed egg ready notification (count: $count, ID: $eggReadyConsolidatedId)',
    );
  }

  Future<void> cancelEggNotification({int? slotIndex}) async {
    if (slotIndex != null) {
      final safeSlotIndex = slotIndex.clamp(0, 99);
      await _notifications.cancel(eggHatchingBaseId + safeSlotIndex);
      debugPrint(
        '🔕 Cancelled egg notification for slot $safeSlotIndex (ID: ${eggHatchingBaseId + safeSlotIndex})',
      );
    } else {
      // Cancel all egg notifications (individual + consolidated)
      for (int i = 0; i < 100; i++) {
        await _notifications.cancel(eggHatchingBaseId + i);
      }
      await _notifications.cancel(eggReadyConsolidatedId);
      debugPrint('🔕 Cancelled all egg notifications');
    }
  }

  // ============================================================================
  // WILDERNESS SPAWN NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleWildernessSpawnNotification({
    required DateTime spawnTime,
    required String biomeId,
  }) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    if (spawnTime.isBefore(now)) {
      return;
    }

    final biomeNames = {
      'valley': 'Valley',
      'sky': 'Sky Peaks',
      'volcano': 'Volcano',
      'swamp': 'Swamp',
    };

    final biomeName = biomeNames[biomeId] ?? biomeId;
    final scheduledDate = tz.TZDateTime.from(spawnTime, tz.local);

    // Use a stable ID based on biome (0-99 range for 4 biomes)
    final biomeIndex = biomeNames.keys.toList().indexOf(biomeId).clamp(0, 99);

    await _notifications.zonedSchedule(
      wildernessSpawnBaseId + biomeIndex,
      '🌲 Wild Creatures Detected!',
      'New specimens spotted in the $biomeName',
      scheduledDate,
      _notificationDetails(
        channelId: 'wilderness_spawns',
        channelName: 'Wilderness Spawns',
        channelDescription: 'Notifications when wild creatures spawn',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: 'wilderness_spawn:$biomeId',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '📅 Scheduled wilderness spawn notification for $biomeName at $scheduledDate (ID: ${wildernessSpawnBaseId + biomeIndex})',
    );
  }

  Future<void> showWildernessSpawnNotification({
    required int spawnCount,
    required int locationCount,
  }) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      wildernessConsolidatedId,
      '🌲 Wild Creatures Detected!',
      'Specimens spotted in $locationCount location${locationCount > 1 ? 's' : ''}',
      _notificationDetails(
        channelId: 'wilderness_spawns',
        channelName: 'Wilderness Spawns',
        channelDescription: 'Notifications when wild creatures spawn',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: 'wilderness_active:$spawnCount',
      ),
    );

    debugPrint(
      '🔔 Showed wilderness spawn notification (count: $spawnCount, ID: $wildernessConsolidatedId)',
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

  // ============================================================================
  // HARVEST NOTIFICATIONS
  // ============================================================================

  Future<void> scheduleHarvestReadyNotification({
    required DateTime readyTime,
    required String biomeId,
  }) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    if (readyTime.isBefore(now)) {
      debugPrint('⏭️  Harvest for $biomeId already ready, skipping schedule');
      return;
    }

    final scheduledDate = tz.TZDateTime.from(readyTime, tz.local);

    // Use a stable ID based on biome type (0-99 range)
    final biomeNames = ['valley', 'sky', 'volcano', 'swamp'];
    final biomeIndex = biomeNames.indexOf(biomeId).clamp(0, 99);

    await _notifications.zonedSchedule(
      harvestReadyBaseId + biomeIndex,
      '⚗️ Harvest Complete!',
      'Your alchemical harvest is ready for collection',
      scheduledDate,
      _notificationDetails(
        channelId: 'harvest_ready',
        channelName: 'Harvest Ready',
        channelDescription: 'Notifications when harvests are complete',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: 'harvest_ready:$biomeId',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '📅 Scheduled harvest ready notification for $biomeId at $scheduledDate (ID: ${harvestReadyBaseId + biomeIndex})',
    );
  }

  Future<void> showHarvestReadyNotification({required int count}) async {
    if (!_initialized) await initialize();

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
        payload: 'harvests_ready:$count',
      ),
    );

    debugPrint(
      '🔔 Showed harvest ready notification (count: $count, ID: $harvestConsolidatedId)',
    );
  }

  Future<void> cancelHarvestNotification({String? biomeId}) async {
    if (biomeId != null) {
      final biomeNames = ['valley', 'sky', 'volcano', 'swamp'];
      final biomeIndex = biomeNames.indexOf(biomeId).clamp(0, 99);
      await _notifications.cancel(harvestReadyBaseId + biomeIndex);
      debugPrint(
        '🔕 Cancelled harvest notification for $biomeId (ID: ${harvestReadyBaseId + biomeIndex})',
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
    String? payload,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        enableVibration: true,
        enableLights: true,
        color: const Color(0xFF6A1B9A),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
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

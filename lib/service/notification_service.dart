import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/database_helper.dart'; // Add this line
import '../utils/formatters.dart';

// --- THIS IS THE NEW CHANNEL WE WILL CREATE ---
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'vehicle_reminders_channel', // Updated ID to force refresh
  'Vehicle Reminders',
  description: 'Notifications for vehicle maintenance and paper expiry',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() {
    return _instance;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing notifications: $e");
      }
    }
  }

  Future<void> requestPermissions() async {
    // Local notifications aren't supported on web, and the web permission
    // plugin throws if the browser has no Notification API.
    if (kIsWeb) return;

    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      if (kDebugMode) {
        print("Error requesting notification permissions: $e");
      }
    }
  }

  static void _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      if (kDebugMode) {
        print('Notification payload: $payload');
      }
    }
  }

  Future<void> showImmediateReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/launcher_icon', // Use project's specific icon name
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: 'reminder_id_$id',
    );

    if (kDebugMode) {
      print("IMMEDIATE notification shown for ID: $id - $title: $body");
    }
  }

  // ---------------------------------------------------------------------
  // Reminder and paper alerts
  //
  // Each reminder or paper notifies once per stage (coming up -> due ->
  // overdue). Due and overdue items repeat every [_repeatDays] days. The last
  // stage shown is stored, so a check can run any number of times without
  // repeating itself, and a skipped day (Android can delay or skip background
  // work) is caught up by the next check instead of being missed.
  // ---------------------------------------------------------------------

  /// Warn this many days before a dated reminder, unless the reminder has
  /// its own lead_time_days.
  static const int _defaultLeadDays = 7;

  /// Warn this many km/miles before an odometer reminder, unless the
  /// reminder has its own lead_time_km.
  static const int _defaultLeadKm = 500;

  static const int _repeatDays = 7;

  /// Days-before-expiry at which papers (insurance, PUC, ...) notify.
  static const List<int> _paperWarnDays = [30, 7, 1];

  static const String _paperPrefPrefix = 'paper_notified_';

  /// Checks every pending service reminder and every paper expiry and shows
  /// the notifications that are due. Used by the daily background task and
  /// on app start.
  Future<void> checkAllReminders() async {
    try {
      await _checkServiceReminders();
    } catch (e) {
      if (kDebugMode) print('Reminder check failed: $e');
    }
    try {
      await _checkPapers();
    } catch (e) {
      if (kDebugMode) print('Paper check failed: $e');
    }
  }

  /// Checks one vehicle's reminders right after its odometer changed, using
  /// [currentOdometer]. Follows the same once-per-stage rules, so it never
  /// repeats an alert the daily check already showed.
  Future<void> checkAndShowOdometerReminders({
    required int vehicleId,
    required int currentOdometer,
    required String unitType,
  }) async {
    try {
      await _checkServiceReminders(
        onlyVehicleId: vehicleId,
        odometer: currentOdometer,
        unitType: unitType,
      );
    } catch (e) {
      if (kDebugMode) print('Odometer reminder check failed: $e');
    }
  }

  Future<void> _checkServiceReminders({
    int? onlyVehicleId,
    int? odometer,
    String? unitType,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final reminders = await dbHelper.queryAllPendingRemindersWithVehicle();
    final unit = unitType ?? await _savedUnit();
    final today = _today();

    for (final r in reminders) {
      final int vehicleId = r[DatabaseHelper.columnVehicleId] as int;
      if (onlyVehicleId != null && vehicleId != onlyVehicleId) continue;

      final int? daysLeft = _daysUntil(r[DatabaseHelper.columnDueDate]);
      final int? dueOdo = (r[DatabaseHelper.columnDueOdometer] as num?)
          ?.toInt();
      final int? vehicleOdo = (r[DatabaseHelper.columnCurrentOdometer] as num?)
          ?.toInt();
      final int? odo = (odometer != null && vehicleOdo != null)
          ? (odometer > vehicleOdo ? odometer : vehicleOdo)
          : (odometer ?? vehicleOdo);
      final int? kmLeft = (dueOdo != null && odo != null) ? dueOdo - odo : null;

      final int leadDays =
          (r[DatabaseHelper.columnLeadTimeDays] as num?)?.toInt() ??
          _defaultLeadDays;
      final int leadKm =
          (r[DatabaseHelper.columnLeadTimeKm] as num?)?.toInt() ??
          _defaultLeadKm;
      final stage = _reminderStage(
        daysLeft: daysLeft,
        kmLeft: kmLeft,
        leadDays: leadDays,
        leadKm: leadKm,
      );
      if (stage == _Stage.none) continue;
      // Describe whichever of date/odometer caused this stage.
      final bool byDate =
          _reminderStage(
            daysLeft: daysLeft,
            kmLeft: null,
            leadDays: leadDays,
            leadKm: leadKm,
          ) ==
          stage;

      final last = _parseRecord(r[DatabaseHelper.columnLastNotifiedAt]);
      if (!_shouldNotify(stage, last, today)) continue;

      final int id = r[DatabaseHelper.columnId] as int;
      final String name =
          r['template_name'] ?? r[DatabaseHelper.columnNotes] ?? 'Service';
      final String vehicle =
          '${r[DatabaseHelper.columnMake] ?? ''} ${r[DatabaseHelper.columnModel] ?? ''}'
              .trim();

      await showImmediateReminder(
        id: id,
        title: switch (stage) {
          _Stage.overdue => 'Service overdue',
          _Stage.due => 'Service due',
          _ => 'Service coming up',
        },
        body: _reminderBody(
          name,
          vehicle,
          stage,
          byDate,
          daysLeft,
          kmLeft,
          unit,
        ),
      );
      await dbHelper.updateReminderLastNotified(id, _record(today, stage));
    }
  }

  Future<void> _checkPapers() async {
    final dbHelper = DatabaseHelper.instance;
    final papers = await dbHelper.queryAllExpiringPapers();
    final prefs = await SharedPreferences.getInstance();
    // The background task runs in its own isolate; make sure we see the
    // latest stored values.
    await prefs.reload();
    final today = _today();

    for (final paper in papers) {
      final String? expiry = paper[DatabaseHelper.columnPaperExpiryDate];
      final int? daysLeft = _daysUntil(expiry);
      if (expiry == null || daysLeft == null) continue;

      final stage = _paperStage(daysLeft);
      if (stage == _PaperStage.none) continue;

      final int id = paper[DatabaseHelper.columnId] as int;
      final key = '$_paperPrefPrefix$id';
      // Stored as "<expiry>|<date>|<stage>"; a new expiry (renewal) resets it.
      final parts = (prefs.getString(key) ?? '').split('|');
      final bool sameExpiry = parts.length == 3 && parts[0] == expiry;
      final DateTime? lastDate = sameExpiry
          ? DateTime.tryParse(parts[1])
          : null;
      final int lastStage = sameExpiry
          ? _PaperStage.values.indexWhere((s) => s.name == parts[2])
          : -1;

      final bool notify =
          lastDate == null ||
          stage.index > lastStage ||
          (stage == _PaperStage.expired &&
              today.difference(lastDate).inDays >= _repeatDays);
      if (!notify) continue;

      final String vehicle =
          '${paper[DatabaseHelper.columnMake] ?? ''} ${paper[DatabaseHelper.columnModel] ?? ''}'
              .trim();
      final String type = paper[DatabaseHelper.columnPaperType] ?? 'Paper';
      final String when = switch (stage) {
        _PaperStage.expired =>
          'expired ${-daysLeft} day${daysLeft == -1 ? '' : 's'} ago',
        _PaperStage.today => 'expires today',
        _ when daysLeft == 1 => 'expires tomorrow',
        _ => 'expires in $daysLeft days',
      };

      await showImmediateReminder(
        // High offset keeps paper ids apart from reminder ids.
        id: 100000 + id,
        title: stage == _PaperStage.expired
            ? '$type expired'
            : '$type expiring soon',
        body: '$type for $vehicle $when (${Fmt.date(expiry)}).',
      );
      await prefs.setString(key, '$expiry|${_dateString(today)}|${stage.name}');
    }
  }

  static _Stage _reminderStage({
    required int? daysLeft,
    required int? kmLeft,
    required int leadDays,
    required int leadKm,
  }) {
    _Stage byDate = _Stage.none;
    if (daysLeft != null) {
      if (daysLeft < 0) {
        byDate = _Stage.overdue;
      } else if (daysLeft == 0) {
        byDate = _Stage.due;
      } else if (daysLeft <= leadDays) {
        byDate = _Stage.soon;
      }
    }
    _Stage byKm = _Stage.none;
    if (kmLeft != null) {
      if (kmLeft < 0) {
        byKm = _Stage.overdue;
      } else if (kmLeft == 0) {
        byKm = _Stage.due;
      } else if (kmLeft <= leadKm) {
        byKm = _Stage.soon;
      }
    }
    return byDate.index >= byKm.index ? byDate : byKm;
  }

  static _PaperStage _paperStage(int daysLeft) {
    if (daysLeft < 0) return _PaperStage.expired;
    if (daysLeft == 0) return _PaperStage.today;
    if (daysLeft <= _paperWarnDays[2]) return _PaperStage.days1;
    if (daysLeft <= _paperWarnDays[1]) return _PaperStage.days7;
    if (daysLeft <= _paperWarnDays[0]) return _PaperStage.days30;
    return _PaperStage.none;
  }

  static bool _shouldNotify(
    _Stage stage,
    ({DateTime date, _Stage stage})? last,
    DateTime today,
  ) {
    if (last == null) return true;
    if (stage.index > last.stage.index) return true;
    return stage.index >= _Stage.due.index &&
        today.difference(last.date).inDays >= _repeatDays;
  }

  static String _reminderBody(
    String name,
    String vehicle,
    _Stage stage,
    bool byDate,
    int? daysLeft,
    int? kmLeft,
    String unit,
  ) {
    final forVehicle = vehicle.isEmpty ? '' : ' for $vehicle';
    String days(int n) => '$n day${n == 1 ? '' : 's'}';
    final int d = daysLeft ?? 0;
    final int km = kmLeft ?? 0;
    final String detail = switch (stage) {
      _Stage.overdue =>
        byDate ? 'is overdue by ${days(-d)}' : 'is overdue by ${-km} $unit',
      _Stage.due => byDate ? 'is due today' : 'is due now',
      _ => byDate ? 'is due in ${days(d)}' : 'is due in $km $unit',
    };
    return '"$name"$forVehicle $detail.';
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Whole days from today until [isoDate] (negative if it has passed).
  /// UTC dates so daylight-saving changes can't make a day 23 hours long.
  static int? _daysUntil(Object? isoDate) {
    if (isoDate is! String || isoDate.isEmpty) return null;
    final d = DateTime.tryParse(isoDate);
    if (d == null) return null;
    return DateTime.utc(d.year, d.month, d.day).difference(_today()).inDays;
  }

  static String _dateString(DateTime d) => d.toIso8601String().split('T')[0];

  static String _record(DateTime date, _Stage stage) =>
      '${_dateString(date)}|${stage.name}';

  static ({DateTime date, _Stage stage})? _parseRecord(Object? value) {
    if (value is! String) return null;
    final parts = value.split('|');
    if (parts.length != 2) return null;
    final date = DateTime.tryParse(parts[0]);
    final stage = _Stage.values.where((s) => s.name == parts[1]);
    if (date == null || stage.isEmpty) return null;
    return (
      date: DateTime.utc(date.year, date.month, date.day),
      stage: stage.first,
    );
  }

  static Future<String> _savedUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('app_unit') ?? 'km';
    } catch (_) {
      return 'km';
    }
  }
}

/// Order matters: a higher stage always notifies.
enum _Stage { none, soon, due, overdue }

/// Order matters: a higher stage always notifies.
enum _PaperStage { none, days30, days7, days1, today, expired }

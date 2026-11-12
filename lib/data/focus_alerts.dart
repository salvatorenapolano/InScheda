import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

/// Come la modalità Focus ti avvisa che il recupero è finito: vibrazione
/// se l'app è aperta, notifica se è in background o a schermo spento.
///
/// È una classe astratta (un "contratto"): dice COSA si può fare, non come.
/// L'app usa [DeviceFocusAlerts], che parla col telefono tramite i plugin;
/// i test usano [SilentFocusAlerts], perché nei test i plugin non esistono.
abstract class FocusAlerts {
  const FocusAlerts();

  /// Prepara i plugin. Va chiamato una volta, all'avvio.
  Future<void> init();

  /// Chiede il permesso per le notifiche (Android 13+ e iOS).
  Future<void> requestPermission();

  /// true se Android ci lascia programmare la notifica al secondo esatto
  /// (permesso "Sveglie e promemoria"). Senza, può arrivare in ritardo.
  Future<bool> canScheduleExact();

  /// Apre le impostazioni di Android dove si concede quel permesso.
  Future<void> openExactAlarmSettings();

  /// Vibra: il recupero è finito e stai guardando l'app.
  Future<void> vibrate();

  /// Programma la notifica "Recupero finito" per l'istante [at].
  Future<void> scheduleRestEnd(DateTime at, {required String exercise});

  /// Toglie la notifica del recupero (programmata o già comparsa).
  Future<void> cancelRestEnd();
}

/// Quella vera: flutter_local_notifications per le notifiche, vibration
/// per far vibrare il telefono.
class DeviceFocusAlerts extends FocusAlerts {
  DeviceFocusAlerts();

  final _notifications = FlutterLocalNotificationsPlugin();

  // Una sola notifica di recupero alla volta: sempre lo stesso id, così
  // una nuova sostituisce la vecchia.
  static const _restId = 1;

  // Il "canale" delle notifiche (Android 8+): l'utente lo vede nelle
  // impostazioni dell'app e può regolarne suono e vibrazione.
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_timer',
      'Fine recupero',
      channelDescription: 'Ti avvisa quando il recupero fra le serie è finito.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        // L'icona della notifica: quella dell'app.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Su iOS non chiediamo i permessi all'avvio: li chiediamo quando
        // fai partire il primo allenamento, che è quando servono.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<void> requestPermission() async {
    await _android?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  @override
  Future<bool> canScheduleExact() async => await _android?.canScheduleExactNotifications() ?? true;

  @override
  Future<void> openExactAlarmSettings() async => _android?.requestExactAlarmsPermission();

  @override
  Future<void> vibrate() async {
    if (!await Vibration.hasVibrator()) return;
    // Tre colpi: si sente anche col telefono in tasca.
    await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
  }

  @override
  Future<void> scheduleRestEnd(DateTime at, {required String exercise}) async {
    // zonedSchedule vuole un orario con fuso orario (TZDateTime). Usiamo
    // UTC: per "fra 90 secondi" il fuso non conta, e così non serve
    // caricare il database dei fusi orari.
    final when = tz.TZDateTime.from(at, tz.UTC);
    try {
      await _notifications.zonedSchedule(
        id: _restId,
        title: 'Recupero finito',
        // Il testo è solo il nome dell'esercizio: "Chest press".
        body: exercise,
        scheduledDate: when,
        notificationDetails: _details,
        // Al secondo esatto, anche col telefono in riposo, se abbiamo il
        // permesso; altrimenti Android la consegna quando può.
        androidScheduleMode: await canScheduleExact()
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Exception catch (error) {
      // Senza notifica il Focus funziona lo stesso: lo scriviamo nel log.
      debugPrint('Notifica del recupero non programmata: $error');
    }
  }

  @override
  Future<void> cancelRestEnd() => _notifications.cancel(id: _restId);
}

/// Quella dei test: non fa niente, ma si ricorda cosa le hanno chiesto.
class SilentFocusAlerts extends FocusAlerts {
  SilentFocusAlerts({this.exact = true});

  /// Cosa risponde a [canScheduleExact].
  final bool exact;

  int vibrations = 0;
  DateTime? scheduled;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> vibrate() async => vibrations++;

  @override
  Future<void> scheduleRestEnd(DateTime at, {required String exercise}) async => scheduled = at;

  @override
  Future<void> cancelRestEnd() async => scheduled = null;
}

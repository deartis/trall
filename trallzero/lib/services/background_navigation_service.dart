import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

/// Callback executado em um isolado próprio quando o usuário toca em uma
/// ação da notificação com o app fechado/em background.
///
/// Os actions usam [AndroidNotificationAction.showsUserInterface] = false
/// justamente para serem roteados SEMPRE para cá (e não para a Activity),
/// garantindo funcionamento mesmo com o app totalmente encerrado.
@pragma('vm:entry-point')
Future<void> onNotificationTapBackground(NotificationResponse notificationResponse) async {
  final service = FlutterBackgroundService();
  switch (notificationResponse.actionId) {
    case 'stop_navigation':
      service.invoke('stopService');
      break;
    case 'kill_app':
      service.invoke('killService');
      break;
  }
}

class BackgroundNavigationService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'navigation_channel',
        initialNotificationTitle: 'Trall Zero — Navegação Ativa',
        initialNotificationContent: 'Acompanhando trajeto em segundo plano...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (service) => true,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_bg_service_small');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onNotificationTapBackground,
    );

    // Função auxiliar para atualizar a notificação com os botões de controle
    void showCustomNotification({String? title, String? content}) {
      flutterLocalNotificationsPlugin.show(
        888,
        title ?? 'Trall Zero — Navegação Ativa',
        content ?? 'Acompanhando trajeto em segundo plano...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'navigation_channel',
            'Trall Zero — Navegação',
            channelDescription: 'Canal de notificação para a navegação do Trall Zero',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: false,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'stop_navigation',
                'PARAR NAVEGAÇÃO',
                showsUserInterface: false,
              ),
              AndroidNotificationAction(
                'kill_app',
                'FECHAR APP',
                showsUserInterface: false,
              ),
            ],
          ),
        ),
      );
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Fluxo de atualizações do GPS em segundo plano
    StreamSubscription<Position>? positionSubscription;

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Atualiza a cada 5 metros
      ),
    ).listen((Position position) {
      // 1. Notifica a UI principal se ela estiver aberta
      service.invoke('onLocationUpdate', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
      });

      // 2. Exibe/atualiza notificação apenas quando GPS está ativo de fato
      if (service is AndroidServiceInstance) {
        showCustomNotification(
          title: 'Trall Zero — Navegação Ativa',
          content: 'Veículo em deslocamento. GPS ativo em segundo plano.',
        );
      }
    }, onError: (err) {
      debugPrint('Erro no GPS background: $err');
    });

    Future<void> teardownNotifications() async {
      try {
        await flutterLocalNotificationsPlugin.cancel(888);
        await flutterLocalNotificationsPlugin.cancelAll();
      } catch (_) {}
    }

    // Para a navegação em segundo plano (o app continua aberto se estiver).
    service.on('stopService').listen((event) async {
      await positionSubscription?.cancel();
      await teardownNotifications();
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService();
      }
      service.stopSelf();
    });

    // Encerra a aplicação por completo a partir da notificação:
    // cancela GPS e notificações, remove o serviço foreground e mata o processo.
    service.on('killService').listen((event) async {
      debugPrint('[BgNav] killService: encerrando aplicação...');
      await positionSubscription?.cancel();
      await teardownNotifications();
      try {
        if (service is AndroidServiceInstance) {
          await service.setAsBackgroundService();
        }
        service.stopSelf();
      } catch (_) {}
      // Dá tempo para o sistema processar stopSelf/remoção da notificação
      // antes de matar o processo inteiro (UI incluída).
      await Future<void>.delayed(const Duration(milliseconds: 500));
      exit(0);
    });
  }

  /// Handler das ações quando o app está aberto (isolado principal).
  static void _handleNotificationResponse(NotificationResponse response) {
    final service = FlutterBackgroundService();
    switch (response.actionId) {
      case 'stop_navigation':
        service.invoke('stopService');
        break;
      case 'kill_app':
        service.invoke('killService');
        break;
    }
  }
}

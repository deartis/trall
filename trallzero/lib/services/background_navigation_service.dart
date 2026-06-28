import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

@pragma('vm:entry-point')
void onNotificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == 'stop_navigation') {
    FlutterBackgroundService().invoke('stopService');
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
      onDidReceiveBackgroundNotificationResponse: onNotificationTapBackground,
    );

    // Função auxiliar para atualizar a notificação com o botão "PARAR"
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
                cancelNotification: true,
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

    // NÃO exibe notificação imediatamente — só aparece quando o GPS
    // receber a primeira posição (ou seja, navegação realmente ativa).

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

    // Listener único para parar o serviço:
    // cancela o GPS stream, remove a notificação e mata o serviço.
    service.on('stopService').listen((event) async {
      await positionSubscription?.cancel();
      await flutterLocalNotificationsPlugin.cancelAll();
      service.stopSelf();
    });
  }
}
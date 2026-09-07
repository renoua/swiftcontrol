import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/single_line_exception.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../utils/crypto/encryption_utils.dart';
import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final BleDevice scanResult;
  BaseDevice(this.scanResult);

  final Set<ZwiftButton> _currentlyPressed = {};

  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool isConnected = false;

  bool supportsEncryption = true;

  BleCharacteristic? syncRxCharacteristic;
  Timer? _longPressTimer;

  // Filet de sécurité : si plus aucune trame n'arrive (ou si l'état local pense
  // qu'un bouton est encore tenu alors que la manette ne le confirme plus),
  // on relâche tout après ce délai plutôt que de rester bloqué en attendant
  // un événement qui ne viendra jamais. Voir plan de correction (étape 4).
  static const _watchdogTimeout = Duration(seconds: 3);
  Timer? _watchdogTimer;

  // Instrumentation (étape 0) : delta entre deux trames reçues, pour calibrer
  // le comportement de la manette (fréquence de rafraîchissement, trames Idle...).
  DateTime? _lastFrameAt;

  // File d'exécution séquentielle : garantit qu'un _performActions ne peut
  // jamais s'entrelacer avec un autre, même si l'un d'eux attend une écriture
  // BLE (vibration). Corrige la course qui laissait _currentlyPressed
  // désynchronisé de l'état réel des touches (étapes 1-3 du plan).
  Future<void> _actionQueue = Future.value();

  Future<void> _enqueue(Future<void> Function() task) {
    // L'erreur est absorbée ici (loguée) plutôt que laissée à la charge de
    // chaque appelant : la plupart des sites d'appel sont "fire and forget"
    // (retour de Future non attendu), et une erreur non gérée y déclencherait
    // sinon un avertissement "Unhandled exception" au niveau de la zone Dart.
    final result = _actionQueue.then((_) => task()).catchError((e, stackTrace) {
      actionStreamInternal.add(LogNotification('Action error: $e'));
    });
    _actionQueue = result;
    return result;
  }

  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK;
  String get customServiceId => BleUuid.ZWIFT_CUSTOM_SERVICE_UUID;

  static BaseDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    final device = switch (scanResult.name) {
      //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
      // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
      'Zwift Play' => ZwiftPlay(scanResult),
      'Zwift Click' => ZwiftClick(scanResult),
      _ => null,
    };

    if (device != null) {
      return device;
    } else {
      // otherwise use the manufacturer data to identify the device
      final manufacturerData = scanResult.manufacturerDataList;
      final data = manufacturerData.firstOrNullWhere((e) => e.companyId == Constants.ZWIFT_MANUFACTURER_ID)?.payload;

      if (data == null || data.isEmpty) {
        return null;
      }

      final type = DeviceType.fromManufacturerData(data.first);
      return switch (type) {
        DeviceType.click => ZwiftClick(scanResult),
        DeviceType.playRight => ZwiftPlay(scanResult),
        DeviceType.playLeft => ZwiftPlay(scanResult),
        //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
        DeviceType.rideLeft => ZwiftRide(scanResult),
        _ => null,
      };
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseDevice && runtimeType == other.runtimeType && scanResult == other.scanResult;

  @override
  int get hashCode => scanResult.hashCode;

  @override
  String toString() {
    return runtimeType.toString();
  }

  BleDevice get device => scanResult;
  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  int? batteryLevel;
  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect() async {
    actionStream.listen((message) {
      print("Received message: $message");
    });

    await UniversalBle.connect(device.deviceId);

    if (!kIsWeb && Platform.isAndroid) {
      //await UniversalBle.requestMtu(device.deviceId, 256);
    }

    final services = await UniversalBle.discoverServices(device.deviceId);
    await _handleServices(services);
  }

  Future<void> _handleServices(List<BleService> services) async {
    final customService = services.firstOrNullWhere((service) => service.uuid == customServiceId);

    if (customService == null) {
      throw Exception(
        'Custom service $customServiceId not found for device $this ${device.name ?? device.rawName}.\nYou may need to update the firmware in Zwift Companion app.\nWe found: ${services.joinToString(transform: (s) => s.uuid)}',
      );
    }

    final asyncCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    );
    final syncTxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
    );
    syncRxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    await UniversalBle.setNotifiable(
      device.deviceId,
      customService.uuid,
      asyncCharacteristic.uuid,
      BleInputProperty.notification,
    );
    await UniversalBle.setNotifiable(
      device.deviceId,
      customService.uuid,
      syncTxCharacteristic.uuid,
      BleInputProperty.indication,
    );

    await _setupHandshake();
  }

  Future<void> _setupHandshake() async {
    if (supportsEncryption) {
      await UniversalBle.writeValue(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic!.uuid,
        Uint8List.fromList([
          ...Constants.RIDE_ON,
          ...Constants.REQUEST_START,
          ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
        ]),
        BleOutputProperty.withoutResponse,
      );
    } else {
      await UniversalBle.writeValue(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic!.uuid,
        Constants.RIDE_ON,
        BleOutputProperty.withoutResponse,
      );
    }
  }

  void processCharacteristic(String characteristic, Uint8List bytes) {
    if (kDebugMode && false) {
      print('Received $characteristic: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Received $characteristic: ${String.fromCharCodes(bytes)}');
    }

    if (bytes.isEmpty) {
      return;
    }

    try {
      if (bytes.startsWith(startCommand)) {
        _processDevicePublicKeyResponse(bytes);
      } else if (bytes.startsWith(Constants.RIDE_ON)) {
        //print("Empty RideOn response - unencrypted mode");
      } else if (!supportsEncryption || (bytes.length > Int32List.bytesPerElement + EncryptionUtils.MAC_LENGTH)) {
        _processData(bytes);
      }
    } catch (e, stackTrace) {
      print("Error processing data: $e");
      print("Stack Trace: $stackTrace");
      if (e is SingleLineException) {
        actionStreamInternal.add(LogNotification(e.message));
      } else {
        actionStreamInternal.add(LogNotification("$e\n$stackTrace"));
      }
    }
  }

  void _processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(Constants.RIDE_ON.length + Constants.RESPONSE_START_CLICK.length);
    zapEncryption.initialise(devicePublicKeyBytes);
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  void _processData(Uint8List bytes) {
    int type;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

      if (zapEncryption.encryptionKeyBytes == null) {
        actionStreamInternal.add(
          LogNotification(
            'Encryption not initialized, yet. You may need to update the firmware of your device with the Zwift Companion app.',
          ),
        );
        return;
      }

      final data = zapEncryption.decrypt(counter, payload);
      type = data[0];
      message = data.sublist(1);
    } else {
      type = bytes[0];
      message = bytes.sublist(1);
    }

    if (kDebugMode) {
      final now = DateTime.now();
      final deltaMs = _lastFrameAt == null ? null : now.difference(_lastFrameAt!).inMilliseconds;
      _lastFrameAt = now;
      print(
        '[BLE $runtimeType] type=$type deltaMs=$deltaMs currentlyPressed=${_currentlyPressed.map((e) => e.name).toList()}',
      );
    }

    // Tant qu'un bouton est considéré comme tenu, chaque trame reçue (quel que
    // soit son type) prouve que le lien est vivant : on repousse le filet de
    // sécurité. S'il n'arrive plus aucune trame, il finira par se déclencher.
    if (_currentlyPressed.isNotEmpty) {
      _armWatchdog();
    }

    switch (type) {
      case Constants.EMPTY_MESSAGE_TYPE:
        // "Idle" : la manette indique explicitement qu'aucun bouton n'est enfoncé.
        // Si notre état local pense encore qu'un bouton est tenu (par ex. parce
        // que la notification de relâchement a été perdue), on se resynchronise
        // immédiatement plutôt que d'attendre le watchdog ou un autre bouton.
        if (_currentlyPressed.isNotEmpty) {
          _longPressTimer?.cancel();
          _longPressTimer = null;
          _enqueue(() => _performActions([], false));
          resetNotificationState();
          actionStreamInternal.add(LogNotification('Idle frame: releasing stuck buttons'));
        }
        break;
      case Constants.BATTERY_LEVEL_TYPE:
        if (batteryLevel != message[1]) {
          batteryLevel = message[1];
          connection.signalChange(this);
        }
        break;
      case Constants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case Constants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case Constants.RIDE_NOTIFICATION_MESSAGE_TYPE: // untested
        processClickNotification(message)
            .then((buttonsClicked) async {
              if (buttonsClicked == null) {
                // ignore, no changes
              } else if (buttonsClicked.isEmpty) {
                _longPressTimer?.cancel();
                _longPressTimer = null;
                _enqueue(() => _performActions([], false));
                actionStreamInternal.add(LogNotification('Buttons released'));
              } else {
                // On annule systématiquement l'ancien timer de répétition, même
                // si le nouvel ensemble contient un bouton on/off : sinon un
                // ancien timer (ex. sur paddleLeft) continue de tourner avec sa
                // closure périmée après un changement de bouton.
                _longPressTimer?.cancel();
                _longPressTimer = null;
                _armWatchdog();

                if (!(buttonsClicked.singleOrNull == ZwiftButton.onOffLeft ||
                    buttonsClicked.singleOrNull == ZwiftButton.onOffRight)) {
                  // we don't want to trigger the long press timer for the on/off buttons
                  late final Timer timer;
                  timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
                    if (!identical(_longPressTimer, timer)) {
                      // Un timer plus récent a pris le relais entre-temps :
                      // celui-ci est périmé, on l'arrête et on ignore son tick.
                      t.cancel();
                      return;
                    }
                    _enqueue(() => _performActions(buttonsClicked, true));
                  });
                  _longPressTimer = timer;
                }

                _enqueue(() => _performActions(buttonsClicked, false));
              }
            })
            .catchError((e) {
              actionStreamInternal.add(LogNotification(e.toString()));
            });
        break;
    }
  }

  Future<List<ZwiftButton>?> processClickNotification(Uint8List message);

  /// Purge tout état de dédoublonnage propre à l'appareil (dernière notification
  /// connue, état de la gâchette analogique...). Appelé lors d'une resynchronisation
  /// forcée (watchdog, trame Idle, déconnexion) pour garantir qu'un nouvel appui
  /// après coup ne soit jamais avalé par une comparaison avec un état périmé.
  void resetNotificationState();

  void _armWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdogTimeout, () {
      actionStreamInternal.add(
        LogNotification('Watchdog: no update received for ${_watchdogTimeout.inSeconds}s while a button was held, resynchronizing'),
      );
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _enqueue(() => _performActions([], false));
      resetNotificationState();
    });
  }

  void _disarmWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _performActions(List<ZwiftButton> buttonsClicked, bool repeated) async {
    // Appuis en cours : tous ceux qui sont actuellement envoyés
    final newlyPressed = buttonsClicked.toSet();
    final released = _currentlyPressed.difference(newlyPressed);
    final pressed = newlyPressed.difference(_currentlyPressed);

    // 1. Relâche les boutons qui ne sont plus pressés
    for (final button in released) {
      final result = await actionHandler.releaseAction(button);
      actionStreamInternal.add(LogNotification(result));
    }

    // 2. Appuie sur les nouveaux
    for (final button in pressed) {
      final result = await actionHandler.performAction(button);
      actionStreamInternal.add(LogNotification(result));
    }

    // 3. Répète l'action si besoin (mode "long press") : ne touche jamais à
    // _currentlyPressed, qui ne représente que l'état de la dernière notification
    // réellement reçue de la manette.
    if (repeated) {
      for (final button in buttonsClicked) {
        final result = await actionHandler.performAction(button);
        actionStreamInternal.add(LogNotification('[repeat] $result'));
      }
    } else {
      // 4. Met à jour l'état courant
      _currentlyPressed
        ..clear()
        ..addAll(newlyPressed);

      if (_currentlyPressed.isEmpty) {
        _disarmWatchdog();
      }
    }

    // 5. Vibration : hors du chemin critique (non attendue) et déclenchée
    // uniquement sur une vraie transition (nouveau bouton shift enfoncé), pas
    // à chaque fois qu'un bouton shift figure encore dans la liste alors qu'il
    // est simplement maintenu. La faire après les événements clavier et sans
    // `await` évite qu'un aller-retour BLE retarde le prochain _performActions.
    if (settings.vibrationEnabled &&
        !repeated &&
        pressed.any((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) {
      unawaited(
        _vibrate().catchError((e) {
          actionStreamInternal.add(LogNotification('Vibration error: $e'));
        }),
      );
    }
  }

  /// Relâche immédiatement tous les boutons considérés comme tenus et remet à
  /// zéro l'état de dédoublonnage. À appeler avant une déconnexion : sans ça,
  /// une touche appuyée au moment de la coupure du lien BLE reste enfoncée au
  /// niveau du système d'exploitation, sans aucun moyen de la relâcher.
  Future<void> releaseAllButtons() async {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _disarmWatchdog();
    await _enqueue(() => _performActions([], false));
    resetNotificationState();
  }

  Future<void> _vibrate() async {
    final vibrateCommand = Uint8List.fromList([...Constants.VIBRATE_PATTERN, 0x20]);
    await UniversalBle.writeValue(
      device.deviceId,
      customServiceId,
      syncRxCharacteristic!.uuid,
      supportsEncryption ? zapEncryption.encrypt(vibrateCommand) : vibrateCommand,
      BleOutputProperty.withoutResponse,
    );
  }
}

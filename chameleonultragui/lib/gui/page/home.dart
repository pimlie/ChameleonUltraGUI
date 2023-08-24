import 'package:chameleonultragui/helpers/flash.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/gui/component/dialog_device_settings.dart';
import 'package:chameleonultragui/gui/component/slot_changer.dart';
import 'package:chameleonultragui/gui/features/flash_firmware_latest.dart';
import 'package:chameleonultragui/gui/features/flash_firmware_zip.dart';
import 'package:chameleonultragui/main.dart';
import 'package:sizer_pro/sizer.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  var selectedSlot = 1;

  @override
  void initState() {
    super.initState();
  }

  Future<(bool, Icon, String, List<String>, bool)>
      getFutureData() async {
      var appState = context.read<MyAppState>();
      List<(TagType, TagType)> usedSlots;
      try {
        usedSlots = await appState.communicator!.getUsedSlots();
      } catch (_) {
        usedSlots = [];
      }

      var getIsChameleonUltra = Future.value(appState.connector.device == ChameleonDevice.ultra);
      if (appState.onWeb) {
        // Serial on Web doesnt provide device/manufacture names, so detect the device type instead
        getIsChameleonUltra = detectChameleonUltra().then((isChameleonUltra) {
          // Also update device type in SerialConnection
          appState.connector.device = isChameleonUltra ? ChameleonDevice.ultra : ChameleonDevice.lite;
          return isChameleonUltra;
        });
      }

      return (
        await getIsChameleonUltra,
        await getBatteryChargeIcon(),
        await getUsedSlotsOut8(usedSlots),
        await getVersion(),
        await isReaderDeviceMode(),
      );
  }

  Future<(AnimationSetting, ButtonPress, ButtonPress)> getSettingsData() async {
    return (
      await getAnimationMode(),
      await getButtonConfig(ButtonType.a),
      await getButtonConfig(ButtonType.b)
    );
  }

  Future<bool> detectChameleonUltra() async {
    var appState = context.read<MyAppState>();
    return await appState.communicator!.detectChameleonUltra();
  }

  Future<Icon> getBatteryChargeIcon() async {
    var appState = context.read<MyAppState>();

    int charge = 0;
    try {
      (_, charge) = await appState.communicator!.getBatteryCharge();
    } catch (_) {}

    if (charge > 98) {
      return const Icon(Icons.battery_full);
    } else if (charge > 87) {
      return const Icon(Icons.battery_6_bar);
    } else if (charge > 75) {
      return const Icon(Icons.battery_5_bar);
    } else if (charge > 62) {
      return const Icon(Icons.battery_4_bar);
    } else if (charge > 50) {
      return const Icon(Icons.battery_3_bar);
    } else if (charge > 37) {
      return const Icon(Icons.battery_2_bar);
    } else if (charge > 10) {
      return const Icon(Icons.battery_1_bar);
    } else if (charge > 3) {
      return const Icon(Icons.battery_0_bar);
    } else if (charge > 0) {
      return const Icon(Icons.battery_alert);
    }

    return const Icon(Icons.battery_unknown);
  }

  Future<ButtonPress> getButtonConfig(ButtonType type) async {
    var appState = context.read<MyAppState>();
    return await appState.communicator!.getButtonConfig(type);
  }

  Future<String> getUsedSlotsOut8(List<(TagType, TagType)> usedSlots) async {
    int usedSlotsOut8 = 0;

    if (usedSlots.isNotEmpty) {
      for (int i = 0; i < 8; i++) {
        if (usedSlots[i].$1 != TagType.unknown ||
            usedSlots[i].$2 != TagType.unknown) {
          usedSlotsOut8++;
        }
      }
    }
    return usedSlotsOut8.toString();
  }

  Future<List<String>> getVersion() async {
    var appState = context.read<MyAppState>();
    String commitHash = "";
    String firmwareVersion =
        numToVerCode(await appState.communicator!.getFirmwareVersion());

    try {
      commitHash = await appState.communicator!.getGitCommitHash();
    } catch (_) {}

    if (commitHash.isEmpty) {
      commitHash = "Outdated FW";
    }

    return ["$firmwareVersion ($commitHash)", commitHash];
  }

  Future<bool> isReaderDeviceMode() async {
    var appState = context.read<MyAppState>();
    return await appState.communicator!.isReaderDeviceMode();
  }

  Future<AnimationSetting> getAnimationMode() async {
    var appState = context.read<MyAppState>();

    try {
      return await appState.communicator!.getAnimationMode();
    } catch (_) {
      return AnimationSetting.full;
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.read<MyAppState>();
    //var connection = ChameleonCommunicator(port: appState.connector);

    return FutureBuilder(
        future: getFutureData(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            appState.log.e('Build Error ${snapshot.error}', error: snapshot.error);
            appState.connector.performDisconnect();
            return Text('Error: ${snapshot.error.toString()}');
          } else {
            final (
              isChameleonUltra,
              batteryIcon,
              usedSlots,
              fwVersion,
              isReaderDeviceMode,
            ) = snapshot.data;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Home'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Center
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    // Disconnect
                                    await appState.connector.performDisconnect();
                                    appState.communicator = null;
                                    appState.changesMade();
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ]
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(appState.connector.portName,
                                    style: const TextStyle(fontSize: 20)),
                                IconButton(
                                  onPressed: null,
                                  padding: EdgeInsets.zero,
                                  disabledColor: Theme.of(context).textTheme.bodyLarge!.color,
                                  icon: Icon(appState.connector.connectionType ==
                                          ConnectionType.ble
                                      ? Icons.bluetooth
                                      : Icons.usb),
                                ),
                                batteryIcon
                              ]
                            )
                          ]
                        )
                      )
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            appState.connector.device.name,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: SizerUtil.width / 25)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text("Used Slots: $usedSlots/8",
                        style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width / 50)),
                    const SlotChanger(),
                    Expanded(
                      child: FractionallySizedBox(
                        widthFactor: 0.4,
                        child: Image.asset(
                          isChameleonUltra
                              ? 'assets/black-ultra-standing-front.png'
                              : 'assets/black-lite-standing-front.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Firmware Version: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width / 50)),
                        Text(fwVersion[0],
                            style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width / 50)),
                        if (appState.connector.connectionType != ConnectionType.ble)
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: IconButton(
                              onPressed: () async {
                                SnackBar snackBar;
                                String latestCommit;

                                var scaffoldMessenger = ScaffoldMessenger.of(context);

                                try {
                                  latestCommit = await latestAvailableCommit(
                                      appState.connector.device);
                                } catch (e) {
                                  scaffoldMessenger.hideCurrentSnackBar();
                                  snackBar = SnackBar(
                                    content:
                                        Text('Update error: ${e.toString()}'),
                                    showCloseIcon: true,
                                  );

                                  scaffoldMessenger.showSnackBar(snackBar);
                                  return;
                                }

                                appState.log.i("Latest commit: $latestCommit");

                                if (latestCommit.isEmpty) {
                                  return;
                                }

                                if (latestCommit.startsWith(fwVersion[1])) {
                                  snackBar = SnackBar(
                                    content: Text(
                                        'Your ${appState.connector.device.name} firmware is up to date'),
                                    showCloseIcon: true,
                                  );

                                  scaffoldMessenger.showSnackBar(snackBar);
                                } else {
                                  var message = 'Downloading and preparing new ${appState.connector.device.name} firmware...';
                                  if (appState.onWeb) {
                                    message = 'Your ${appState.connector.device.name} firmware is out of date! Automatic updates are not (yet) supported on web, download manually and then update by clicking on the Settings icon';
                                  }

                                  snackBar = SnackBar(
                                    content: Text(message),
                                    showCloseIcon: true,
                                  );

                                  scaffoldMessenger.showSnackBar(snackBar);

                                  if (!appState.onWeb) {
                                    try {
                                      await flashFirmwareLatest(appState);
                                    } catch (e) {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                      snackBar = SnackBar(
                                        content:
                                            Text('Update error: ${e.toString()}'),
                                        showCloseIcon: true,
                                      );

                                      scaffoldMessenger
                                          .showSnackBar(snackBar);
                                    }
                                  }
                                }
                              },
                              tooltip: "Check for updates",
                              icon: const Icon(Icons.update),
                            ),
                          )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isChameleonUltra)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: IconButton(
                              onPressed: () async {
                                await appState.communicator!.setReaderDeviceMode(!isReaderDeviceMode);
                                setState(() {});
                                appState.changesMade();
                              },
                              tooltip: isReaderDeviceMode ? 'Go to emulator mode' : 'Go to reader mode',
                              icon: Icon(isReaderDeviceMode ? Icons.nfc_sharp : Icons.barcode_reader),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            onPressed: () => showDialog<String>(
                              context: context,
                              builder: (BuildContext dialogContext) => FutureBuilder(
                                future: getSettingsData(),
                                builder: (BuildContext dialogContext, AsyncSnapshot snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const AlertDialog(
                                        title:
                                            Text('Device Settings'),
                                        content:
                                            CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    appState.log.e('Build error', error: snapshot.error);

                                    // appState.connector.performDisconnect();
                                    return AlertDialog(
                                        title: const Text(
                                            'Device Settings'),
                                        content: Text(
                                            'Error: ${snapshot.error.toString()}'));
                                  }

                                  onClose() {
                                    Navigator.pop(dialogContext, 'Cancel');
                                  }

                                  var scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final communicator = appState.communicator!;

                                  final (
                                      animationMode,
                                      aButtonMode,
                                      bButtonMode
                                  ) = snapshot.data;

                                  var canUpdateLatest = !kIsWeb && appState.connector.connectionType != ConnectionType.ble;
                                  var canUpdateZip = canUpdateLatest;

                                  return DialogDeviceSettings(
                                    animationMode: animationMode,
                                    onClose: onClose,
                                    onEnterDFUMode: () async {
                                      onClose();

                                      await communicator.enterDFUMode();
                                      await appState.connector.performDisconnect();
                                      await asyncSleep(500);
                                      appState.changesMade();
                                    },
                                    onResetSettings: () async {
                                      await communicator.resetSettings();
                                      onClose();
                                      appState.changesMade();
                                    },
                                    onUpdateAnimation: (animation) async {
                                      await communicator.setAnimationMode(animation);
                                      await communicator.saveSettings();

                                      setState(() {});
                                      appState.changesMade();
                                    },
                                    onFirmwareUpdateLatest: !canUpdateLatest ? null : () async {
                                      onClose();

                                      var snackBar = SnackBar(
                                        content: Text(
                                            'Downloading and preparing new ${appState.connector.device.name} firmware...'),
                                        showCloseIcon: true,
                                      );

                                      scaffoldMessenger.showSnackBar(snackBar);
                                      try {
                                        await flashFirmwareLatest(appState);
                                      } catch (e) {
                                        snackBar = SnackBar(
                                          content: Text('Update error: ${e.toString()}'),
                                          showCloseIcon: true,
                                        );

                                        scaffoldMessenger.hideCurrentSnackBar();
                                        scaffoldMessenger.showSnackBar(snackBar);
                                      }
                                    },
                                    onFirmwareUpdateFromZip: !canUpdateZip ? null : () async {
                                      onClose();

                                      try {
                                        await flashFirmwareZip(appState);
                                      } catch (e) {
                                        var snackBar = SnackBar(
                                          content: Text('Update error: ${e.toString()}'),
                                          showCloseIcon: true,
                                        );

                                        scaffoldMessenger.showSnackBar(snackBar);
                                      }
                                    }
                                  );
                                }
                              )
                            ),
                            icon: const Icon(Icons.settings),
                            tooltip: 'Device Settings',
                          ),
                        )
                      ]
                    )
                  ],
                ),
              ),
            );
          }
        });
  }
}

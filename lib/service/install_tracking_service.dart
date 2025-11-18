import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart'; // Import Workmanager

class InstallTrackingService {
  static final InstallTrackingService _instance =
      InstallTrackingService._internal();
  factory InstallTrackingService() => _instance;
  InstallTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const String _prefKeyInstallId = 'app_install_id';
  static const String _prefKeyIsSynced = 'install_event_synced';

  Future<void> trackInstall() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. If already synced, stop.
      bool isSynced = prefs.getBool(_prefKeyIsSynced) ?? false;
      if (isSynced) return;

      // 2. Get/Generate ID
      String? installId = prefs.getString(_prefKeyInstallId);
      if (installId == null) {
        installId = const Uuid().v4();
        await prefs.setString(_prefKeyInstallId, installId);
      }

      // 3. Prepare Data
      Map<String, dynamic> deviceData = await _getDeviceData();
      final installData = {
        'install_id': installId,
        'timestamp': FieldValue.serverTimestamp(),
        'device_info': deviceData,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'synced_at': DateTime.now().toIso8601String(),
      };

      // 4. Try to write (This works if online, or caches if offline)
      // We remove 'await' so it doesn't block UI
      _firestore
          .collection('app_installs')
          .doc(installId)
          .set(installData)
          .then((_) {
            // If this success callback runs, it means we are ONLINE and it worked.
            prefs.setBool(_prefKeyIsSynced, true);
          })
          .catchError((error) {
            print("Offline or Error: $error");
          });

      // 5. THE MAGIC STEP: Schedule a Background Sync
      // This tells Android: "Run 'sync_install' AS SOON AS you have internet"
      await Workmanager().registerOneOffTask(
        "install_sync_task", // Unique Name
        "sync_install_data", // Task Name (we check this in main)
        constraints: Constraints(
          networkType: NetworkType.connected, // <--- REQUIRED INTERNET
        ),
        inputData: {
          'installId': installId,
          'deviceData': deviceData.toString(), // Pass simple data if needed
        },
        backoffPolicy: BackoffPolicy.exponential, // Retry if it fails
      );

      print("Background Sync Scheduled (waiting for internet)");
    } catch (e) {
      print("Error tracking install: $e");
    }
  }

  Future<Map<String, dynamic>> _getDeviceData() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return {
        'model': androidInfo.model,
        'brand': androidInfo.brand,
        'device': androidInfo.device,
        'version_sdk': androidInfo.version.sdkInt,
        'is_physical_device': androidInfo.isPhysicalDevice,
      };
    }
    return {'unknown': 'platform'};
  }
}

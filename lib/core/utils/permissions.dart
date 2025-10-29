import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLocationPermission() async {
  // Check current status first
  var status = await Permission.locationWhenInUse.status;

  if (status.isDenied) {
    // Request the permission
    status = await Permission.locationWhenInUse.request();
  }

  // If permanently denied, open app settings
  if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  }

  return status.isGranted;
}

Future<bool> requestBluetoothPermissions() async {
  // Check if we already have permissions
  if (await Permission.bluetooth.isGranted &&
      await Permission.bluetoothConnect.isGranted &&
      await Permission.bluetoothScan.isGranted) {
    return true;
  }

  // Request necessary Bluetooth permissions
  final Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ].request();

  // Check if all required permissions are granted
  final allGranted = statuses.values.every((status) => status.isGranted);

  // If any permission is permanently denied, open app settings
  if (!allGranted) {
    for (final entry in statuses.entries) {
      if (await entry.value.isPermanentlyDenied) {
        await openAppSettings();
        break;
      }
    }
  }

  return allGranted;
}
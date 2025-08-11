import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLocationPermission() async {
  final status = await Permission.locationWhenInUse.request();
  return status.isGranted;
}

Future<bool> requestBluetoothPermissions() async {
  final status = await [
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan
  ].request();

  return status.values.every((status) => status.isGranted);
}
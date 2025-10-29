import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request all necessary permissions at startup
  await _requestAllPermissions();

  runApp(MyApp());
}

Future<void> _requestAllPermissions() async {
  try {
    print('Requesting startup permissions...');

    // Request location permission
    var locationStatus = await Permission.locationWhenInUse.status;
    if (locationStatus.isDenied) {
      locationStatus = await Permission.locationWhenInUse.request();
    }

    // Request Bluetooth permissions
    final bluetoothPermissions = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    print('Startup permission request completed');
  } catch (e) {
    print('Error in startup permission request: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Power Meter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}
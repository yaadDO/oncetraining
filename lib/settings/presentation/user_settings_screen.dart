import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle

class UserSettingsScreen extends StatefulWidget {
  @override
  _UserSettingsScreenState createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _weightController;
  late TextEditingController _ftpController;
  late TextEditingController _maxHrController;
  late TextEditingController _wheelCircController;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _weightController = TextEditingController();
    _ftpController = TextEditingController();
    _maxHrController = TextEditingController();
    _wheelCircController = TextEditingController();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weightController.text = (prefs.getDouble('userWeight') ?? 70.0).toString();
      _ftpController.text = (prefs.getInt('userFtp') ?? 250).toString();
      _maxHrController.text = (prefs.getInt('userMaxHr') ?? 190).toString();
      _wheelCircController.text = (prefs.getDouble('wheelCircumference') ?? 2.1).toString();
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('userWeight', double.parse(_weightController.text));
      await prefs.setInt('userFtp', int.parse(_ftpController.text));
      await prefs.setInt('userMaxHr', int.parse(_maxHrController.text));
      await prefs.setDouble('wheelCircumference', double.parse(_wheelCircController.text));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.blue.shade500,
              ],
            ),
          ),
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 15),
                    Text(
                      'Rider Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInputCard(
                          controller: _weightController,
                          label: 'Weight',
                          unit: 'kg',
                          hint: 'Enter your weight in kilograms',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter weight';
                            if (double.tryParse(value) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        _buildInputCard(
                          controller: _ftpController,
                          label: 'FTP',
                          unit: 'watts',
                          hint: 'Enter your Functional Threshold Power',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter FTP';
                            if (int.tryParse(value) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        _buildInputCard(
                          controller: _maxHrController,
                          label: 'Max Heart Rate',
                          unit: 'bpm',
                          hint: 'Enter your maximum heart rate',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter max HR';
                            if (int.tryParse(value) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        _buildInputCard(
                          controller: _wheelCircController,
                          label: 'Wheel Circumference',
                          unit: 'meters',
                          hint: 'Typical road bike: 2.1m, MTB: 2.2m',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter circumference';
                            if (double.tryParse(value) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                        SizedBox(height: 30),

                        // Save Button
                        Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(20),
                            elevation: 0,
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _saveSettings,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green,
                                      Colors.green.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save, size: 28, color: Colors.white),
                                      SizedBox(width: 15),
                                      Text(
                                        'SAVE SETTINGS',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required String unit,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: controller,
              style: TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Colors.white,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                errorStyle: TextStyle(color: Colors.amber),
              ),
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }
}
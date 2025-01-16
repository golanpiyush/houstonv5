import 'package:flutter/material.dart';
import 'package:houstonv8/Services/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Declare the variable but don't initialize it here
  late bool isBlackTheme;

  @override
  void initState() {
    super.initState();
    // Initialize the variable with the current theme value from the Settings singleton
    isBlackTheme = Settings().isBlackTheme;
  }

  void toggleTheme(bool value) {
    setState(() {
      // Set the new theme value using the setter
      Settings().isBlackTheme = value;
      isBlackTheme = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: isBlackTheme ? Colors.black : Colors.white,
        iconTheme:
            IconThemeData(color: isBlackTheme ? Colors.white : Colors.black),
      ),
      body: Container(
        color: isBlackTheme ? Colors.black : Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Choose Background Color',
                style: TextStyle(
                  color: isBlackTheme ? Colors.white : Colors.black,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Text(
                  'Black Theme',
                  style: TextStyle(
                    color: isBlackTheme ? Colors.white : Colors.black,
                    fontSize: 18,
                  ),
                ),
                value: isBlackTheme,
                onChanged: toggleTheme,
                activeColor: Colors.white,
                inactiveThumbColor: Colors.black,
                inactiveTrackColor: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

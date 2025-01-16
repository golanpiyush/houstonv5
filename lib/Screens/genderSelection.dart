import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:houstonv8/Screens/searchScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  _GenderSelectionScreenState createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  String? selectedGender;

  @override
  void initState() {
    super.initState();
  }

  // Save selected gender to SharedPreferences
  _saveGender(String gender) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('gender', gender);
    setState(() {
      selectedGender = gender;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Gender'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text above gender selection area
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'What are you?',
              style: TextStyle(
                fontFamily: 'Jost',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _saveGender('male'),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: selectedGender == 'male'
                        ? Colors.blueAccent
                        : Colors.transparent, // Corrected to check for 'male'
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/avatars/niggas.svg', // Update path to your custom SVG
                        height: 100,
                        width: 100,
                      ),
                      const SizedBox(
                          height: 8), // Space between the SVG and text
                      const Text(
                        'Man',
                        style: TextStyle(
                          fontFamily: 'Jost',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _saveGender('female'),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: selectedGender == 'female'
                        ? Colors.pinkAccent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15), // Rounded corners
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/avatars/niggis.svg', // Update path to your custom SVG
                        height: 100,
                        width: 100,
                      ),
                      const SizedBox(
                          height: 8), // Space between the SVG and text
                      const Text(
                        'Woman',
                        style: TextStyle(
                          fontFamily: 'Jost',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Space after the gender selection

          // Enter Button
          ElevatedButton(
            onPressed: () async {
              // Navigate to the Search Screen after saving the gender
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const SongSearchScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 0, 0, 0),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Enter',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Jost',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

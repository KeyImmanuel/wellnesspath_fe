import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'main.dart';

class ProfilingScreen extends StatefulWidget {
  final String token;
  const ProfilingScreen({super.key, required this.token});

  @override
  State<ProfilingScreen> createState() => _ProfilingScreenState();
}

class _ProfilingScreenState extends State<ProfilingScreen> {
  final List<String> splits = ['Push/Pull/Legs', 'Upper/Lower', 'Full Body', 'Bro Split'];
  final List<String> goals = ['Muscle Gain', 'Fat Loss', 'Stamina', 'General Fitness'];
  final List<String> intensities = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> categories = ['Underweight', 'Normal', 'Overweight', 'Obese'];
  final List<String> equipment = [
    'Body Only', 'Bands', 'Barbell', 'Cable', 'Dumbbell',
    'E-Z Curl Bar', 'Exercise Ball', 'Kettlebells', 'Machine',
    'Medicine Ball', 'Weight Bench', 'None', 'Other'
  ];
  final List<String> days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  String? selectedSplit;
  String? selectedGoal;
  String? selectedIntensity;
  String? selectedCategory;
  List<String> selectedEquipment = [];
  Set<int> selectedRestDays = {};

  final TextEditingController targetWeightController = TextEditingController();
  final TextEditingController bmiController = TextEditingController();

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://192.168.1.4:8080';
  }

  Future<void> saveProfile() async {
    if (widget.token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Token tidak tersedia. Silakan login ulang."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final int frequency = 7 - selectedRestDays.length;

    if (selectedSplit == 'Push/Pull/Legs' && !(frequency == 3 || frequency == 6)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Split 'Push/Pull/Legs' hanya valid jika kamu latihan 3 atau 6 hari per minggu."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse('${getBaseUrl()}/protected/profile');
    final body = jsonEncode({
      'split_type': selectedSplit,
      'goal': selectedGoal,
      'intensity': selectedIntensity,
      'bmi_category': selectedCategory,
      'equipment': selectedEquipment,
      'rest_days': selectedRestDays.toList(),
      'target_weight': double.tryParse(targetWeightController.text),
      'bmi': double.tryParse(bmiController.text),
      'duration_per_session': 45,
      'frequency': frequency,
    });

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      print("📤 Profiling response status: ${response.statusCode}");
      print("📤 Profiling response body: ${response.body}");

      if (response.statusCode == 200) {
        final genUrl = Uri.parse('${getBaseUrl()}/protected/plans/generate');
        final genRes = await http.post(
          genUrl,
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );

        print("🧠 Generate Plan status: ${genRes.statusCode}");
        print("🧾 Generate Plan body: ${genRes.body}");

        if (genRes.statusCode == 200) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal generate workout plan.\n[${genRes.statusCode}] ${genRes.body}"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan profil. [${response.statusCode}]"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal menyimpan profil (network/server error)."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profile Setup"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDropdown("Split Type", splits, selectedSplit, (value) => setState(() => selectedSplit = value)),
            _buildDropdown("Goal", goals, selectedGoal, (value) => setState(() => selectedGoal = value)),
            _buildDropdown("Intensity", intensities, selectedIntensity, (value) => setState(() => selectedIntensity = value)),
            _buildDropdown("BMI Category", categories, selectedCategory, (value) => setState(() => selectedCategory = value)),
            const SizedBox(height: 16),
            _buildTextInput("Target Weight (kg)", targetWeightController, TextInputType.number),
            _buildTextInput("BMI", bmiController, TextInputType.number),
            const SizedBox(height: 16),
            const Text("Equipment", style: TextStyle(color: Colors.white, fontSize: 16)),
            Wrap(
              spacing: 8,
              children: equipment.map((e) => FilterChip(
                label: Text(e),
                selected: selectedEquipment.contains(e),
                onSelected: (bool selected) {
                  setState(() {
                    selected ? selectedEquipment.add(e) : selectedEquipment.remove(e);
                  });
                },
                labelStyle: const TextStyle(color: Colors.white),
                selectedColor: Colors.orange,
                backgroundColor: Colors.grey[800],
              )).toList(),
            ),
            const SizedBox(height: 24),
            const Text("Rest Days", style: TextStyle(color: Colors.white, fontSize: 16)),
            Wrap(
              spacing: 10,
              children: List.generate(7, (index) {
                return FilterChip(
                  label: Text(days[index]),
                  selected: selectedRestDays.contains(index + 1),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedRestDays.add(index + 1);
                      } else {
                        selectedRestDays.remove(index + 1);
                      }
                    });
                  },
                  labelStyle: const TextStyle(color: Colors.white),
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.grey[800],
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (selectedSplit != null &&
                    selectedGoal != null &&
                    selectedIntensity != null &&
                    selectedCategory != null &&
                    selectedEquipment.isNotEmpty &&
                    selectedRestDays.isNotEmpty &&
                    targetWeightController.text.isNotEmpty &&
                    bmiController.text.isNotEmpty) {
                  saveProfile();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please complete all fields before proceeding."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Save Profile"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          dropdownColor: Colors.grey[900],
          value: selectedValue,
          onChanged: onChanged,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(color: Colors.white)),
          )).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[850],
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

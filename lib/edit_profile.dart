import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
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

  final TextEditingController nameController = TextEditingController();
  final TextEditingController targetWeightController = TextEditingController(text: "65");
  final TextEditingController bmiController = TextEditingController(text: "22.5");

  String? selectedSplit;
  String? selectedGoal;
  String? selectedIntensity;
  String? selectedCategory;
  List<String> selectedEquipment = [];
  Set<int> selectedRestDays = {};

  @override
  void initState() {
    super.initState();
    _loadNameFromPrefs();
  }

  Future<void> _loadNameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    nameController.text = prefs.getString('name') ?? '';
  }

  Future<void> _saveNameToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildTextField("Full Name", nameController),
            _buildDropdown("Split Type", splits, selectedSplit, (val) => setState(() => selectedSplit = val)),
            _buildDropdown("Goal", goals, selectedGoal, (val) => setState(() => selectedGoal = val)),
            _buildDropdown("Intensity", intensities, selectedIntensity, (val) => setState(() => selectedIntensity = val)),
            _buildDropdown("BMI Category", categories, selectedCategory, (val) => setState(() => selectedCategory = val)),
            const SizedBox(height: 16),
            _buildTextField("Target Weight (kg)", targetWeightController, inputType: TextInputType.number),
            _buildTextField("BMI", bmiController, inputType: TextInputType.number),
            const SizedBox(height: 16),
            const Text("Equipment", style: TextStyle(color: Colors.white, fontSize: 16)),
            Wrap(
              spacing: 8,
              children: equipment.map((e) => FilterChip(
                label: Text(e),
                selected: selectedEquipment.contains(e),
                onSelected: (selected) {
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveNameToPrefs();
                  // TODO: Simpan semua data lainnya ke backend jika dibutuhkan
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Profile updated successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Save Changes"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType inputType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter $label",
            hintStyle: TextStyle(color: Colors.grey[400]),
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
}

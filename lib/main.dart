// [IMPORTS]
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';

import 'Login.dart';
import 'exercise.dart';
import 'nutrition.dart';
import 'setting.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Login(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = const [
    HomeScreen(),
    ExercisePage(),
    ReplacementExercisePage(),
    Setting(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
        physics: const NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Exercise'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Replacement'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String username = 'Loading...';
  String targetWeight = '-';
  String planLevel = '-';
  String goal = '-';
  String todayWorkoutFocus = '';
  List<Map<String, dynamic>> schedule = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadUserAndSchedule();
  }

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://192.168.1.4:8080';
  }

  String getMotivationalMessage(String focus) {
    final List<String> messages = [
      "🔥 Tantang dirimu hari ini dengan sesi $focus!",
      "💪 Saatnya jadi lebih kuat dengan latihan $focus!",
      "🚀 Ayo bergerak! Fokus latihan hari ini: $focus.",
      "🌟 Jangan biarkan harimu berlalu tanpa aksi. Fokus: $focus!",
      "⚡ Fokus hari ini adalah $focus. Kamu pasti bisa menaklukkannya!",
    ];
    return messages[Random().nextInt(messages.length)];
  }

  Future<void> checkAndRegeneratePlan(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    final lastDateStr = prefs.getString('lastGeneratedDate');
    if (lastDateStr == todayStr) return;

    final response = await http.post(
      Uri.parse('${getBaseUrl()}/protected/plans/generate'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await prefs.setString('lastGeneratedDate', todayStr);
    }
  }

  Future<void> loadUserAndSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      await checkAndRegeneratePlan(token);

      final userResponse = await http.get(
        Uri.parse('${getBaseUrl()}/protected/user'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final planResponse = await http.get(
        Uri.parse('${getBaseUrl()}/protected/plans/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final profileResponse = await http.get(
        Uri.parse('${getBaseUrl()}/protected/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 200 &&
          planResponse.statusCode == 200 &&
          profileResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        final planData = jsonDecode(planResponse.body);
        final profileData = jsonDecode(profileResponse.body);

        final name = userData['data']?['name'] ?? 'User';
        await prefs.setString('username', name);

        final weight = profileData['data']?['target_weight'];
        if (weight != null) targetWeight = '${weight.toString()} kg';

        final intensity = profileData['data']?['intensity'];
        if (intensity != null) planLevel = intensity.toString();

        final g = profileData['data']?['goal'];
        if (g != null) goal = g.toString();

        DateTime now = DateTime.now();
        String todayDateStr = "${now.day}/${now.month}/${now.year}";
        Map<String, Map<String, dynamic>> planMap = {};

        for (var item in planData['data']['workoutPlan']) {
          int dayNum = item['dayNumber'];
          String focus = item['focus'];
          List exercises = item['exercises'];

          DateTime thisDate = now.add(Duration(days: dayNum - 1));
          String dateStr = "${thisDate.day}/${thisDate.month}/${thisDate.year}";

          if (!planMap.containsKey(dateStr)) {
            planMap[dateStr] = {
              'day': getDayNameFromNumber(thisDate.weekday),
              'date': dateStr,
              'focus': focus,
              'exercises': exercises.map<Map<String, dynamic>>((e) => {
                'name': e['name'],
                'sets': e['sets'],
                'reps': e['reps'],
                'body_part': e['body_part'],
                'equipment': e['equipment'],
              }).toList(),
            };
          }

          if (dateStr == todayDateStr) {
            todayWorkoutFocus = focus;
          }
        }

        List<Map<String, dynamic>> parsedPlan = [];

        for (int i = 0; i < 7; i++) {
          DateTime d = now.add(Duration(days: i));
          String dateStr = "${d.day}/${d.month}/${d.year}";
          if (planMap.containsKey(dateStr)) {
            parsedPlan.add(planMap[dateStr]!);
          } else {
            parsedPlan.add({
              'day': getDayNameFromNumber(d.weekday),
              'date': dateStr,
              'focus': 'Rest',
              'exercises': [],
            });
          }
        }

        setState(() {
          username = name;
          schedule = parsedPlan;
          isLoading = false;
        });
      } else {
        setState(() {
          username = 'Failed to load';
          errorMessage = 'Gagal memuat data dari server';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan saat memuat jadwal.';
        isLoading = false;
      });
    }
  }

  String getDayNameFromNumber(int number) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return (number >= 1 && number <= 7) ? days[number - 1] : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (todayWorkoutFocus.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Workout Hari Ini'),
                            content: Text(getMotivationalMessage(todayWorkoutFocus)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.notifications, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/profile.jpg'),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hey, $username',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Text('Siap untuk olahraga? let’s crush it'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Plan Level', planLevel, Icons.show_chart),
                  _buildStatCard('Goal', goal, Icons.flag),
                  _buildStatCard('Target Weight', targetWeight, Icons.fitness_center),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage.isNotEmpty
                      ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
                      : ListView(
                    children: schedule.map((item) {
                      final time = "${item['day']}, ${item['date']}";
                      final focus = item['focus'];
                      final exercises = item['exercises'] as List<dynamic>;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _buildInfoCard("Workout: $focus", icon: Icons.fitness_center),
                          _buildInfoCardWidget(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Training:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 8),
                                ...exercises.map<Widget>((e) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("• ${e['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        Text("  - Reps: ${e['sets']}x${e['reps']}", style: const TextStyle(color: Colors.white)),
                                        Text("  - Muscle: ${e['body_part']}", style: const TextStyle(color: Colors.white)),
                                        Text("  - Equipment: ${e['equipment']}", style: const TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                            icon: Icons.list_alt,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text, {IconData icon = Icons.info_outline}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildInfoCardWidget(Widget content, {IconData icon = Icons.info_outline}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: content),
        ],
      ),
    );
  }
}

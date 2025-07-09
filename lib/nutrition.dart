import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ReplacementExercisePage extends StatefulWidget {
  const ReplacementExercisePage({super.key});

  @override
  State<ReplacementExercisePage> createState() => _ReplacementExercisePageState();
}

class _ReplacementExercisePageState extends State<ReplacementExercisePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> todayExercises = [];
  bool isLoading = true;
  String? adsUrl;

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://192.168.1.4:8080';
  }

  @override
  void initState() {
    super.initState();
    fetchAllExercises();
    fetchAds();
  }

  Future<void> fetchAds() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final res = await http.get(
        Uri.parse('${getBaseUrl()}/protected/ads?adsID=1'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          adsUrl = data['data']['ads_url'];
        });
      } else {
        print("❌ Failed to fetch ads: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ Error in fetchAds: $e");
    }
  }

  Future<void> fetchAllExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final recRes = await http.get(
        Uri.parse('${getBaseUrl()}/protected/plans/recommendations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Map<int, List<Map<String, dynamic>>> recommendationMap = {};
      if (recRes.statusCode == 200) {
        final recData = jsonDecode(recRes.body)['data'] as List<dynamic>;
        for (final item in recData) {
          final origId = item['originalExerciseId'];
          final replacementsRaw = item['replacements'] ?? [];
          final replacements = List<Map<String, dynamic>>.from(replacementsRaw);
          recommendationMap[origId] = replacements;
        }
      }

      final res = await http.get(
        Uri.parse('${getBaseUrl()}/protected/plans/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final plans = data['data']['workoutPlan'] ?? [];

        todayExercises.clear();
        DateTime now = DateTime.now();

        for (final plan in plans) {
          final int dayNumber = plan['dayNumber'];
          final String focus = plan['focus'];
          final List<dynamic> exercises = plan['exercises'];

          DateTime thisDate = now.add(Duration(days: dayNumber - 1));
          if (thisDate.isAfter(now.add(const Duration(days: 6)))) continue;

          final List<Map<String, dynamic>> exerciseList = [];

          for (final ex in exercises) {
            final int id = ex['exerciseId'];
            final String name = ex['name'];
            final int reps = ex['reps'] ?? 10;
            final recs = recommendationMap[id] ?? [];

            exerciseList.add({
              'planExerciseID': (ex['planExerciseID'] as num?)?.toInt(),
              'originalId': id,
              'originalName': name,
              'reps': reps,
              'controller': TextEditingController(text: reps.toString()),
              'replacementOptions': [
                {'id': id, 'name': name},
                ...recs.map((r) => {'id': r['exerciseId'], 'name': r['name']}), // combine
              ],
              'selectedId': id,
            });
          }

          todayExercises.add({
            'dayNumber': dayNumber,
            'focus': focus,
            'exercises': exerciseList,
          });
        }

        if (!mounted) return;
        setState(() => isLoading = false);
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error in fetchAllExercises: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateSingleExercise(Map<String, dynamic> exercise) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final originalId = exercise['originalId'];
    final selectedId = exercise['selectedId'];
    final int? planExerciseID = (exercise['planExerciseID'] as num?)?.toInt();
    final TextEditingController repsController = exercise['controller'];
    final int newReps = int.tryParse(repsController.text) ?? exercise['reps'];

    if (selectedId == null || selectedId == 0) {
      print("❌ planExerciseID null atau tidak valid: $exercise");
      return;
    }

    print("📦 Mengirim update reps => planExerciseID=$selectedId, newReps=$newReps");

    try {
      if (originalId != selectedId) {
        final replaceRes = await http.put(
          Uri.parse('${getBaseUrl()}/protected/plans/replace'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'originalExerciseId': originalId,
            'newExerciseId': selectedId,
          }),
        );
        print('🔁 Replace Response: ${replaceRes.statusCode} - ${replaceRes.body}');
      }

      final repsRes = await http.put(
        Uri.parse('${getBaseUrl()}/protected/plans/updatereps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'planExerciseID': selectedId,
          'newReps': newReps,
        }),
      );

      print('✅ Reps Update Response: ${repsRes.statusCode} - ${repsRes.body}');

      if (repsRes.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perubahan disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal update reps untuk ID $planExerciseID'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const Icon(Icons.swap_horiz, color: Colors.white),
        actions: const [
          Icon(Icons.notifications, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: todayExercises.length,
                itemBuilder: (context, dayIndex) {
                  final dayPlan = todayExercises[dayIndex];
                  final dayNumber = dayPlan['dayNumber'];
                  final focus = dayPlan['focus'];
                  final exercises = dayPlan['exercises'] as List<Map<String, dynamic>>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hari $dayNumber - Fokus: $focus',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 10),
                      ...exercises.map((exercise) {
                        final options = List<Map<String, dynamic>>.from(exercise['replacementOptions']);
                        final TextEditingController repsController = exercise['controller'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latihan Asli: ${exercise['originalName']}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<int>(
                                value: exercise['selectedId'],
                                dropdownColor: Colors.grey[850],
                                iconEnabledColor: Colors.white,
                                style: const TextStyle(color: Colors.white),
                                isExpanded: true,
                                items: options.map((opt) {
                                  return DropdownMenuItem<int>(
                                    value: opt['id'],
                                    child: Text(opt['name']),
                                  );
                                }).toList(),
                                onChanged: (newId) {
                                  setState(() {
                                    exercise['selectedId'] = newId!;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: repsController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Reps',
                                  labelStyle: TextStyle(color: Colors.orange),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.orange),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _updateSingleExercise(exercise);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: const Text("Simpan", style: TextStyle(color: Colors.black)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(color: Colors.white30),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            color: Colors.grey[850],
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: adsUrl != null
                  ? Image.network(adsUrl!)
                  : const Text(
                '🔸 Iklan tidak tersedia 🔸',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

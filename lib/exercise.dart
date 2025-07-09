import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key});

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> exercises = [];
  int currentIndex = 0;
  bool isLoading = true;
  String errorMessage = '';
  Map<String, dynamic> profile = {};
  String todayFocus = '-';

  bool isRestDay = false;
  bool isRestingNow = false;
  int restSeconds = 30;
  bool isRestSkipped = false;
  String adsUrl = '';

  VideoPlayerController? _videoController;

  String getBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://127.0.0.1:8080';
  }

  @override
  void initState() {
    super.initState();
    fetchTodayWorkout();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> initVideo(String url) async {
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(url);
      await _videoController!.initialize();
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration &&
            !_videoController!.value.isPlaying) {
          _videoController?.pause();
          _videoController?.dispose();
          setState(() {
            _videoController = null;
          });
        }
      });
      await _videoController!.play();
      setState(() {});
    } catch (e) {
      print("Video error: $e");
    }
  }

  Future<void> fetchTodayWorkout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) throw Exception("No token found");

      final profileRes = await http.get(
        Uri.parse('${getBaseUrl()}/protected/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (profileRes.statusCode == 200) {
        profile = jsonDecode(profileRes.body)['data'];
      }

      final response = await http.get(
        Uri.parse('${getBaseUrl()}/protected/plans/today?dayID=1'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final workoutDay = data['data']['workoutDay'];
        if (workoutDay == null || workoutDay['exercises'] == null) {
          setState(() {
            isRestDay = true;
            isLoading = false;
          });
          await fetchAds(token);
          return;
        }

        todayFocus = workoutDay['focus'] ?? '-';

        final parsedExercises = (workoutDay['exercises'] as List).map<Map<String, dynamic>>((e) {
          String imageUrl = e['image_url'] ?? '';
          if (Platform.isAndroid && imageUrl.contains('127.0.0.1')) {
            imageUrl = imageUrl.replaceFirst('127.0.0.1', '10.0.2.2');
          }
          return {
            'id': e['exerciseId'] ?? 0,
            'name': e['name'] ?? '-',
            'reps': e['reps'] ?? 0,
            'sets': e['sets'] ?? 0,
            'rest': 30,
            'image_url': imageUrl,
            'video_url': '',
          };
        }).toList();

        setState(() {
          exercises = parsedExercises;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchAds(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/protected/ads?adsID=1'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          adsUrl = data['data']['ads_url'] ?? '';
        });
      }
    } catch (e) {
      print("Fetch ads error: $e");
    }
  }

  void fetchVideoByExerciseID(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final exerciseID = exercises[id]['id'] ?? 0;
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/protected/exercises/video?exerciseID=$exerciseID'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final videoUrl = jsonDecode(response.body)['data']['video_url'] ?? '';
        if (videoUrl.isNotEmpty) {
          exercises[id]['video_url'] = videoUrl;
          await initVideo(videoUrl);
        }
      }
    } catch (e) {
      print("Fetch video error: $e");
    }
  }

  void startRestTimer(VoidCallback onDone) {
    setState(() {
      isRestingNow = true;
      restSeconds = 30;
      isRestSkipped = false;
    });
    Future.doWhile(() async {
      if (isRestSkipped) {
        setState(() => isRestingNow = false);
        onDone();
        return false;
      }
      if (restSeconds > 0) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          restSeconds--;
        });
        return true;
      } else {
        setState(() => isRestingNow = false);
        onDone();
        return false;
      }
    });
  }

  void goToNext() async {
    if (currentIndex < exercises.length - 1) {
      startRestTimer(() async {
        setState(() => currentIndex++);
        final nextVideo = exercises[currentIndex]['video_url'];
        if (nextVideo.isNotEmpty) await initVideo(nextVideo);
      });
    }
  }

  void goToPrevious() async {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      final prevVideo = exercises[currentIndex]['video_url'];
      if (prevVideo.isNotEmpty) await initVideo(prevVideo);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red)))
          : isRestDay
          ? _buildRestDayAd()
          : Column(
        children: [
          Expanded(
            child: _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            )
                : exercises[currentIndex]['image_url'] != ''
                ? Image.network(exercises[currentIndex]['image_url'], fit: BoxFit.cover)
                : Container(
              width: double.infinity,
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.fitness_center, size: 100, color: Colors.white24),
              ),
            ),
          ),
          _buildExerciseControls(),
        ],
      ),
    );
  }

  Widget _buildExerciseControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercises[currentIndex]['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => fetchVideoByExerciseID(currentIndex),
                icon: const Icon(Icons.play_circle_filled, size: 18),
                label: const Text("Video"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${exercises[currentIndex]['sets']} Sets / ${exercises[currentIndex]['reps']} Reps",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "Rest: ${exercises[currentIndex]['rest']} seconds",
            style: const TextStyle(color: Colors.orange, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCard('Goal', profile['goal'] ?? '-'),
              _buildInfoCard('Intensity', profile['intensity'] ?? '-'),
              _buildInfoCard('Focus', todayFocus),
            ],
          ),
          if (isRestingNow) ...[
            const SizedBox(height: 16),
            Text('Resting... $restSeconds s', style: const TextStyle(color: Colors.orange, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() => isRestSkipped = true),
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip Rest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentIndex > 0)
                ElevatedButton(
                  onPressed: goToPrevious,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                  child: const Text('Previous'),
                ),
              if (currentIndex < exercises.length - 1)
                ElevatedButton(
                  onPressed: isRestingNow ? null : goToNext,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Next'),
                ),
              if (currentIndex == exercises.length - 1)
                const Text("\ud83c\udfcb\ufe0f Last Exercise!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRestDayAd() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hotel, size: 100, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              "Hari ini adalah Rest Day \ud83d\udecc",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Gunakan waktu ini untuk istirahat dan pemulihan. Stay hydrated dan tidur cukup!",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            adsUrl.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                adsUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 160,
              ),
            )
                : const Text(
              "\ud83d\udd39 Iklan tidak tersedia",
              style: TextStyle(color: Colors.orange, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "\ud83d\udce3 Sponsored Content",
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

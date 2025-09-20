import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/Constant/color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({Key? key}) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  ScreenshotController screenshotController = ScreenshotController();
  bool _scanning = false;
  String _resultText = '';
 static final FlutterTts tts = FlutterTts();
  late Timer _beepTimer;

  final apiUrl =
      "${ApiConfig.geminiApi}";
  final header = {
    'Content-Type': 'application/json',
  };

  double _volume = 1.0; // Volume level, range 0.0 to 1.0
  double _currentPosition = 0.0;
  double _totalDuration = 1.0; // Default to 1 to avoid division by zero

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
   tts.stop();
    _beepTimer.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // Play MP4 video
  Future<void> _playMp4(String url) async {
    _controller = VideoPlayerController.file(File(url))
      ..initialize().then((_) {
        setState(() {
          _totalDuration = _controller!.value.duration.inSeconds.toDouble();
        });
        _controller!.play();
        _controller!.addListener(_updatePosition);
      });
  }
   static Future<void> loadAndApplySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Load settings
    double speechRate = prefs.getDouble('speechRate') ?? 0.5;
    double pitch = prefs.getDouble('pitch') ?? 1.0;
    String? voiceName = prefs.getString('voiceName');
    String? voiceLocale = prefs.getString('voiceLocale');

    // Apply settings to TTS engine
    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);

    if (voiceName != null && voiceLocale != null) {
      await tts.setVoice({
        'name': voiceName,
        'locale': voiceLocale,
      });
    } else {
      await tts.setLanguage('id-ID'); // Default language
    }
  }
  
  // Play Video URL (video MP4)
  Future<void> _playVideo(String url) async {
    _controller = VideoPlayerController.network(url)
      ..initialize().then((_) {
        setState(() {
          _totalDuration = _controller!.value.duration.inSeconds.toDouble();
        });
        _controller!.play();
        _controller!.addListener(_updatePosition);
      });
  }

  // Update video position
  void _updatePosition() {
    setState(() {
      _currentPosition = _controller!.value.position.inSeconds.toDouble();
    });
  }

  // Process image for description
  Future<void> _processImage(XFile image) async {
    setState(() {
      _scanning = true;
      _resultText = '';
    });

    // Start beep sound
    _beepTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {});

    try {
      final imageBytes = await image.readAsBytes();
      final base64File = base64Encode(imageBytes);
SharedPreferences prefs = await SharedPreferences.getInstance();
String promptQuality = prefs.getString('promptQuality') ?? 'detail'; 
      final data = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Deskripsikan gambar ini dengan sangat ${promptQuality} dan mudah di mengerti tanpa melihat visual nya, lalu tambahkan 'Linkara semakin di depan."
              },
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64File,
                }
              }
            ]
          }
        ],
      };

      final response = await http.post(Uri.parse(apiUrl),
          headers: header, body: jsonEncode(data));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _resultText = result['candidates'][0]['content']['parts'][0]['text'];
      } else {
        _resultText = 'Error: ${response.statusCode}';
      }
    } catch (e) {
      _resultText = 'Terjadi kesalahan: $e';
    }

    // Stop beep sound
    _beepTimer.cancel();

    setState(() {
      _scanning = false;
    });

    if (_resultText.isNotEmpty) {
      await tts.speak(_resultText);
    }
  }

  Future<void> _captureScreenshot() async {
    screenshotController.capture().then((Uint8List? image) {
      if (image != null) {
        // Process captured image (convert to base64 or use in API)
        _processImage(XFile.fromData(image));
      }
    }).catchError((onError) {
      print(onError);
    });
  }

  // Toggle play/pause
  void _togglePlayPause() {
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linkara Video Describer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor:AppColors.primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: _controller != null
                ? Screenshot(
                    controller: screenshotController,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Text(
                    'No video selected',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
          ),
          if (_resultText.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _resultText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final XFile? video = await ImagePicker().pickVideo(source: ImageSource.gallery);
                        if (video != null) {
                          _playMp4(video.path);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Select MP4 Video',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _captureScreenshot,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _scanning
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Capture Screenshot',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
                  Text(
                  'Video Duration',
                  style: TextStyle(color: Colors.white),
                ),
          
                const SizedBox(height: 20),
                      Slider(
                  value: _currentPosition,
                  min: 0.0,
                  max: _totalDuration,
                  onChanged: (value) {
                    setState(() {
                      _currentPosition = value;
                    });
                    if (_controller != null) {
                      _controller!.seekTo(Duration(seconds: _currentPosition.toInt()));
                    }
                  },
                ),
                  Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _controller != null && _controller!.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  'Volume',
                  style: TextStyle(color: Colors.white),
                ),
                Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: _volume.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                    });
                    if (_controller != null) {
                      _controller!.setVolume(_volume);
                    }
                  },
                ),
                const SizedBox(height: 20),
              
              
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format duration in HH:mm:ss
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
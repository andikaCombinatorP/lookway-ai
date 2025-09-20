import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/coloredboxes.dart';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart'; // Import package video_player
import 'package:video_compress/video_compress.dart'; // Import package video_compress

import 'package:lookway/Constant/color.dart'; // Sesuaikan dengan path Anda

// VideoChat Widget (First Screen)
class VideoChat extends StatefulWidget {
  const VideoChat({super.key});

  @override
  State<VideoChat> createState() => _VideoChatState();
}

class _VideoChatState extends State<VideoChat> {
  File? _selectedVideo;
  bool _scanning = false;
  String _resultText = '';
  static final FlutterTts tts = FlutterTts();
  late VideoPlayerController
      _videoPlayerController; // Controller untuk video player

  final apiUrl = "${ApiConfig.geminiApi}";

  final header = {
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    loadAndApplySettings();
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

  // Fungsi untuk memilih video
  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowCompression: true,
    );

    if (result != null) {
      setState(() {
        _selectedVideo = File(result.files.single.path!);
        _videoPlayerController = VideoPlayerController.file(_selectedVideo!)
          ..initialize().then((_) {
            setState(() {});
            _videoPlayerController.play();
          });
      });
    }
  }

  // Fungsi untuk mengkompres video menggunakan video_compress
  Future<String?> _compressVideo(String inputPath) async {
    try {
      // Inisialisasi VideoCompress
      await VideoCompress.setLogLevel(0); // Nonaktifkan log untuk produksi

      // Kompres video
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(inputPath,
          quality: VideoQuality.LowQuality, // Kualitas medium
          deleteOrigin: false,
          includeAudio: true,
          duration: 120, // Jangan hapus file asli
          frameRate: 24);

      if (mediaInfo != null) {
        return mediaInfo.path; // Return path video yang sudah dikompres
      } else {
        throw Exception('Failed to compress video');
      }
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  // Fungsi untuk memindai video
  Future<void> _scanVideo() async {
    if (_selectedVideo == null) return;

    setState(() {
      _scanning = true;
      _resultText = '';
    });

    try {
      // 1. Check video file size
      final fileSizeInBytes = await _selectedVideo!.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      String videoPath = _selectedVideo!.path;
      String? compressedPath;

      // 2. Compress video if larger than 20MB
      if (fileSizeInMB > 20) {
        print(
            'Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - Compressing...');
        compressedPath = await _compressVideo(videoPath);

        if (compressedPath == null) {
          throw Exception('Failed to compress video');
        }

        // Update video path to compressed version
        videoPath = compressedPath;

        // Check new file size after compression
        final compressedSizeInBytes = await File(videoPath).length();
        final compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
        print(
            'Compressed video size: ${compressedSizeInMB.toStringAsFixed(2)}MB');
      } else {
        print(
            'Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - No compression needed');
      }

      // 3. Read and encode video
      final videoBytes = await File(videoPath).readAsBytes();
      final base64File = base64Encode(videoBytes);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String promptQuality = prefs.getString('promptQuality') ?? 'detail';
      // 4. Send to API
      final data = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Deskripsikan video ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual dan suara nya, lalu tambahkan 'Linkara Access."
              },
              {
                "inlineData": {
                  "mimeType": "video/mp4",
                  "data": base64File,
                }
              }
            ]
          }
        ],
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: header,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _resultText = result['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('API Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        _resultText = 'Coba lagi nanti ya ${response.statusCode}';
      }

      // 5. Clean up compressed file if it was created
      if (compressedPath != null) {
        try {
          await File(compressedPath).delete();
          print('Compressed temporary file deleted');
        } catch (e) {
          print('Error deleting compressed file: $e');
        }
      }
    } catch (e) {
      print('Error processing video: $e');
      _resultText = 'Terjadi kesalahan: $e';
    }

    setState(() {
      _scanning = false;
    });

    if (_resultText.isNotEmpty) {
      await tts.speak(_resultText);
    }
  }

  @override
  void dispose() {
    tts.stop();
    _videoPlayerController.dispose(); // Dispose video controller
    VideoCompress.dispose(); // Dispose VideoCompress
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linkara Video Describer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [ColoredBoxes()],
        backgroundColor: AppColors.primaryColor,
      ),
      body: Stack(
        children: [
          Center(
            child: _selectedVideo != null
                ? AspectRatio(
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        'Select a Video',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
          ),
          if (_resultText.isNotEmpty)
            SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 20.0),
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
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
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedVideo != null)
                    ElevatedButton(
                      onPressed: _scanning ? null : _scanVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _scanning ? Colors.grey : AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15.0,
                          horizontal: 30.0,
                        ),
                      ),
                      child: _scanning
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Scan Video',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15.0,
                        horizontal: 30.0,
                      ),
                    ),
                    child: const Text(
                      'Select Video',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedVideo != null && _resultText.isNotEmpty)
                          Semantics(
                            label: 'Tanya lebih lanjut,tanyakan lebih lanjut jika belum jelas, kami akan memberikan hasil yang terbaik',
                            child: ElevatedButton(
                              onPressed: () {
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) {
    return Semantics(
      label: 'Geser ke bawah untuk kembali',
      child:  ChatMoreVideo(
              imagePath: _selectedVideo!.path,
              description: _resultText,
            ),
     
      
    );
  },
).whenComplete(() {
  // Memberi feedback suara saat modal ditutup, termasuk swipe down
  Future.delayed(Duration(milliseconds: 100), () {
    SemanticsService.announce(
      'Anda menutup tab',
      TextDirection.ltr,
    );
  });
});


                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700]),
                              child: const Text(
                                'Ask More',
                                style:
                                    TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ),
          if (_selectedVideo != null)
            Align(
              alignment: Alignment.center,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    if (_videoPlayerController.value.isPlaying) {
                      _videoPlayerController.pause();
                    } else {
                      _videoPlayerController.play();
                    }
                  });
                },
                child: Icon(
                  _videoPlayerController.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// class ChatMoreVideo extends StatefulWidget {
//   final String imagePath;
//   final String description;

//   const ChatMoreVideo({
//     super.key,
//     required this.imagePath,
//     required this.description,
//   });

//   @override
//   State<ChatMoreVideo> createState() => _ChatMoreVideoState();
// }

// class _ChatMoreVideoState extends State<ChatMoreVideo> {
//   final TextEditingController _questionController = TextEditingController();
//   final List<Map<String, String>> _chatMessages = [];
//   bool _isLoading = false;

//   final FlutterTts _flutterTts = FlutterTts();
//   late VideoPlayerController _videoPlayerController;

//   final apiUrl =
//       "${ApiConfig.geminiApi}";

//   final header = {
//     'Content-Type': 'application/json',
//   };

//   @override
//   void initState() {
//     super.initState();
//     _videoPlayerController = VideoPlayerController.file(File(widget.imagePath))
//       ..initialize().then((_) {
//         setState(() {});
//       });
//   }

//   Future<String?> _compressVideo(String inputPath) async {
//     try {
//       await VideoCompress.setLogLevel(0);

//       final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
//         inputPath,
//         quality: VideoQuality.LowQuality,
//         deleteOrigin: false,
//       );

//       if (mediaInfo != null) {
//         return mediaInfo.path;
//       } else {
//         throw Exception('Failed to compress video');
//       }
//     } catch (e) {
//       print('Error compressing video: $e');
//       return null;
//     }
//   }

//   Future<void> _sendQuestion(String question) async {
//     setState(() {
//       _isLoading = true;
//       _chatMessages.add({"sender": "user", "message": question});
//     });

//     String? compressedPath;
//     try {
//       // 1. Check video file size
//       final file = File(widget.imagePath);
//       final fileSizeInBytes = await file.length();
//       final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

//       String videoPath = widget.imagePath;

//       // 2. Compress video if larger than 20MB
//       if (fileSizeInMB > 20) {
//         print('Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - Compressing...');
//         compressedPath = await _compressVideo(videoPath);

//         if (compressedPath == null) {
//           throw Exception('Failed to compress video');
//         }

//         videoPath = compressedPath;

//         // Check new file size after compression
//         final compressedSizeInBytes = await File(videoPath).length();
//         final compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
//         print('Compressed video size: ${compressedSizeInMB.toStringAsFixed(2)}MB');
//       } else {
//         print('Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - No compression needed');
//       }

//       // 3. Read and encode video
//       final videoBytes = await File(videoPath).readAsBytes();
//       final base64File = base64Encode(videoBytes);

//       final data = {
//         "contents": [
//           {
//             "parts": [
//               {"text": question},
//               {
//                 "inlineData": {
//                   "mimeType": "video/mp4",
//                   "data": base64File,
//                 }
//               }
//             ]
//           }
//         ],
//       };

//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: header,
//         body: jsonEncode(data)
//       );

//       if (response.statusCode == 200) {
//         final result = jsonDecode(response.body);
//         final answer = result['candidates'][0]['content']['parts'][0]['text'];

//         setState(() {
//           _chatMessages.add({"sender": "bot", "message": answer});
//         });

//         await _flutterTts.speak(answer);
//       } else {
//         setState(() {
//           _chatMessages.add({
//             "sender": "bot",
//             "message": "Error: ${response.statusCode}. Please try again."
//           });
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _chatMessages.add({
//           "sender": "bot",
//           "message": "An error occurred: $e"
//         });
//       });
//     } finally {
//       // Clean up compressed file if it was created
//       if (compressedPath != null) {
//         try {
//           await File(compressedPath).delete();
//           print('Compressed temporary file deleted');
//         } catch (e) {
//           print('Error deleting compressed file: $e');
//         }
//       }

//       setState(() {
//         _isLoading = false;
//         _questionController.clear();
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _flutterTts.stop();
//     _videoPlayerController.dispose();
//     VideoCompress.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Chat More',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.black,
//       ),
//       body: Column(
//         children: [
//           // Video Player Section
//           Expanded(
//             flex: 2,
//             child: SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Description:',
//                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       widget.description,
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                     const SizedBox(height: 20),
//                     Center(
//                       child: _videoPlayerController.value.isInitialized
//                           ? AspectRatio(
//                               aspectRatio: _videoPlayerController.value.aspectRatio,
//                               child: VideoPlayer(_videoPlayerController),
//                             )
//                           : const CircularProgressIndicator(),
//                     ),
//                     const SizedBox(height: 10),
//                     FloatingActionButton(
//                       onPressed: () {
//                         setState(() {
//                           if (_videoPlayerController.value.isPlaying) {
//                             _videoPlayerController.pause();
//                           } else {
//                             _videoPlayerController.play();
//                           }
//                         });
//                       },
//                       child: Icon(
//                         _videoPlayerController.value.isPlaying
//                             ? Icons.pause
//                             : Icons.play_arrow,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Chat Section
//           Expanded(
//             child: Container(
//               color: Colors.grey[100],
//               child: ListView.builder(
//                 padding: const EdgeInsets.all(10.0),
//                 itemCount: _chatMessages.length,
//                 itemBuilder: (context, index) {
//                   final message = _chatMessages[index];
//                   final isUser = message["sender"] == "user";
//                   return Align(
//                     alignment:
//                         isUser ? Alignment.centerRight : Alignment.centerLeft,
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(vertical: 5.0),
//                       padding: const EdgeInsets.all(10.0),
//                       decoration: BoxDecoration(
//                         color: isUser ? Colors.blue : Colors.grey[300],
//                         borderRadius: BorderRadius.circular(10.0),
//                       ),
//                       child: Text(
//                         message["message"]!,
//                         style: TextStyle(
//                           color: isUser ? Colors.white : Colors.black,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),

//           // Input and Loading Section
//           if (_isLoading)
//             const Padding(
//               padding: EdgeInsets.all(10.0),
//               child: CircularProgressIndicator(),
//             ),
//           Padding(
//             padding: const EdgeInsets.all(10.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _questionController,
//                     decoration: InputDecoration(
//                       labelText: 'Ask a question',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10.0),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: () {
//                     final question = _questionController.text.trim();
//                     if (question.isNotEmpty) {
//                       _sendQuestion(question);
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
//                   child: const Text('Send'),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class ChatMoreVideo extends StatefulWidget {
  final String imagePath;
  final String description;

  const ChatMoreVideo({
    super.key,
    required this.imagePath,
    required this.description,
  });

  @override
  State<ChatMoreVideo> createState() => _ChatMoreVideoState();
}

class _ChatMoreVideoState extends State<ChatMoreVideo> {
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  final FocusNode _progressFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  final FocusNode _latestResponseFocusNode = FocusNode();
  final FocusNode _focusAwal = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isLoading = false;
  String lastRecognizedText = '';
  Timer? _debounceTimer;
  late VideoPlayerController _videoPlayerController;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusAwal);
      }
    });

    _videoPlayerController = VideoPlayerController.file(File(widget.imagePath))
      ..initialize().then((_) {
        setState(() {});
      });
// Future.delayed(Duration.zero, () {
//     if (mounted) {
//       FocusScope.of(context).requestFocus(_focusAwal);
//     }
//   });
  }

  final FlutterTts _flutterTts = FlutterTts();

  final apiUrl = "${ApiConfig.geminiApi}";

  final header = {
    'Content-Type': 'application/json',
  };

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _questionController.text = result.recognizedWords;
          // Reset debounce timer on every new speech result
          _debounceTimer?.cancel();
          _debounceTimer = Timer(Duration(seconds: 2), _onSpeechEnded);
        });
      });
    }
  }

  void _onSpeechEnded() async {
    // Ambil pertanyaan yang dikenali
    final question = _questionController.text.trim();

    if (question.isNotEmpty) {
      // Bacakan teks menggunakan TTS
      await _flutterTts.speak('Pertanyaan anda ,${question}');

      // Tunggu hingga TTS selesai
      await _flutterTts.awaitSpeakCompletion(true);

      // Setelah selesai, kirimkan pertanyaan
      _sendQuestion(question);
    }

    _stopListening(); // Hentikan pendengaran setelah selesai
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<String?> _compressVideo(String inputPath) async {
    try {
      await VideoCompress.setLogLevel(0);

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        inputPath,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );

      if (mediaInfo != null) {
        return mediaInfo.path;
      } else {
        throw Exception('Failed to compress video');
      }
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  Future<void> _sendQuestion(String question) async {
    setState(() {
      _isLoading = true;
      _chatMessages.add({"sender": "user", "message": question});
    });

    String? compressedPath;
    try {
      // 1. Check video file size
      final file = File(widget.imagePath);
      final fileSizeInBytes = await file.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      String videoPath = widget.imagePath;

      // 2. Compress video if larger than 20MB
      if (fileSizeInMB > 20) {
        print(
            'Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - Compressing...');
        compressedPath = await _compressVideo(videoPath);

        if (compressedPath == null) {
          throw Exception('Failed to compress video');
        }

        videoPath = compressedPath;

        // Check new file size after compression
        final compressedSizeInBytes = await File(videoPath).length();
        final compressedSizeInMB = compressedSizeInBytes / (1024 * 1024);
        print(
            'Compressed video size: ${compressedSizeInMB.toStringAsFixed(2)}MB');
      } else {
        print(
            'Video size: ${fileSizeInMB.toStringAsFixed(2)}MB - No compression needed');
      }

      // 3. Read and encode video
      final videoBytes = await File(videoPath).readAsBytes();
      final base64File = base64Encode(videoBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {"text": "dalam video tersebut ${question}"},
              {
                "inlineData": {
                  "mimeType": "video/mp4",
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
        final answer = result['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          _chatMessages.add({"sender": "bot", "message": answer});
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        });
        // Langsung ucapkan jawaban menggunakan TTS
        setState(() {
          _isLoading = false;
          _questionController.clear();
        });

        FocusScope.of(context).requestFocus(_latestResponseFocusNode);

        await _flutterTts.speak(answer);
      } else {
        setState(() {
          _chatMessages.add({
            "sender": "bot",
            "message": "Error: ${response.statusCode}. Please try again."
          });
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages
            .add({"sender": "bot", "message": "An error occurred: $e"});
      });
    } finally {}
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _progressFocusNode.dispose();
    _videoPlayerController.dispose(); // Dispose video controller
    VideoCompress.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 300,
            color: Colors.teal,
            child: ColoredBoxes(),
          ),
          // Bagian Deskripsi
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Container(
                color: Colors.yellow,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Semantics(
                        label:
                            'ini hasil tangkapan anda, ini deskripsi sebelumnya ,${widget.description}',
                        child: Center(
                          child: _videoPlayerController.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio:
                                      _videoPlayerController.value.aspectRatio,
                                  child: VideoPlayer(_videoPlayerController),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            if (_videoPlayerController.value.isPlaying) {
                              _videoPlayerController.pause();
                            } else {
                              _videoPlayerController.play();
                            }
                          });
                        },
                        child: Icon(
                          _videoPlayerController.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),

                      const SizedBox(height: 20), // Jarak setelahnya

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bagian Chat
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: ListView.builder(
                controller: _scrollController, // Tambahkan ini
                padding: const EdgeInsets.all(10.0),
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final message = _chatMessages[index];
                  final isUser = message["sender"] == "user";
                  final isLastMessage =
                      index == _chatMessages.length - 1 && !isUser;

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Focus(
                      focusNode:
                          isLastMessage ? _latestResponseFocusNode : null,
                      child: Semantics(
                        label: isUser
                            ? 'Ini pesan yang Anda kirimkan.'
                            : 'Ini balasan dari AI.',
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primaryTeal
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            message["message"]!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bagian Input dan Loading
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Focus(
                focusNode: _progressFocusNode,
                child: Semantics(
                    label: 'mohon tunggu sebentar,sedang di proses',
                    child: const CircularProgressIndicator()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Semantics(
                  label: 'voice text, klik untuk mulai berbicara',
                  child: Focus(
                    focusNode: _focusAwal,
                    child: IconButton(
                      autofocus: true,
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.black),
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: 'isi permintaan lebih lanjut anda',
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        labelText: 'Ajukan pertanyaan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final question = _questionController.text.trim();
                    if (question.isNotEmpty) {
                      _sendQuestion(question);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor),
                  child: Semantics(
                      label: 'tombol kirim,klik untuk mengirim pertanyaan',
                      child: const Text('Send')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

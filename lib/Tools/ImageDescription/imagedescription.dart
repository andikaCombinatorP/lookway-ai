import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Import Timer
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lookway/Api/api_config.dart';

import 'package:lookway/Constant/color.dart';
import 'package:lookway/coloredboxes.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // Pastikan ini sesuai dengan proyek Anda

class ImageChat extends StatefulWidget {
  const ImageChat({super.key});

  @override
  State<ImageChat> createState() => _ImageChatState();
}

class _ImageChatState extends State<ImageChat> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _scanning = false;
String promptQuality='detail';
  String _resultText = '';
  XFile? _capturedImage;
 static final FlutterTts tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  FocusNode _progressFocusNode = FocusNode();
  final FocusNode _captureButtonFocusNode = FocusNode();
final FocusNode _resultFocusNode = FocusNode();

  late Timer _beepTimer; // Timer untuk beep
  final apiUrl = "${ApiConfig.geminiApi}";
  final header = {
    'Content-Type': 'application/json',
  };


  @override
  void initState() {
    super.initState();
    _initializeCamera();
    loadAndApplySettings();
    _loadPromptQuality();
       _captureButtonFocusNode.requestFocus();
// Atur pitch untuk suara tetap natural
  }
   static Future<String> getPromptQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('promptQuality') ?? 'detail';
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
    Future<void> _loadPromptQuality() async {
    String quality = await getPromptQuality();
    setState(() {
      promptQuality = quality;
    });
  }
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras.first, ResolutionPreset.high);
    await _cameraController.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  // Fungsi untuk menangani pemrosesan gambar
  Future<void> _captureImage() async {
    if (!_cameraController.value.isInitialized || _scanning) return;

    setState(() {
      _scanning = true;
      _resultText = '';
    });
    await _cameraController.setFlashMode(FlashMode.torch);
    // Memulai beep berulang setiap 100 mili detik

    _audioPlayer.play(AssetSource('images/logo/process.mp3'));
    try {
      final XFile file = await _cameraController.takePicture();
      _capturedImage = file;

      final imageBytes = await file.readAsBytes();
      final base64File = base64Encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Deskripsikan gambar ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual, lalu tambahkan 'Linkara semakin di depan."
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
        _resultText = 'coba lagi nanti ya ${response.statusCode}';
      }
    } catch (e) {
      _resultText = 'Terjadi kesalahan: $e';
    }
    await _cameraController.setFlashMode(FlashMode.off);
  FocusScope.of(context).requestFocus(_resultFocusNode);
    setState(() {
      _scanning = false;
    });
    _audioPlayer.stop();
    if (_resultText.isNotEmpty) {
      await tts.speak(_resultText);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
   tts.stop();
 // Pastikan timer dihentikan
    super.dispose();
      _progressFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
appBar: AppBar(),
      body: _isCameraInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController),
                if (_resultText.isNotEmpty)
                  SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Semantics(
                        label: 'Berikut Hasilnya',
                        child: Focus(
                              focusNode: _resultFocusNode, 
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
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
        
  ElevatedButton(
     focusNode: _captureButtonFocusNode, 
    onPressed: () {
      _captureImage();
      // Pindah fokus ke CircularProgressIndicator ketika sedang memproses
      if (_scanning) {
        FocusScope.of(context).requestFocus(_progressFocusNode);
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryColor,
      padding: const EdgeInsets.symmetric(
        vertical: 15.0,
        horizontal: 30.0,
      ),
    ),
    child: _scanning
        ? Semantics(
label: 'Foto telah berhasil ditangkap.anda menyuruh kami mendiskripsikan secara ${promptQuality}, Proses analisis sedang berlangsung dengan cermat. Harap tunggu sejenak, kami sedang menyiapkan hasil yang akurat dan relevan. Hasil analisis akan segera tersedia dan siap untuk anda dengarkan.'
,
          child: Focus(
            includeSemantics: true,
              focusNode: _progressFocusNode,
              child: const CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        )
        : const Text(
          semanticsLabel: 'Image describer,Capture,Tangkap foto untuk memulai proses,klik untuk mulai menangkap',
            'Tangkap foto',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
  
),

                        const SizedBox(height: 10),
                        if (_capturedImage != null && _resultText.isNotEmpty)
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
      child:  ChatMoreCamera(
              imagePath: _capturedImage!.path,
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
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}

class ChatMoreCamera extends StatefulWidget {
  final String imagePath;
  final String description;

  const ChatMoreCamera({
    super.key,
    required this.imagePath,
    required this.description,
  });

  @override
  State<ChatMoreCamera> createState() => _ChatMoreCameraState();
}

class _ChatMoreCameraState extends State<ChatMoreCamera> {
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

  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      FocusScope.of(context).requestFocus(_focusAwal);
    }
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

  Future<void> _sendQuestion(String question) async {
    setState(() {
      _isLoading = true;
      _chatMessages.add({"sender": "user", "message": question});
    });
     FocusScope.of(context).requestFocus(_progressFocusNode);
    Future.delayed(const Duration(milliseconds: 100), () {
  _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
    duration: const Duration(milliseconds: 100),
    curve: Curves.easeOut,
  );
});

    try {
      final imageBytes = await File(widget.imagePath).readAsBytes();
      final base64File = base64Encode(imageBytes);

      final data = {
        "contents": [
          {
            "parts": [
              {"text":'dalam gambar tersebut${question}' },
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
    } finally {

    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
       _progressFocusNode.dispose();
         _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: Column(
        children: [
          Container(height: 300,color: Colors.teal,child: ColoredBoxes(),),
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
                         
                        label: 'ini hasil tangkapan anda, ini deskripsi sebelumnya ,${widget.description}',
                        child: Center(
                          child: Image.file(
                            File(widget.imagePath),
                            height: 200,
                            fit: BoxFit.contain,
                          ),
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
              child:ListView.builder(
  controller: _scrollController, // Tambahkan ini
  padding: const EdgeInsets.all(10.0),
  itemCount: _chatMessages.length,
 itemBuilder: (context, index) {
  final message = _chatMessages[index];
  final isUser = message["sender"] == "user";
  final isLastMessage = index == _chatMessages.length - 1 && !isUser;

  return Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Focus(
      focusNode: isLastMessage ? _latestResponseFocusNode : null,
      child: Semantics(
        label: isUser
            ? 'Ini pesan yang Anda kirimkan.'
            : 'Ini balasan dari AI.',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primaryTeal : Colors.grey[300],
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
                child: Semantics(label: 'mohon tunggu sebentar,sedang di proses',
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
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.black),
                          onPressed: _isListening ? _stopListening : _startListening,
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                    child: Semantics(
                      label: 'tombol kirim,klik untuk mengirim pertanyaan',
                      
                      child:
                     const Text('Send')),
                  ),
           
              ],
            ),
          ),
        ],
      ),
    );
  }
}

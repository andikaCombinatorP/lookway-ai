import 'dart:io';
import 'dart:convert';
import 'dart:async'; // Import Timer
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:image_picker/image_picker.dart'; // Tambahkan import image_picker
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/coloredboxes.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:lookway/Constant/color.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Pastikan ini sesuai dengan proyek Anda

class ImageDescriber extends StatefulWidget {
  const ImageDescriber({super.key});

  @override
  State<ImageDescriber> createState() => _ImageDescriberState();
}

class _ImageDescriberState extends State<ImageDescriber> {
  XFile? _pickedImage;
  bool _scanning = false;
  String _resultText = '';
 static final FlutterTts tts = FlutterTts();
  late Timer _beepTimer;
  bool _isSpeaking = false;
  String _lastPosition = '0'; // Track last speaking position
  final AudioPlayer _audioPlayer = AudioPlayer();

  final apiUrl =
      "${ApiConfig.geminiApi}";

  final header = {
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    loadAndApplySettings();
    _initTts();
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
  void _initTts() {
  tts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

   tts.setProgressHandler(
      (String text, int startOffset, int endOffset, String word) {
        _lastPosition = word;
      },
    );
  }

  Future<void> _controlTts() async {
    if (_isSpeaking) {
      await _pauseTts();
    } else {
      await _resumeTts();
    }
  }

  Future<void> _pauseTts() async {
    final result = await tts.stop();
    if (result == 1) {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _resumeTts() async {
    if (_resultText.isNotEmpty) {
      // If we have a last position, start from there, otherwise start from beginning
      String textToSpeak = _resultText;
      if (_lastPosition != '0') {
        final lastIndex = _resultText.indexOf(_lastPosition);
        if (lastIndex != -1) {
          textToSpeak = _resultText.substring(lastIndex);
        }
      }
      
      final result = await tts.speak(textToSpeak);
      if (result == 1) {
        setState(() {
          _isSpeaking = true;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImage = image;
      });

      _processImage(image);
    }
  }

 Future<void> _processImage(XFile image) async {
  setState(() {
    _scanning = true;
    _resultText = '';
    _lastPosition = '0'; // Reset last position when processing new image
  });

  // Mulai memainkan suara MP3
  _audioPlayer.play(AssetSource('images/logo/process.mp3'));

  try {
    final imageBytes = await image.readAsBytes();
    final base64File = base64Encode(imageBytes);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String promptQuality = prefs.getString('promptQuality') ?? 'detail';

    final data = {
      "contents": [
        {
          "parts": [
            {"text": "Deskripsikan gambar ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual nya, lalu tambahkan 'Linkara Access."},
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

  // Hentikan suara setelah proses selesai
  _audioPlayer.stop();

  setState(() {
    _scanning = false;
  });

  if (_resultText.isNotEmpty) {
    _resumeTts(); // Automatically start speaking
  }
}

  @override
  void dispose() {
   tts.stop();
    _beepTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linkara Image Describer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),actions: [ColoredBoxes()],
        backgroundColor: AppColors.primaryColor,
      ),
      
      body: Stack(
        children: [
          Center(
            child: _pickedImage == null
                ? const Text(
                    'No image selected',
                    style: TextStyle(fontSize: 18),
                  )
                : Image.file(
                    File(_pickedImage!.path),
                    fit: BoxFit.cover,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _resultText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      IconButton(
                        onPressed: _controlTts,
                        icon: Icon(
                          _isSpeaking ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
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
                    onPressed: _pickImageFromGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15.0,
                        horizontal: 30.0,
                      ),
                    ),
                    child: _scanning
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Select from Gallery',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 10),
                 if (_pickedImage != null && _resultText.isNotEmpty)
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
      child:  ChatMore(
              imagePath: _pickedImage!.path,
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
      ),
    );
  }
}

class ChatMore extends StatefulWidget {
  final String imagePath;
  final String description;

  const ChatMore({
    super.key,
    required this.imagePath,
    required this.description,
  });

  @override
  State<ChatMore> createState() => _ChatMoreState();
}

class _ChatMoreState extends State<ChatMore> {
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

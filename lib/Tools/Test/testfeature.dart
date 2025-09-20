import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/semantics.dart';

import 'package:http/http.dart' as http;
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/Constant/color.dart';
import 'package:lookway/coloredboxes.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart'as stt;

class AudioDescriber extends StatefulWidget {
  const AudioDescriber({super.key});

  @override
  State<AudioDescriber> createState() => _AudioDescriberState();
}

class _AudioDescriberState extends State<AudioDescriber> {
  File? _audioFile;
  bool _processing = false;
  String _resultText = '';

  final apiUrl = "${ApiConfig.geminiApi}";

  final header = {
    'Content-Type': 'application/json',
  };

 Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (result != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
      });
      _processAudio(_audioFile!);
    }
  }

  Future<void> _processAudio(File audioFile) async {
    setState(() {
      _processing = true;
      _resultText = '';
    });

    try {
      final audioBytes = await audioFile.readAsBytes();
      final base64File = base64Encode(audioBytes);
 SharedPreferences prefs = await SharedPreferences.getInstance();

      String promptQuality = prefs.getString('promptQuality') ?? 'detail';
      final data = {
        "contents": [
          {
            "parts": [
              {"text": "Deskripsikan suara ini dengan sangat ${promptQuality} dan mudah dimengerti oleh orang yang tidak mendengarkannya dan beri kutipan percakapan yang anda ketahui jika ada, lalu tambahkan 'Linkara semakin di depan.'"},
              {
                "inlineData": {
                  "mimeType": "audio/mp3",
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
        body: jsonEncode(data)
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _resultText = result['candidates'][0]['content']['parts'][0]['text'];
      } else {
        _resultText = 'Error: ${response.statusCode}';
      }
    } catch (e) {
      _resultText = 'Terjadi kesalahan: $e';
    }

    setState(() {
      _processing = false;
    });

  }

  @override
  void dispose() {
 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linkara Audio Describer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: 
Stack(
          children: [
            Center(
              child: _audioFile == null
                  ? const Text(
                      'No audio file selected',
                      style: TextStyle(fontSize: 18),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.audio_file, size: 48),
                        Text(
                          'Audio file: ${_audioFile!.path.split('/').last}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
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
                    ElevatedButton(
                      onPressed: _pickAudioFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15.0,
                          horizontal: 30.0,
                        ),
                      ),
                      child: _processing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Select Audio File',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 10),
                    if (_audioFile != null && _resultText.isNotEmpty)
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
      child:  ChatMoreAudio(
              audioPath: _audioFile!.path,
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


// class ChatMoreAudio extends StatefulWidget {
//   final String audioPath;
//   final String description;

//   const ChatMoreAudio({
//     super.key,
//     required this.audioPath,
//     required this.description,
//   });

//   @override
//   State<ChatMoreAudio> createState() => _ChatMoreAudioState();
// }

// class _ChatMoreAudioState extends State<ChatMoreAudio> {
//   final TextEditingController _questionController = TextEditingController();
//   final List<Map<String, String>> _chatMessages = [];
//   bool _isLoading = false;



//   final apiUrl =
//       "${ApiConfig.geminiApi}";

//   final header = {
//     'Content-Type': 'application/json',
//   };

//   Future<void> _sendQuestion(String question) async {
//     setState(() {
//       _isLoading = true;
//       _chatMessages.add({"sender": "user", "message": question});
//     });

//     try {
//       final audioBytes = await File(widget.audioPath).readAsBytes();
//       final base64File = base64Encode(audioBytes);

//       final data = {
//         "contents": [
//           {
//             "parts": [
//               {"text": question},
//               {
//                 "inlineData": {
//                   "mimeType": "audio/mpeg",
//                   "data": base64File,
//                 }
//               }
//             ]
//           }
//         ],
//       };

//       final response = await http.post(Uri.parse(apiUrl),
//           headers: header, body: jsonEncode(data));

//       if (response.statusCode == 200) {
//         final result = jsonDecode(response.body);
//         final answer = result['candidates'][0]['content']['parts'][0]['text'];

//         setState(() {
//           _chatMessages.add({"sender": "bot", "message": answer});
//         });

        
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
//       setState(() {
//         _isLoading = false;
//         _questionController.clear();
//       });
//     }
//   }

//   @override
//   void dispose() {

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
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       widget.description,
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                     const SizedBox(height: 20),
//                     Center(
//                       child: Icon(
//                         Icons.audiotrack,
//                         size: 100,
//                         color: Colors.blue,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
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
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.black),
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


class ChatMoreAudio extends StatefulWidget {
  final String audioPath;
  final String description;

  const ChatMoreAudio({
    super.key,
    required this.audioPath,
    required this.description,
  });

  @override
  State<ChatMoreAudio> createState() => _ChatMoreAudioState();
}

class _ChatMoreAudioState extends State<ChatMoreAudio> {
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


    // Tunggu hingga TTS selesai

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
      final audioBytes = await File(widget.audioPath).readAsBytes();
      final base64File = base64Encode(audioBytes);


      final data = {
        "contents": [
          {
            "parts": [
              {"text":'dalam audio tersebut${question}' },
              {
                 "inlineData": {
                  "mimeType": "audio/mp3",
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
                       child: Icon(
                        Icons.audiotrack,
                         size: 100,
                       color: Colors.blue,
                      
                  ),
                      ),
    
                
                       ),
                     
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

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/coloredboxes.dart';

import 'package:path/path.dart' as path;

import 'package:lookway/Constant/color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart'as stt;

class PdfDescriber extends StatefulWidget {
  const PdfDescriber({super.key});

  @override
  State<PdfDescriber> createState() => _PdfDescriberState();
}

class _PdfDescriberState extends State<PdfDescriber> {
  PlatformFile? _pickedPdf;
  bool _processing = false;
  String _resultText = '';
  final FlutterTts _flutterTts = FlutterTts();
  late Timer _beepTimer;
  
  final apiUrl = "${ApiConfig.geminiApi}";

  final header = {
    'Content-Type': 'application/json',
  };

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _pickedPdf = result.files.first;
        });

        _processPdf(result.files.first);
      }
    } catch (e) {
      setState(() {
        _resultText = 'Error picking PDF: $e';
      });
    }
  }

  Future<void> _processPdf(PlatformFile file) async {
    setState(() {
      _processing = true;
      _resultText = '';
    });

    _beepTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      // Beep sound logic here if needed
    });

    try {
      final bytes = await File(file.path!).readAsBytes();
      final base64Pdf = base64Encode(bytes);
SharedPreferences prefs = await SharedPreferences.getInstance();
String promptQuality = prefs.getString('promptQuality') ?? 'detail'; 
      final data = {
        "contents": [
          {
            "parts": [
              {"text": "Berikan deskripsi ${promptQuality} semi ringkas dari dokumen PDF berikut ini dalam bahasa yang mudah dimengerti bagi orang yang tidak melihat dokumennya dan isi gambarnya jika ada, lalu tambahkan 'Linkara Access.' di akhir:"},
              {
                "inlineData": {
                  "mimeType": "application/pdf",
                  "data": base64Pdf,
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
        _resultText = 'Error: ${response.statusCode}';
      }
    } catch (e) {
      _resultText = 'Terjadi kesalahan: $e';
    }

    _beepTimer.cancel();

    setState(() {
      _processing = false;
    });

    if (_resultText.isNotEmpty) {
      await _flutterTts.speak(_resultText);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _beepTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linkara PDF Describer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Stack(
        children: [
          Center(
            child: _pickedPdf == null
                ? const Text(
                    'No PDF selected',
                    style: TextStyle(fontSize: 18),
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          path.basename(_pickedPdf!.path!),
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          if (_resultText.isNotEmpty)
            Align(
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _pickPdfFile,
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
                            'Select PDF File',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (_pickedPdf != null && _resultText.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatMorePdf(
                              pdfPath: _pickedPdf!.path!,
                              description: _resultText,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                      child: const Text(
                        'Ask More',
                        style: TextStyle(color: Colors.white, fontSize: 16),
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

// class ChatMorePdf extends StatefulWidget {
//   final String pdfPath;
//   final String description;

//   const ChatMorePdf({
//     super.key,
//     required this.pdfPath,
//     required this.description,
//   });

//   @override
//   State<ChatMorePdf> createState() => _ChatMorePdfState();
// }

// class _ChatMorePdfState extends State<ChatMorePdf> {
//   final TextEditingController _questionController = TextEditingController();
//   final List<Map<String, String>> _chatMessages = [];
//   bool _isLoading = false;

//   final FlutterTts _flutterTts = FlutterTts();

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
//       final pdfBytes = await File(widget.pdfPath).readAsBytes();
//       final base64File = base64Encode(pdfBytes);

//       final data = {
//         "contents": [
//           {
//             "parts": [
//               {"text": "Berdasarkan dokumen PDF yang diberikan, ${question}"},
//               {
//                 "inlineData": {
//                   "mimeType": "application/pdf",
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
//         body: jsonEncode(data),
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
//       setState(() {
//         _isLoading = false;
//         _questionController.clear();
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _flutterTts.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Chat About PDF',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.black,
//       ),
//       body: Column(
//         children: [
//           // Description Section
//           Expanded(
//             flex: 2,
//             child: SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'PDF Summary:',
//                       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       widget.description,
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                     const SizedBox(height: 20),
//                     Center(
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Column(
//                           children: [
//                             const Icon(
//                               Icons.picture_as_pdf,
//                               size: 48,
//                               color: Colors.red,
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               path.basename(widget.pdfPath),
//                               style: const TextStyle(fontSize: 14),
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ),
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
//                       labelText: 'Ask about the PDF',
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


class ChatMorePdf extends StatefulWidget {
  final String pdfPath;
  final String description;

  const ChatMorePdf({
    super.key,
    required this.pdfPath,
    required this.description,
  });

  @override
  State<ChatMorePdf> createState() => _ChatMorePdfState();
}

class _ChatMorePdfState extends State<ChatMorePdf> {
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
      final imageBytes = await File(widget.pdfPath).readAsBytes();
      final base64File = base64Encode(imageBytes);

      final data = {
         "contents": [
          {
            "parts": [
              {"text": "Berdasarkan dokumen PDF yang diberikan, ${question}"},
              {
                "inlineData": {
                  "mimeType": "application/pdf",
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
                         
                        label: 'ini pdf anda, ini deskripsi sebelumnya ,${widget.description}',
                        child: Center(
                          child:  const Icon(
                              Icons.picture_as_pdf,
                              size: 48,
                              color: Colors.red,
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

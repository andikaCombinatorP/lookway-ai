import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lookway/Constant/color.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ImageRecognitionPage extends StatefulWidget {
  @override
  _ImageRecognitionPageState createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends State<ImageRecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String _recognizedText = '';

 static final FlutterTts tts = FlutterTts();
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
  
  Future _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _recognizeText(_image!);
    }
  }

  Future _recognizeText(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);

    setState(() {
      _recognizedText = recognizedText.text;
    });

    if (_recognizedText.isNotEmpty) {
      await tts.speak(_recognizedText);
    }
  }




  @override
  void dispose() {
   tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Text Recognition with TTS',style: TextStyle(color: Colors.white),),
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Pick Image from Gallery'),
              ),
              const SizedBox(height: 20),
              _image == null
                  ? const Text(
                      'No image selected.',
                      style: TextStyle(fontSize: 16, color: Colors.grey))
                  : GestureDetector(
                      onTap: () {
                        // Anda dapat menambahkan fitur lain jika diperlukan saat tap
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        height: 400,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recognized Text:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recognizedText,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
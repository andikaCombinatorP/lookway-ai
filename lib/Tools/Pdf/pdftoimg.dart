import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lookway/Constant/color.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfExtract extends StatefulWidget {
  const PdfExtract({Key? key}) : super(key: key);

  @override
  State<PdfExtract> createState() => _PdfExtractState();
}

class _PdfExtractState extends State<PdfExtract> {
  static const platform = MethodChannel('pdf_converter');
  final TextRecognizer textRecognizer = TextRecognizer();
  bool isLoading = false;
  List<String> imagePaths = [];
  String rawText = '';

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text from PDF'),
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  ElevatedButton(
                      onPressed: _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:  const Text(
                              'Pilih File',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: CircularProgressIndicator(),
                ),
                   if (rawText.isNotEmpty)
              
                        ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RawTextScreen(text: rawText),
                    ),
                  ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:  const Text(
                              'Lihat Teks',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
              if (imagePaths.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: imagePaths.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<Widget>(
                        future: _processImage(imagePaths[index]),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }
                          return snapshot.data!;
                        },
                      );
                    },
                  ),
                ),
           
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result == null || result.files.single.path == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final pdfPath = result.files.single.path!;
      final outputDir = (await getTemporaryDirectory()).path;

      // Invoke native method
      final List<dynamic> dynamicImagePaths = await platform.invokeMethod(
        'convertPdfToImages',
        {'pdfPath': pdfPath, 'outputDir': outputDir},
      );

      setState(() {
        imagePaths = dynamicImagePaths.cast<String>();
      });

      debugPrint('Total images received from native: ${imagePaths.length}');

      // Extract text from each image
      String allText = '';
      for (String imagePath in imagePaths) {
        final File imageFile = File(imagePath);
        final inputImage = InputImage.fromFile(imageFile);
        final recognizedText = await textRecognizer.processImage(inputImage);
        allText += recognizedText.text + '\n';
      }

      setState(() {
        rawText = allText;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Widget> _processImage(String imagePath) async {
    final File imageFile = File(imagePath);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    return Stack(
      children: [
        Image.file(imageFile), // Menampilkan gambar asli
        ...recognizedText.blocks.map((block) {
          return Positioned(
            left: block.boundingBox.left,
            top: block.boundingBox.top,
            child: Container(
              color: Colors.yellow.withOpacity(0.5),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class RawTextScreen extends StatefulWidget {
  final String text;

  const RawTextScreen({Key? key, required this.text}) : super(key: key);

  @override
  _RawTextScreenState createState() => _RawTextScreenState();
}

class _RawTextScreenState extends State<RawTextScreen> {
  final FlutterTts tts = FlutterTts();
  bool isSpeaking = false;

    @override
  void initState() {
    super.initState();
    loadAndApplySettings();
}
    
Future<void> loadAndApplySettings() async {
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
  

  Future<void> _startTTS(String text) async {
    setState(() {
      isSpeaking = true;
    });


    tts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });

   tts.setErrorHandler((message) {
      setState(() {
        isSpeaking = false;
      });
    });

    await tts.speak(text);
  }

  Future<void> _stopTTS() async {
    await tts.stop();
    setState(() {
      isSpeaking = false;
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Raw Text')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Raw Text',
                   
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text copied to clipboard!')),
                      );
                    },
                    child: const Text('Copy Text'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.text,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: isSpeaking
                        ? null
                        : () => _startTTS(widget.text),
                    child: const Text('Play'),
                  ),
                  ElevatedButton(
                    onPressed: isSpeaking ? _stopTTS : null,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

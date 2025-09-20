import 'dart:async';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lookway/Constant/color.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TextSearchForm extends StatefulWidget {
  const TextSearchForm({super.key});

  @override
  State<TextSearchForm> createState() => _TextSearchFormState();
}

class _TextSearchFormState extends State<TextSearchForm> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    // Announce page load
    Future.delayed(const Duration(milliseconds: 500), () {
      tts.speak('Halaman pencarian teks. Masukkan teks yang ingin Anda cari.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        title: Semantics(
          label: 'Halaman Pencarian Teks',
          child: const Text(
            'Text Search',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Kolom input teks pencarian pastikan memasukkan teks tanpa spasi akhir',
              hint: 'Ketuk dua kali untuk memasukkan teks yang ingin dicari',
              textField: true,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Enter text to search',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) {
                  // Provide audio feedback for each character typed
                  // if (value.isNotEmpty) {
                  //   tts.speak('Mengetik: ${value.characters.last}');
                  // }
                },
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Tombol mulai pencarian',
              hint: 'Ketuk dua kali untuk memulai pencarian dengan kamera',
              button: true,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  String searchText = _searchController.text.trimRight(); // Only removes trailing spaces
                  
                  if (searchText.isEmpty) {
                    tts.speak('Mohon masukkan teks yang ingin dicari terlebih dahulu');
                    return;
                  }
                  tts.speak('Memulai pencarian dengan kamera');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OcrPage(
                        title: 'OCR Scanner',
                        // Pass the trimmed search text
                        searchText: searchText.toLowerCase(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Start Search',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OcrPage extends StatefulWidget {
  const OcrPage({super.key, required this.title, required this.searchText});

  final String title;
  final String searchText;

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  String text = "";
  final StreamController<String> controller = StreamController<String>();
  bool torchOn = true;
  int cameraSelection = 0;
  bool lockCamera = false;
  bool loading = false;
  bool isSearching = true;
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();
  static final FlutterTts tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isSpeaking = false;
  Timer? searchTimer;

  @override
  void initState() {
    super.initState();
    loadAndApplySettings();
    // Announce camera page load
    Future.delayed(const Duration(milliseconds: 500), () {
      tts.speak('Kamera aktif. Mencari teks: ${widget.searchText}');
    });
    // Start periodic announcements for guidance
    startSearchAnnouncements();
  }

void startSearchAnnouncements() {
  searchTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (isSearching && !isSpeaking) {
      // Use original search text case for announcements
      String originalSearchText = widget.searchText;
      tts.speak('Masih mencari teks: $originalSearchText. Gerakan kamera perlahan.');
    }
  });
}

  static Future<void> loadAndApplySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double speechRate = prefs.getDouble('speechRate') ?? 0.5;
    double pitch = prefs.getDouble('pitch') ?? 1.0;
    String? voiceName = prefs.getString('voiceName');
    String? voiceLocale = prefs.getString('voiceLocale');

    await tts.setSpeechRate(speechRate);
    await tts.setPitch(pitch);

    if (voiceName != null && voiceLocale != null) {
      await tts.setVoice({
        'name': voiceName,
        'locale': voiceLocale,
      });
    } else {
      await tts.setLanguage('id-ID');
    }
  }

void setText(String value) {
  // Convert scanned text to lowercase immediately
  String lowercaseValue = value.toLowerCase();
  
  controller.add(value); // Keep original text for display
  
  if (lowercaseValue.isEmpty) {
    if (!isSpeaking) {
      _speakText('Tidak ada teks terdeteksi. Silakan arahkan kamera ke teks.');
    }
    return;
  }

  // Since widget.searchText is already lowercase from TextSearchForm,
  // we can compare directly
  if (lowercaseValue.contains(widget.searchText)) {
    isSearching = false;
    HapticFeedback.heavyImpact();
    // For TTS, use original case of found text
    String foundText = value.substring(
      lowercaseValue.indexOf(widget.searchText),
      lowercaseValue.indexOf(widget.searchText) + widget.searchText.length
    );
    _speakText("Teks ditemukan: $foundText");
  }
  text = value;
}

  Future<void> _playSound(String sound) async {
    try {
      await _audioPlayer.play(AssetSource(sound));
    } catch (e) {
      print("Gagal memutar suara: $e");
    }
  }

  Future<void> _speakText(String text) async {
    if (isSpeaking) return;

    isSpeaking = true;
    if (text.contains("Teks ditemukan")) {
      await _playSound('images/logo/ocr.mp3');
    }

    text = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s,.!?]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = _formatText(text);

    await tts.stop();
    await tts.speak(text);

    await Future.any([
      tts.awaitSpeakCompletion(true),
      Future.delayed(const Duration(seconds: 10)),
    ]);

    isSpeaking = false;
  }

  String _formatText(String text) {
    text = text.isNotEmpty ? text[0].toUpperCase() + text.substring(1) : text;
    if (!RegExp(r'[.!?]$').hasMatch(text)) {
      text += '.';
    }
    return text;
  }

  @override
  void dispose() {
    controller.close();
    tts.stop();
    searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        title: Semantics(
          label: 'Mencari teks: ${widget.searchText}',
          child: Text(
            'Mencari: ${widget.searchText}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
              ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor:AppColors.primaryColor,),
              onPressed: (){ if (text.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedTextPage(savedText: text),
              ),
            );
          }},
                 
                  child:     
                      const Text(
                              'Tangkap',
                              style: TextStyle(color: Colors.white),
                            ), 
                    ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child:
                Semantics(
                     excludeSemantics: true,
                        child: ScalableOCR(
                            key: cameraKey,
                            torchOn: torchOn,
                            cameraSelection: cameraSelection,
                            lockCamera: lockCamera,
                            paintboxCustom: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4.0
                              ..color = Colors.blue.withOpacity(0.6),
                            boxLeftOff: 20,
                            boxBottomOff: 20,
                            boxRightOff: 20,
                            boxTopOff: 20,
                            boxHeight: 300,
                            getRawData: (value) => inspect(value),
                            getScannedText: setText,
                          ),
                      )
                 
              
          
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Scanned Text',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: StreamBuilder<String>(
                        stream: controller.stream,
                        builder: (context, snapshot) {
                          return SingleChildScrollView(
                            child: Text(
                              snapshot.data ?? 'No text scanned yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: snapshot.data?.isEmpty ?? true
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        
        onPressed: () {
          if (text.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedTextPage(savedText: text),
              ),
            );
          }
        },
    
        label: const Text('Tangkap',style: TextStyle(fontSize: 40,color: Colors.white),),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }
}

class Result extends StatelessWidget {
  const Result({
    Key? key,
    required this.text,
  }) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text("Readed text: $text");
  }
}

class SavedTextPage extends StatelessWidget {
  final String savedText;

  const SavedTextPage({Key? key, required this.savedText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Text'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            savedText,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lookway/Constant/color.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashReader extends StatefulWidget {
  const CashReader({super.key, required this.title});
  final String title;

  @override
  State<CashReader> createState() => _CashReaderState();
}

class _CashReaderState extends State<CashReader> {
  final StreamController<String> controller = StreamController<String>();
  bool torchOn = true;
  int cameraSelection = 0;
  bool lockCamera = false;
  bool loading = false;
  String lastDetectedValue = '';
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();
 static final FlutterTts tts = FlutterTts(); // Inisialisasi TTS
final AudioPlayer _audioPlayer = AudioPlayer(); 

  @override
  void initState() {
    super.initState();
loadAndApplySettings();
  }
  
Future<void> _playSound(String sound) async {
  try {
    await _audioPlayer.play(AssetSource(sound)); // Memainkan suara dari assets
  } catch (e) {
    print("Gagal memutar suara: $e");
  }
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
  
  Future<void> _speakText(String text) async {
  

    if (text.isNotEmpty) {
      await tts.stop();
            await _playSound('images/logo/ocr.mp3'); 
      await tts.speak('${text}');
       return; 
    }
  }

  Future<void> _processDetectedText(String detectedText) async {
    final supportedValues = {
      '1000': 'seribu rupiah',
      '2000': 'dua ribu rupiah',
      '5000': 'lima ribu rupiah',
      '10000': 'sepuluh ribu rupiah',
      '20000': 'dua puluh ribu rupiah',
      '50000': 'lima puluh ribu rupiah',
      '100000': 'seratus ribu rupiah',
    };

    final regex = RegExp(r'\b(1000|2000|5000|10000|20000|50000|100000)\b');
    final matches = regex.allMatches(detectedText);

  bool isMatched = false; // Tambahkan flag untuk mengecek apakah ada kecocokan

  for (var match in matches) {
    final matchedText = match.group(0);
    if (matchedText != null && supportedValues.containsKey(matchedText)) {
      setState(() {
        lastDetectedValue = matchedText;
      });

      await _speakText(supportedValues[matchedText]!);
      isMatched = true; // Setel flag jika ada kecocokan
      break;
    }
  }
// 🔴 Jika tidak ada angka yang cocok, putar suara error
if (!isMatched) {
  // Delay 5 detik sebelum memutar suara error dan berbicara dengan TTS


  // Menjalankan dua aksi secara bersamaan

    _playSound('images/logo/eror.mp3');


}
  }
  @override
  void dispose() {
    controller.close();
tts.stop();
    super.dispose();
  }

  Color _getColorForAmount(String amount) {
    switch (amount) {
      case '1000':
        return Colors.grey;
      case '2000':
        return Colors.grey;
      case '5000':
        return Colors.brown;
      case '10000':
        return Colors.purple;
      case '20000':
        return Colors.green;
      case '50000':
        return Colors.blue;
      case '100000':
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryColor,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
       
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getColorForAmount(lastDetectedValue),
                    width: 3,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
   
                  
                    child: !loading
                        ? Semantics(
                          excludeSemantics: true,
                          label: 'arahkan ke uang anda',
                       
                          child: ScalableOCR(
                              key: cameraKey,
                              torchOn: torchOn,
                              cameraSelection: cameraSelection,
                              lockCamera: lockCamera,
                              paintboxCustom: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 4.0
                                ..color = _getColorForAmount(lastDetectedValue),
                              boxLeftOff: 20,
                              boxBottomOff: 20,
                              boxRightOff: 20,
                              boxTopOff: 20,
                              boxHeight: MediaQuery.of(context).size.height * 0.4,
                              getRawData: (value) => inspect(value),
                            
                              getScannedText: _processDetectedText,
                            ),
                        )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
          
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Terdeteksi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _getColorForAmount(lastDetectedValue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _getColorForAmount(lastDetectedValue),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      lastDetectedValue.isEmpty
                          ? 'Arahkan kamera ke uang kertas'
                          : 'Rp ${lastDetectedValue}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getColorForAmount(lastDetectedValue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ketuk layar untuk memindai ulang',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
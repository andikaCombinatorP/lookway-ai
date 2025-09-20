import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lookway/Constant/color.dart';
import 'package:lookway/coloredboxes.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CompassPage extends StatefulWidget {
  @override
  _CompassPageState createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  double _currentHeading = 0.0;
  double _lastSpokenHeading = -1.0;
 static final FlutterTts tts = FlutterTts();
  String _currentDirectionText = '';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
   loadAndApplySettings();
    
    FlutterCompass.events?.listen((event) {
      if (!_isActive) return;

      if (event.heading != null) {
        // Normalisasi heading
        double heading = (event.heading! + 360) % 360;
        String directionText = _getDirectionText(heading);

        if (_shouldSpeakDirection(heading)) {
          _speakDirection(directionText);
          _lastSpokenHeading = heading;
        }

        setState(() {
          _currentHeading = heading;
          _currentDirectionText = directionText;
        });


      }
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
  

  /// Menghitung apakah perlu berbicara arah baru
  bool _shouldSpeakDirection(double heading) {
    const double angleThreshold = 15.0;
    if (_lastSpokenHeading == -1.0) return true;
    double difference = _angleDifference(heading, _lastSpokenHeading);
    return difference >= angleThreshold;
  }

  /// Menghitung perbedaan sudut dengan penanganan wrap-around
  double _angleDifference(double angle1, double angle2) {
    double difference = (angle1 - angle2).abs();
    return difference > 180 ? 360 - difference : difference;
  }

  /// Mendapatkan teks arah dari heading
  String _getDirectionText(double heading) {
    if (heading >= 345.0 || heading < 15.0) {
      return "Utara";
    } else if (heading >= 15.0 && heading < 75.0) {
      return "Timur Laut";
    } else if (heading >= 75.0 && heading < 105.0) {
      return "Timur";
    } else if (heading >= 105.0 && heading < 165.0) {
      return "Tenggara";
    } else if (heading >= 165.0 && heading < 195.0) {
      return "Selatan";
    } else if (heading >= 195.0 && heading < 255.0) {
      return "Barat Daya";
    } else if (heading >= 255.0 && heading < 285.0) {
      return "Barat";
    } else { // 285.0 <= heading < 345.0
      return "Barat Laut";
    }
  }

  /// Mengucapkan arah menggunakan TTS
  Future<void> _speakDirection(String direction) async {

    await tts.speak("$direction.");
  }

  /// Membuka Google Maps
  Future<void> _openMaps() async {
    final url = 'https://www.google.com/maps';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Tidak dapat membuka Google Maps';
    }
  }

  @override
  Future<void> dispose() async {
    _isActive = false;
    tts.stop();
   
    super.dispose();
            
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kompas Real-time'),
        actions: [ColoredBoxes()],
      ),
      body: Container(

        child: Column(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Arah Anda:',
                    style: TextStyle(fontSize: 24),
                  ),
                  Text(
                    _currentDirectionText,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Transform.rotate(
                    angle: (_currentHeading * (3.14159265359 / 180) * -1),
                    child: Icon(
                      Icons.navigation,
                      size: 100,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _openMaps,
                    child: Text('Buka Google Maps'),
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

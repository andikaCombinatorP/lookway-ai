import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lookway/Tools/Kompass/kompaspage.dart';
import 'package:lookway/Tools/Test/models.dart';
import 'package:lookway/Tools/Test/test3.dart';
import 'package:lookway/Tools/Test/testfeature2.dart';
import 'package:lookway/Tools/timer.dart';
import 'package:speech_to_text/speech_to_text.dart'as stt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const platform = MethodChannel('com.example.lookway/shortcuts');
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Tangani navigasi dari shortcut
    platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        String route = call.arguments as String;
        // Navigasi langsung ke halaman tujuan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            route,
            (Route<dynamic> route) => false, // Hapus semua halaman sebelumnya
          );
        });
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => UniversalShareHandler(),
        '/menu': (context) => MenuPage(),
        '/menu_image': (context) => MenuImagePage(),
        '/video_desc': (context) => VideoChat(),
        '/pdf_desc': (context) => PdfDescriber(),
        '/image_camera': (context) => ImageCameraPage(),
        '/video_camera': (context) => VideoCameraPage(),
        '/compass': (context) => CompassPage(),
        '/text_finder': (context) => TextFinderPage(),
        '/realtime_ocr': (context) => RealtimeOcrPage(),
        '/image_ocr': (context) => ImageOcrPage(),
        '/camera_ocr': (context) => CameraOcrPage(),
        '/video_capture': (context) => VideoCapturePage(),
        '/reading_book': (context) => ReadingBookPage(),
        '/camera_zoom': (context) => CameraZoomPage(),

                '/timer_tts': (context) =>TimerScreen(),
      },
    );
  }
}


class MenuPage extends StatefulWidget {
  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final List<Map<String, dynamic>> menuItems = [
    {'title': 'Image Describer', 'desc': 'View menu images', 'route': '/menu_image'},
    {'title': 'Video Describer', 'desc': 'Video description', 'route': '/video_desc'},
    {'title': 'Audio Reader', 'desc': 'PDF description', 'route': '/pdf_desc'},
    {'title': 'Instant Text Reader', 'desc': 'Capture images', 'route': '/image_camera'},
    {'title': 'Cash Reader', 'desc': 'Record videos', 'route': '/video_camera'},
    {'title': 'Video Call Ai', 'desc': 'Navigation tool', 'route': '/compass'},
    {'title': 'Text Finder', 'desc': 'Find text', 'route': '/text_finder'},
    {'title': 'Image Reader', 'desc': 'Live text recognition', 'route': '/realtime_ocr'},
    {'title': 'Reading Book', 'desc': 'OCR for images', 'route': '/image_ocr'},
    {'title': 'Pdf Descripion', 'desc': 'Camera text OCR', 'route': '/camera_ocr'},
    {'title': 'Video Capture Ai', 'desc': 'Capture videos', 'route': '/video_capture'},
    {'title': 'Document Reader', 'desc': 'Book reader', 'route': '/reading_book'},
    {'title': 'Ai Chat Assistance', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
     {'title': 'Nearby Description', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
      {'title': 'Object Finder Guide', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
       {'title': 'Social Media Caption generator', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
              {'title': 'Color Exploler', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                         {'title': 'Translator', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                             {'title': 'My location', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                                {'title': 'Compass', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                                   {'title': 'Walk Step Counter', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                                      {'title': 'saver and launcher', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                                            {'title': 'Diary management', 'desc': 'Zoom camera', 'route': '/camera_zoom'},
                    {'title': 'timer tts', 'desc': 'Timer With TTS', 'route': '/timer_tts'},
  ];

  List<Map<String, dynamic>> filteredItems = [];
  static const platform = MethodChannel('com.example.lookway/shortcuts');
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    filteredItems = menuItems;
    _searchController.addListener(_filterMenuItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMenuItems() {
    String query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredItems = menuItems;
        return;
      }

      // Pisahkan query menjadi kata-kata
      List<String> queryWords = query.split(' ').where((word) => word.isNotEmpty).toList();

      // List untuk menyimpan item beserta skornya
      List<Map<String, dynamic>> scoredItems = [];

      for (var item in menuItems) {
        String title = item['title'].toLowerCase();
        String desc = item['desc'].toLowerCase();
        int score = 0;

        // Hitung skor berdasarkan kecocokan kata di title dan desc
        for (String word in queryWords) {
          if (title.contains(word)) {
            score += 2; // Beri bobot lebih tinggi untuk kecocokan di title
          }
          if (desc.contains(word)) {
            score += 1; // Bobot lebih rendah untuk kecocokan di desc
          }
        }

        // Hanya masukkan item yang memiliki skor (ada kecocokan)
        if (score > 0) {
          scoredItems.add({
            'item': item,
            'score': score,
          });
        }
      }

      // Urutkan berdasarkan skor (descending) dan ambil item aslinya
      scoredItems.sort((a, b) => b['score'].compareTo(a['score']));
      filteredItems = scoredItems.map((scoredItem) => scoredItem['item'] as Map<String, dynamic>).toList();
    });
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _searchController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  Future<void> _addShortcutToHomeScreen(
      BuildContext context, String title, String route) async {
    try {
      await platform.invokeMethod('addShortcut', {
        'title': title,
        'route': route,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shortcut untuk $title ditambahkan ke beranda!')),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan shortcut: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Menu...',
                  prefixIcon: Icon(Icons.search, color: Colors.white),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            _filterMenuItems();
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                        onPressed: _isListening ? _stopListening : _startListening,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, filteredItems[index]['route']);
                    },
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return Container(
                            color: Colors.grey[900],
                            child: Wrap(
                              children: <Widget>[
                                ListTile(
                                  leading: Icon(Icons.add_to_home_screen, color: Colors.white),
                                  title: Text(
                                    'Tambahkan ke layar beranda',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _addShortcutToHomeScreen(
                                      context,
                                      filteredItems[index]['title'],
                                      filteredItems[index]['route'],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              filteredItems[index]['title'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              filteredItems[index]['desc'],
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Halaman-halaman sederhana untuk setiap menu
class MenuImagePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Menu Image'), backgroundColor: Colors.black),
      body: Center(child: Text('Menu Image Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class VideoDescPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Description'), backgroundColor: Colors.black),
      body: Center(child: Text('Video Description Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class PdfDescPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Description'), backgroundColor: Colors.black),
      body: Center(child: Text('PDF Description Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class ImageCameraPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Camera'), backgroundColor: Colors.black),
      body: Center(child: Text('Image Camera Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class VideoCameraPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Camera'), backgroundColor: Colors.black),
      body: Center(child: Text('Video Camera Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}


class TextFinderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Text Finder'), backgroundColor: Colors.black),
      body: Center(child: Text('Text Finder Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class RealtimeOcrPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Realtime OCR'), backgroundColor: Colors.black),
      body: Center(child: Text('Realtime OCR Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class ImageOcrPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image OCR'), backgroundColor: Colors.black),
      body: Center(child: Text('Image OCR Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class CameraOcrPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera OCR'), backgroundColor: Colors.black),
      body: Center(child: Text('Camera OCR Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class VideoCapturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Capture'), backgroundColor: Colors.black),
      body: Center(child: Text('Video Capture Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class ReadingBookPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reading Book'), backgroundColor: Colors.black),
      body: Center(child: Text('Reading Book Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}

class CameraZoomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Zoom'), backgroundColor: Colors.black),
      body: Center(child: Text('Camera Zoom Page', style: TextStyle(color: Colors.white))),
      backgroundColor: Colors.black,
    );
  }
}
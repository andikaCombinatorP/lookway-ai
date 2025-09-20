import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const BlindAssistApp());
}

class BlindAssistApp extends StatelessWidget {
  const BlindAssistApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blind Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
          background: Colors.black,
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.all(20),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 18, color: Colors.white),
          titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts flutterTts = FlutterTts();
  bool isTtsEnabled = true;
  bool isVibrationEnabled = true;
  double speechRate = 0.5;
  double speechPitch = 1.0;
  String selectedVoice = "en-US";

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadSettings();

    // Read welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak("Welcome to the Blind Assistant app. Swipe right to save a link. Swipe left to access saved links. Double tap for settings.");
    });
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage(selectedVoice);
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setPitch(speechPitch);
    await flutterTts.setVolume(1.0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isTtsEnabled = prefs.getBool('isTtsEnabled') ?? true;
      isVibrationEnabled = prefs.getBool('isVibrationEnabled') ?? true;
      speechRate = prefs.getDouble('speechRate') ?? 0.5;
      speechPitch = prefs.getDouble('speechPitch') ?? 1.0;
      selectedVoice = prefs.getString('selectedVoice') ?? "en-US";
    });
    await _initializeTts();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTtsEnabled', isTtsEnabled);
    await prefs.setBool('isVibrationEnabled', isVibrationEnabled);
    await prefs.setDouble('speechRate', speechRate);
    await prefs.setDouble('speechPitch', speechPitch);
    await prefs.setString('selectedVoice', selectedVoice);
  }

  Future<void> _speak(String text) async {
    if (isTtsEnabled) {
      await flutterTts.speak(text);
    }
  }

  void _vibrate() {
    if (isVibrationEnabled && Vibration.hasVibrator() != null) {
      Vibration.vibrate(duration: 200);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind Assistant'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right - Save Link
          if (details.primaryVelocity! > 0) {
            _vibrate();
            _speak("Adding a new link");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SaveLinkPage(
                  onSpeak: _speak,
                  onVibrate: _vibrate,
                ),
              ),
            );
          }
          // Swipe left - Access Links
          else if (details.primaryVelocity! < 0) {
            _vibrate();
            _speak("Opening saved links list");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LinkListPage(
                  onSpeak: _speak,
                  onVibrate: _vibrate,
                ),
              ),
            );
          }
        },
        onDoubleTap: () {
          _vibrate();
          _speak("Opening settings");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(
                isTtsEnabled: isTtsEnabled,
                isVibrationEnabled: isVibrationEnabled,
                speechRate: speechRate,
                speechPitch: speechPitch,
                selectedVoice: selectedVoice,
                onSave: (tts, vibration, rate, pitch, voice) {
                  setState(() {
                    isTtsEnabled = tts;
                    isVibrationEnabled = vibration;
                    speechRate = rate;
                    speechPitch = pitch;
                    selectedVoice = voice;
                  });
                  _initializeTts();
                  _saveSettings();
                },
                onSpeak: _speak,
                onVibrate: _vibrate,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 120,
                  width: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: 120,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.accessibility_new,
                        size: 80,
                        color: Colors.black,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'Blind Assistant',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      _buildInstructionCard(
                        context,
                        'Swipe Right',
                        'To add a new link',
                        Icons.add_link,
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionCard(
                        context,
                        'Swipe Left',
                        'To access saved links',
                        Icons.list,
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionCard(
                        context,
                        'Double Tap',
                        'To open settings',
                        Icons.settings,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        _vibrate();
        _speak("$title. $description");
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.amber,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
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

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
}

class SaveLinkPage extends StatefulWidget {
  final Function(String) onSpeak;
  final Function() onVibrate;

  const SaveLinkPage({
    Key? key,
    required this.onSpeak,
    required this.onVibrate,
  }) : super(key: key);

  @override
  _SaveLinkPageState createState() => _SaveLinkPageState();
}

class _SaveLinkPageState extends State<SaveLinkPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _urlFocus = FocusNode();
  String _errorMessage = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Focus listener for reading text field labels
    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus) {
        widget.onSpeak("Enter link title");
        widget.onVibrate();
      }
    });

    _urlFocus.addListener(() {
      if (_urlFocus.hasFocus) {
        widget.onSpeak("Enter link URL");
        widget.onVibrate();
      }
    });

    // Read instructions when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSpeak("Add link page. Fill in the title and URL, then save.");
    });
  }

  Future<void> _saveLink() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    String title = _titleController.text.trim();
    String url = _urlController.text.trim();

    // Validate input
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Title cannot be empty';
        _isProcessing = false;
      });
      widget.onSpeak(_errorMessage);
      widget.onVibrate();
      return;
    }

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'URL cannot be empty';
        _isProcessing = false;
      });
      widget.onSpeak(_errorMessage);
      widget.onVibrate();
      return;
    }

    // Add http:// if not present
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Retrieve existing links
      List<String> savedTitles = prefs.getStringList('savedTitles') ?? [];
      List<String> savedUrls = prefs.getStringList('savedUrls') ?? [];

      // Add new link
      savedTitles.add(title);
      savedUrls.add(url);

      // Save updated lists
      await prefs.setStringList('savedTitles', savedTitles);
      await prefs.setStringList('savedUrls', savedUrls);

      widget.onSpeak("Link successfully saved");
      widget.onVibrate();

      // Return to home page
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save link: $e';
        _isProcessing = false;
      });
      widget.onSpeak(_errorMessage);
      widget.onVibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Link'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          },
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 0) {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Link',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _titleController,
                focusNode: _titleFocus,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Link Title',
                  labelStyle: const TextStyle(color: Colors.amber, fontSize: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: const Icon(Icons.title, color: Colors.amber),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && _errorMessage.contains('Title')) {
                    setState(() {
                      _errorMessage = '';
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _urlController,
                focusNode: _urlFocus,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Link URL',
                  labelStyle: const TextStyle(color: Colors.amber, fontSize: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  prefixIcon: const Icon(Icons.link, color: Colors.amber),
                  hintText: 'https://example.com',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && _errorMessage.contains('URL')) {
                    setState(() {
                      _errorMessage = '';
                    });
                  }
                },
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isProcessing ? null : _saveLink,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.amber.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'SAVE LINK',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  widget.onSpeak("Help for using the add link page");
                  widget.onVibrate();
                  _showHelpDialog();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'HELP',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Help',
            style: TextStyle(color: Colors.amber),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const [
                Text(
                  '1. Enter the link title in the first field',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '2. Enter the link URL in the second field',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Press the SAVE LINK button to save',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Swipe right to return to the home page',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSpeak("Closing help");
                widget.onVibrate();
                Navigator.of(context).pop();
              },
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.amber, fontSize: 18),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      widget.onSpeak("Back to add link page");
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _titleFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }
}

class LinkListPage extends StatefulWidget {
  final Function(String) onSpeak;
  final Function() onVibrate;

  const LinkListPage({
    Key? key,
    required this.onSpeak,
    required this.onVibrate,
  }) : super(key: key);

  @override
  _LinkListPageState createState() => _LinkListPageState();
}

class _LinkListPageState extends State<LinkListPage> {
  List<String> _titles = [];
  List<String> _urls = [];
  bool _isLoading = true;
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLinks();

    // Read instructions when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSpeak("Saved links list page. Tap an item to read details. Double tap to open the link.");
    });
  }

  Future<void> _loadLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _titles = prefs.getStringList('savedTitles') ?? [];
        _urls = prefs.getStringList('savedUrls') ?? [];
        _isLoading = false;
      });

      if (_titles.isEmpty) {
        widget.onSpeak("No saved links yet");
      } else {
        widget.onSpeak("${_titles.length} saved links found");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      widget.onSpeak("Failed to load links list");
    }
  }

  Future<void> _deleteLink(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        String deletedTitle = _titles[index];
        _titles.removeAt(index);
        _urls.removeAt(index);
        widget.onSpeak("Deleting link $deletedTitle");
      });

      await prefs.setStringList('savedTitles', _titles);
      await prefs.setStringList('savedUrls', _urls);

      widget.onVibrate();
    } catch (e) {
      widget.onSpeak("Failed to delete link");
    }
  }

  Future<void> _launchURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        widget.onSpeak("Cannot open link");
        widget.onVibrate();
      }
    } catch (e) {
      widget.onSpeak("Failed to open link: ${e.toString()}");
      widget.onVibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Links'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              widget.onSpeak("Help for usage");
              widget.onVibrate();
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 0) {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          }
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : _titles.isEmpty
                ? _buildEmptyState()
                : _buildLinkList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          Text(
            'No Saved Links',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Swipe right to return and add a new link',
            style: TextStyle(fontSize: 18, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              widget.onSpeak("Return to home page");
              widget.onVibrate();
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                'RETURN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _titles.length,
      itemBuilder: (context, index) {
        bool isFocused = _focusedIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            elevation: isFocused ? 12 : 4,
            color: isFocused ? Colors.amber.withOpacity(0.2) : const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isFocused
                  ? const BorderSide(color: Colors.amber, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _focusedIndex = index;
                });
                widget.onSpeak("${_titles[index]}. ${_urls[index]}. Double tap to open this link.");
                widget.onVibrate();
              },
              onDoubleTap: () {
                widget.onSpeak("Opening link ${_titles[index]}");
                widget.onVibrate();
                _launchURL(_urls[index]);
              },
              onLongPress: () {
                widget.onSpeak("Deleting link ${_titles[index]}");
                widget.onVibrate();
                _showDeleteConfirmation(index);
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.link,
                          color: Colors.amber,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _titles[index],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isFocused ? Colors.amber : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 44.0),
                      child: Text(
                        _urls[index],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Help',
            style: TextStyle(color: Colors.amber),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const [
                Text(
                  '1. Tap a link to read its details',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '2. Double tap to open the link',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Long press to delete a link',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Swipe right to return to the home page',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSpeak("Closing help");
                widget.onVibrate();
                Navigator.of(context).pop();
              },
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.amber, fontSize: 18),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      widget.onSpeak("Back to saved links page");
    });
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Delete Link',
            style: TextStyle(color: Colors.amber),
          ),
          content: Text(
            'Are you sure you want to delete "${_titles[index]}"?',
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSpeak("Cancel deletion");
                widget.onVibrate();
                Navigator.of(context).pop();
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.amber, fontSize: 18),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.onSpeak("Deleting link");
                widget.onVibrate();
                _deleteLink(index);
                Navigator.of(context).pop();
              },
              child: const Text(
                'DELETE',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }
}


class SettingsPage extends StatefulWidget {
  final bool isTtsEnabled;
  final bool isVibrationEnabled;
  final double speechRate;
  final double speechPitch;
  final String selectedVoice;
  final Function(bool, bool, double, double, String) onSave;
  final Function(String) onSpeak;
  final Function() onVibrate;

  const SettingsPage({
    Key? key,
    required this.isTtsEnabled,
    required this.isVibrationEnabled,
    required this.speechRate,
    required this.speechPitch,
    required this.selectedVoice,
    required this.onSave,
    required this.onSpeak,
    required this.onVibrate,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isTtsEnabled;
  late bool _isVibrationEnabled;
  late double _speechRate;
  late double _speechPitch;
  late String _selectedVoice;
  final List<String> _voiceOptions = ['en-US', 'en-GB', 'en-AU'];

  @override
  void initState() {
    super.initState();
    _isTtsEnabled = widget.isTtsEnabled;
    _isVibrationEnabled = widget.isVibrationEnabled;
    _speechRate = widget.speechRate;
    _speechPitch = widget.speechPitch;
    _selectedVoice = widget.selectedVoice;

    // Read instructions when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSpeak("Settings page. Configure text-to-speech and vibration settings. Press Save to apply changes.");
    });
  }

  void _saveSettings() {
    widget.onSave(
      _isTtsEnabled,
      _isVibrationEnabled,
      _speechRate,
      _speechPitch,
      _selectedVoice,
    );
    widget.onSpeak("Settings saved");
    widget.onVibrate();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          },
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to go back
          if (details.primaryVelocity! > 0) {
            widget.onSpeak("Return to home page");
            widget.onVibrate();
            Navigator.pop(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SwitchListTile(
                  title: const Text(
                    'Enable Text-to-Speech',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  value: _isTtsEnabled,
                  activeColor: Colors.amber,
                  onChanged: (value) {
                    setState(() {
                      _isTtsEnabled = value;
                    });
                    widget.onSpeak(value ? "Text-to-speech enabled" : "Text-to-speech disabled");
                    widget.onVibrate();
                  },
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      widget.onSpeak("Toggle text-to-speech");
                      widget.onVibrate();
                    }
                  },
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text(
                    'Enable Vibration',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  value: _isVibrationEnabled,
                  activeColor: Colors.amber,
                  onChanged: (value) {
                    setState(() {
                      _isVibrationEnabled = value;
                    });
                    widget.onSpeak(value ? "Vibration enabled" : "Vibration disabled");
                    widget.onVibrate();
                  },
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      widget.onSpeak("Toggle vibration");
                      widget.onVibrate();
                    }
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Speech Rate: ${_speechRate.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
                Slider(
                  value: _speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey,
                  onChanged: (value) {
                    setState(() {
                      _speechRate = value;
                    });
                    widget.onSpeak("Speech rate set to ${value.toStringAsFixed(2)}");
                    widget.onVibrate();
                  },
                  onChangeStart: (_) {
                    widget.onSpeak("Adjust speech rate");
                    widget.onVibrate();
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Speech Pitch: ${_speechPitch.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
                Slider(
                  value: _speechPitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey,
                  onChanged: (value) {
                    setState(() {
                      _speechPitch = value;
                    });
                    widget.onSpeak("Speech pitch set to ${value.toStringAsFixed(2)}");
                    widget.onVibrate();
                  },
                  onChangeStart: (_) {
                    widget.onSpeak("Adjust speech pitch");
                    widget.onVibrate();
                  },
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedVoice,
                  decoration: InputDecoration(
                    labelText: 'Voice',
                    labelStyle: const TextStyle(color: Colors.amber, fontSize: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.amber, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  dropdownColor: const Color(0xFF1E1E1E),
                  items: _voiceOptions.map((voice) {
                    return DropdownMenuItem(
                      value: voice,
                      child: Text(
                        voice,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVoice = value!;
                    });
                    widget.onSpeak("Voice set to $value");
                    widget.onVibrate();
                  },
                  onTap: () {
                    widget.onSpeak("Select voice");
                    widget.onVibrate();
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SAVE SETTINGS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    widget.onSpeak("Help for using the settings page");
                    widget.onVibrate();
                    _showHelpDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'HELP',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Help',
            style: TextStyle(color: Colors.amber),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const [
                Text(
                  '1. Toggle text-to-speech to enable or disable voice feedback',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '2. Toggle vibration to enable or disable haptic feedback',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Adjust speech rate and pitch using sliders',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Select a voice from the dropdown menu',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '5. Press SAVE SETTINGS to apply changes',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 12),
                Text(
                  '6. Swipe right to return to the home page',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.onSpeak("Closing help");
                widget.onVibrate();
                Navigator.of(context).pop();
              },
              child: const Text(
                'CLOSE',
                style: TextStyle(color: Colors.amber, fontSize: 18),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      widget.onSpeak("Back to settings page");
    });
  }
}
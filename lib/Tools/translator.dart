import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accessible Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.tealAccent,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 18, color: Colors.white),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(fontSize: 20),
            minimumSize: const Size(double.infinity, 60),
          ),
        ),
      ),
      home: const AccessibleTranslator(),
    );
  }
}

class AccessibleTranslator extends StatefulWidget {
  const AccessibleTranslator({Key? key}) : super(key: key);

  @override
  _AccessibleTranslatorState createState() => _AccessibleTranslatorState();
}

class _AccessibleTranslatorState extends State<AccessibleTranslator> with WidgetsBindingObserver {
  // Text controllers
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  // TTS and STT
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  // Translator
  final GoogleTranslator _translator = GoogleTranslator();

  // Language selection
  String _sourceLanguage = 'en';
  String _targetLanguage = 'es'; // Changed default target to Spanish for variety

  // State variables
  bool _isListening = false;
  bool _isTranslating = false;
  bool _isSpeaking = false;
  double _fontSize = 20.0;
  double _speechRate = 0.5;

  // Accessibility settings
  bool _useHighContrast = true;
  bool _useVibrationFeedback = true;
  int _autoDetectTimeout = 2; // seconds
  bool _autoSpeak = true;

  // Language maps
  final Map<String, String> _languageMap = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
    'zh-cn': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTTS();
    _initializeSTT();
    _loadSettings();

    // Announce screen for accessibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        _speak("Accessible Translator opened. Double tap anywhere to get help.");
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flutterTts.stop();
    }
  }

  // Initialize Text-to-Speech
  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage(_targetLanguage);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // Initialize Speech-to-Text
  Future<void> _initializeSTT() async {
    await _speechToText.initialize();
  }

  // Load user settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 20.0;
      _speechRate = prefs.getDouble('speechRate') ?? 0.5;
      _sourceLanguage = prefs.getString('sourceLanguage') ?? 'en';
      _targetLanguage = prefs.getString('targetLanguage') ?? 'es';
      _useHighContrast = prefs.getBool('useHighContrast') ?? true;
      _useVibrationFeedback = prefs.getBool('useVibrationFeedback') ?? true;
      _autoDetectTimeout = prefs.getInt('autoDetectTimeout') ?? 2;
      _autoSpeak = prefs.getBool('autoSpeak') ?? true;
    });

    await _flutterTts.setLanguage(_targetLanguage);
    await _flutterTts.setSpeechRate(_speechRate);
  }

  // Save user settings
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setDouble('speechRate', _speechRate);
    await prefs.setString('sourceLanguage', _sourceLanguage);
    await prefs.setString('targetLanguage', _targetLanguage);
    await prefs.setBool('useHighContrast', _useHighContrast);
    await prefs.setBool('useVibrationFeedback', _useVibrationFeedback);
    await prefs.setInt('autoDetectTimeout', _autoDetectTimeout);
    await prefs.setBool('autoSpeak', _autoSpeak);
  }

  // Start listening for speech input
  void _startListening() async {
    if (_useVibrationFeedback && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 100);
    }

    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == "done") {
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
        });

        _speak("Listening. Please speak now.");

        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _sourceController.text = result.recognizedWords;
            });

            // Auto translate after a short delay
            if (result.finalResult) {
              _translate();
            }
          },
          localeId: _sourceLanguage,
        );
      } else {
        _speak("Speech recognition not available on this device.");
      }
    }
  }

  // Stop listening for speech input
  Future<void> _stopListening() async {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    if (_useVibrationFeedback && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 100);
    }

    _speak("Stopped listening.");
  }

  // Translate text
  Future<void> _translate() async {
    if (_sourceController.text.isEmpty) {
      _speak("No text to translate. Please enter or speak some text first.");
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      // Provide haptic feedback
      if (_useVibrationFeedback && (await Vibration.hasVibrator() ?? false)) {
        Vibration.vibrate(duration: 150);
      }

      final translation = await _translator.translate(
        _sourceController.text,
        from: _sourceLanguage,
        to: _targetLanguage,
      );

      setState(() {
        _targetController.text = translation.text;
        _isTranslating = false;
      });

      // Auto speak the result if enabled
      if (_autoSpeak) {
        _speakTranslation();
      } else {
        _speak("Translation complete. Double tap to hear the translation.");
      }
    } catch (e) {
      setState(() {
        _isTranslating = false;
        _targetController.text = "Error: Could not translate text. Please check your internet connection and try again.";
      });

      _speak("Translation failed. Please check your internet connection and try again.");
    }
  }

  // Speak text using TTS
  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    }

    if (text.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
      });

      await _flutterTts.setLanguage(_targetLanguage);
      await _flutterTts.speak(text);
    }
  }

  // Speak the translation
  void _speakTranslation() async {
    if (_targetController.text.isEmpty) {
      _speak("No translation available.");
      return;
    }

    await _flutterTts.setLanguage(_targetLanguage);
    _speak(_targetController.text);
  }

  // Speak the source text
  void _speakSource() async {
    if (_sourceController.text.isEmpty) {
      _speak("No source text available.");
      return;
    }

    await _flutterTts.setLanguage(_sourceLanguage);
    _speak(_sourceController.text);
  }

  // Copy text to clipboard
  void _copyToClipboard(String text) async {
    if (text.isEmpty) {
      _speak("No text to copy.");
      return;
    }


    if (_useVibrationFeedback && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 200);
    }

    _speak("Text copied to clipboard.");
  }


  // Clear text fields
  Future<void> _clearText() async {
    setState(() {
      _sourceController.clear();
      _targetController.clear();
    });

    if (_useVibrationFeedback && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 150);
    }

    _speak("Text cleared.");
  }

  // Show help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accessibility Help", style: TextStyle(fontSize: 24)),
        backgroundColor: Colors.black,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem("Double tap on input field to activate voice input"),
              _buildHelpItem("Double tap on output field to hear translation"),
              _buildHelpItem("Swipe left/right with two fingers to switch languages"),
              _buildHelpItem("Three finger tap to copy translation"),
              _buildHelpItem("Three finger double tap to paste from clipboard"),
              _buildHelpItem("Shake device to clear all text"),
              _buildHelpItem("Use the buttons at the bottom for additional actions"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _speak("Help dialog closed.");
            },
            child: const Text("Close", style: TextStyle(fontSize: 20, color: Colors.tealAccent)),
          ),
        ],
      ),
    );

    // Speak the help content
    _speak("Help dialog opened. Double tap on input field to activate voice input. Double tap on output field to hear translation. Swipe left or right with two fingers to switch languages. Three finger tap to copy translation. Three finger double tap to paste from clipboard. Shake device to clear all text. Use the buttons at the bottom for additional actions.");
  }

  // Build help item
  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.brightness_1, size: 8, color: Colors.tealAccent),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // Show settings dialog
  void _showSettingsDialog() {
    double tempFontSize = _fontSize;
    double tempSpeechRate = _speechRate;
    bool tempHighContrast = _useHighContrast;
    bool tempVibration = _useVibrationFeedback;
    int tempTimeout = _autoDetectTimeout;
    bool tempAutoSpeak = _autoSpeak;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Accessibility Settings", style: TextStyle(fontSize: 24)),
          backgroundColor: Colors.black,
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Text Size", style: TextStyle(fontSize: 20)),
                Slider(
                  value: tempFontSize,
                  min: 16.0,
                  max: 32.0,
                  divisions: 8,
                  label: tempFontSize.round().toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      tempFontSize = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text("Speech Rate", style: TextStyle(fontSize: 20)),
                Slider(
                  value: tempSpeechRate,
                  min: 0.25,
                  max: 1.0,
                  divisions: 6,
                  label: tempSpeechRate.toStringAsFixed(2),
                  onChanged: (value) {
                    setDialogState(() {
                      tempSpeechRate = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text("Auto Detection Timeout (seconds)", style: TextStyle(fontSize: 20)),
                Slider(
                  value: tempTimeout.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: tempTimeout.toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      tempTimeout = value.round();
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("High Contrast Mode", style: TextStyle(fontSize: 20)),
                  value: tempHighContrast,
                  activeColor: Colors.tealAccent,
                  onChanged: (value) {
                    setDialogState(() {
                      tempHighContrast = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text("Vibration Feedback", style: TextStyle(fontSize: 20)),
                  value: tempVibration,
                  activeColor: Colors.tealAccent,
                  onChanged: (value) {
                    setDialogState(() {
                      tempVibration = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text("Auto Speak Translation", style: TextStyle(fontSize: 20)),
                  value: tempAutoSpeak,
                  activeColor: Colors.tealAccent,
                  onChanged: (value) {
                    setDialogState(() {
                      tempAutoSpeak = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _speak("Settings canceled.");
              },
              child: const Text("Cancel", style: TextStyle(fontSize: 20, color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _fontSize = tempFontSize;
                  _speechRate = tempSpeechRate;
                  _useHighContrast = tempHighContrast;
                  _useVibrationFeedback = tempVibration;
                  _autoDetectTimeout = tempTimeout;
                  _autoSpeak = tempAutoSpeak;
                });

                _flutterTts.setSpeechRate(_speechRate);
                _saveSettings();

                Navigator.of(context).pop();
                _speak("Settings saved.");
              },
              child: const Text("Save", style: TextStyle(fontSize: 20, color: Colors.tealAccent)),
            ),
          ],
        ),
      ),
    );

    // Speak the settings dialog opened
    _speak("Settings dialog opened. Adjust your preferences and save when done.");
  }

  // Show language selection dialog
  void _showLanguageSelectionDialog(bool isSource) {
    String currentLanguage = isSource ? _sourceLanguage : _targetLanguage;
    String tempLanguage = currentLanguage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isSource ? "Select Source Language" : "Select Target Language",
            style: const TextStyle(fontSize: 24),
          ),
          backgroundColor: Colors.black,
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _languageMap.length,
              itemBuilder: (context, index) {
                String langCode = _languageMap.keys.elementAt(index);
                String langName = _languageMap[langCode]!;

                return ListTile(
                  title: Text(langName, style: const TextStyle(fontSize: 20)),
                  trailing: langCode == tempLanguage
                      ? const Icon(Icons.check, color: Colors.tealAccent)
                      : null,
                  onTap: () {
                    setDialogState(() {
                      tempLanguage = langCode;
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _speak("Language selection canceled.");
              },
              child: const Text("Cancel", style: TextStyle(fontSize: 20, color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (isSource) {
                    _sourceLanguage = tempLanguage;
                  } else {
                    _targetLanguage = tempLanguage;
                    _flutterTts.setLanguage(_targetLanguage);
                  }
                });

                _saveSettings();
                Navigator.of(context).pop();

                _speak("${isSource ? 'Source' : 'Target'} language set to ${_languageMap[tempLanguage]}.");
              },
              child: const Text("Select", style: TextStyle(fontSize: 20, color: Colors.tealAccent)),
            ),
          ],
        ),
      ),
    );

    // Speak the language selection dialog opened
    _speak("${isSource ? 'Source' : 'Target'} language selection dialog opened. Current language is ${_languageMap[currentLanguage]}.");
  }

  // Build an accessible text field
  Widget _buildAccessibleTextField({
    required TextEditingController controller,
    required String label,
    required bool isSource,
    required VoidCallback onDoubleTap,
    required VoidCallback onTripleTap,
  }) {
    return Semantics(
      label: label,
      hint: isSource
          ? "Double tap to activate voice input, triple tap to paste from clipboard"
          : "Double tap to hear translation, triple tap to copy to clipboard",
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _useHighContrast ? Colors.black : Colors.grey.shade900,
          border: Border.all(
            color: _useHighContrast ? Colors.tealAccent : Colors.grey.shade700,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onDoubleTap: onDoubleTap,
          onTap: () {
            // Announce the field
            _speak(isSource
                ? "Source text field. Double tap to activate voice input."
                : "Translation field. Double tap to hear translation.");
          },
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: _fontSize,
              color: _useHighContrast ? Colors.white : Colors.grey.shade300,
            ),
            maxLines: 8,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: _useHighContrast ? Colors.tealAccent : Colors.grey.shade400,
                fontSize: _fontSize - 2,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            readOnly: !isSource, // Only source field is editable
          ),
        ),
      ),
    );
  }

  // Build an accessible button
  Widget _buildAccessibleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? (_useHighContrast ? Colors.teal : Colors.teal.shade700),
            minimumSize: const Size(0, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accessible Translator',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _useHighContrast ? Colors.tealAccent : Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: GestureDetector(
        onLongPress: () {
          _speak("Accessible Translator app. Double tap anywhere for help.");
        },
        onDoubleTap: _showHelpDialog,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language selection row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showLanguageSelectionDialog(true),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              'Source',
                              style: TextStyle(
                                fontSize: 16,
                                color: _useHighContrast ? Colors.tealAccent : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _languageMap[_sourceLanguage] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 28),
                    onPressed: () {
                      if (_sourceLanguage != _targetLanguage) {
                        setState(() {
                          String temp = _sourceLanguage;
                          _sourceLanguage = _targetLanguage;
                          _targetLanguage = temp;

                          // Swap text if both fields have content
                          if (_sourceController.text.isNotEmpty && _targetController.text.isNotEmpty) {
                            String tempText = _sourceController.text;
                            _sourceController.text = _targetController.text;
                            _targetController.text = tempText;
                          }
                        });

                        _speak("Languages swapped. Source language is now ${_languageMap[_sourceLanguage]} and target language is ${_languageMap[_targetLanguage]}.");
                        _saveSettings();
                      } else {
                        _speak("Source and target languages are the same. Cannot swap.");
                      }
                    },
                    tooltip: 'Swap Languages',
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showLanguageSelectionDialog(false),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              'Target',
                              style: TextStyle(
                                fontSize: 16,
                                color: _useHighContrast ? Colors.tealAccent : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _languageMap[_targetLanguage] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Source text field
              _buildAccessibleTextField(
                controller: _sourceController,
                label: 'Source Text',
                isSource: true,
                onDoubleTap: _startListening,
                onTripleTap: _stopListening,
              ),
              // Translate button
              ElevatedButton.icon(
                onPressed: _translate,
                icon: Icon(_isTranslating ? Icons.hourglass_top : Icons.translate),
                label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _useHighContrast ? Colors.tealAccent : Colors.teal,
                  foregroundColor: _useHighContrast ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 16),
              // Target text field
              _buildAccessibleTextField(
                controller: _targetController,
                label: 'Translation',
                isSource: false,
                onDoubleTap: _speakTranslation,
                onTripleTap: () => _copyToClipboard(_targetController.text),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      _buildAccessibleButton(
                        icon: _isListening ? Icons.mic_off : Icons.mic,
                        label: _isListening ? 'Stop' : 'Speak',
                        onPressed: _isListening ? _stopListening : _startListening,
                        color: _isListening ? Colors.red : null,
                      ),
                      _buildAccessibleButton(
                        icon: Icons.volume_up,
                        label: 'Speak Source',
                        onPressed: _speakSource,
                      ),
                      _buildAccessibleButton(
                        icon: Icons.volume_up,
                        label: 'Speak Translation',
                        onPressed: _speakTranslation,
                      ),
                      _buildAccessibleButton(
                        icon: Icons.content_copy,
                        label: 'Copy Translation',
                        onPressed: () => _copyToClipboard(_targetController.text),
                      ),
                      _buildAccessibleButton(
                        icon: Icons.content_paste,
                        label: 'Paste',
                        onPressed: _startListening,
                      ),
                      _buildAccessibleButton(
                        icon: Icons.clear,
                        label: 'Clear',
                        onPressed: _clearText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
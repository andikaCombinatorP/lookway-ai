import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

class AccessibleAIChatPage extends StatefulWidget {
  const AccessibleAIChatPage({Key? key}) : super(key: key);

  @override
  _AccessibleAIChatPageState createState() => _AccessibleAIChatPageState();
}

class _AccessibleAIChatPageState extends State<AccessibleAIChatPage> with WidgetsBindingObserver {
  // Camera related variables
  List<CameraDescription>? cameras;
  CameraController? controller;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isCameraVisible = false;
  FlashMode _currentFlashMode = FlashMode.off;
  
  // Chat related variables
  List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;
  bool _isProcessing = false;
  
  // Accessibility related variables
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  double _fontSizeMultiplier = 1.0;
  
  // API related variables
  final String apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyC1IMuKdxY6zQT30S8zWiq1lDIxV4TuReU";
  
  // Theme related variables
  bool _highContrastMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeAccessibilityFeatures();
    
    // Add welcome message
    Future.delayed(Duration(milliseconds: 500), () {
      _addSystemMessage("Hello! I'm your AI assistant. I'm here to help you. You can speak to me by pressing and holding the microphone button, or type your message. Say 'help' for assistance with available commands.");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _textController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App lifecycle management for camera
    final CameraController? cameraController = controller;
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        controller = CameraController(
          cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        await controller!.initialize();
        if (!mounted) return;
        
        setState(() {
          _isCameraInitialized = true;
          _isCameraPermissionGranted = true;
        });
      } else {
        _addSystemMessage("No cameras found on this device.");
      }
    } on CameraException catch (e) {
      _handleCameraError(e);
    } catch (e) {
      _addSystemMessage("Failed to initialize camera: $e");
    }
  }

  // Initialize accessibility features
  Future<void> _initializeAccessibilityFeatures() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    await _speechToText.initialize(
      onError: (error) => _addSystemMessage("Speech recognition error: $error"),
    );
    
    // Set up TTS completion listener
    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      setState(() {
        _isProcessing = true;
      });
      await flutterTts.speak(text);
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        Vibration.vibrate(duration: 100);
        setState(() {
          _isListening = true;
        });
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
                if (_textController.text.isNotEmpty) {
                  _handleSubmitted(_textController.text);
                }
              }
            });
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      } else {
        _addSystemMessage("Speech recognition not available");
      }
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraVisible = !_isCameraVisible;
    });
    
    if (_isCameraVisible) {
      _speak("Camera is now open. Double tap to take a photo.");
    } else {
      _speak("Camera is now closed.");
    }
  }

  void _toggleFlashlight() {
    if (controller == null || !controller!.value.isInitialized) return;
    
    setState(() {
      if (_currentFlashMode == FlashMode.off) {
        _currentFlashMode = FlashMode.torch;
        _speak("Flashlight on");
      } else {
        _currentFlashMode = FlashMode.off;
        _speak("Flashlight off");
      }
      controller!.setFlashMode(_currentFlashMode);
    });
  }

  Future<void> _takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) {
      _speak("Camera is not ready");
      return;
    }
    
    try {
      Vibration.vibrate(duration: 200);
      _speak("Taking photo");
      
      final XFile photo = await controller!.takePicture();
      final File imageFile = File(photo.path);
      
      _sendImageToAI(imageFile);
      setState(() {
        _isCameraVisible = false;
      });
    } catch (e) {
      _speak("Failed to take photo: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        _sendImageToAI(imageFile);
      } else {
        _speak("No image selected");
      }
    } catch (e) {
      _speak("Failed to pick image: $e");
    }
  }

  Future<void> _sendImageToAI(File imageFile) async {
    try {
      _addUserImageMessage(imageFile.path);
      _speak("Analyzing image. Please wait.");
      
      // Convert image to base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Prepare request payload
      Map<String, dynamic> payload = {
        "contents": [
          {
            "parts": [
              {"text": "Describe this image in detail for a visually impaired person:"},
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      };
      
      // Send request to AI
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        String aiResponse = responseData['candidates'][0]['content']['parts'][0]['text'];
        _addAIMessage(aiResponse);
        _speak(aiResponse);
      } else {
        String errorMessage = "Failed to analyze image. Error: ${response.statusCode}";
        _addSystemMessage(errorMessage);
        _speak(errorMessage);
      }
    } catch (e) {
      String errorMessage = "Error processing image: $e";
      _addSystemMessage(errorMessage);
      _speak(errorMessage);
    }
  }

  Future<void> _sendMessageToAI(String message) async {
    try {
      _speak("Processing your request");
      
      Map<String, dynamic> payload = {
        "contents": [
          {
            "parts": [
              {"text": message}
            ]
          }
        ]
      };
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        String aiResponse = responseData['candidates'][0]['content']['parts'][0]['text'];
        _addAIMessage(aiResponse);
        _speak(aiResponse);
      } else {
        String errorMessage = "Failed to get response. Error: ${response.statusCode}";
        _addSystemMessage(errorMessage);
        _speak(errorMessage);
      }
    } catch (e) {
      String errorMessage = "Error: $e";
      _addSystemMessage(errorMessage);
      _speak(errorMessage);
    }
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    
    if (text.trim().isEmpty) return;
    
    // Check for special commands
    if (_handleSpecialCommands(text.toLowerCase().trim())) {
      return;
    }
    
    // Regular message processing
    _addUserMessage(text);
    _sendMessageToAI(text);
  }

  bool _handleSpecialCommands(String text) {
    switch (text) {
      case 'help':
        _addSystemMessage(
          "Available commands:\n"
          "- 'camera': Open camera to take a photo\n"
          "- 'gallery': Select image from gallery\n"
          "- 'flashlight': Toggle flashlight on/off\n"
          "- 'clear': Clear chat history\n"
          "- 'font larger': Increase font size\n"
          "- 'font smaller': Decrease font size\n"
          "- 'high contrast': Toggle high contrast mode\n"
          "- 'stop speaking': Stop voice output\n"
          "- 'help': Show this help message"
        );
        return true;
        
      case 'camera':
        _toggleCamera();
        return true;
        
      case 'gallery':
        _pickImage();
        return true;
        
      case 'flashlight':
        _toggleFlashlight();
        return true;
        
      case 'clear':
        setState(() {
          _messages.clear();
        });
        _speak("Chat history cleared");
        return true;
        
      case 'font larger':
        setState(() {
          _fontSizeMultiplier += 0.2;
          if (_fontSizeMultiplier > 2.0) _fontSizeMultiplier = 2.0;
        });
        _speak("Font size increased");
        return true;
        
      case 'font smaller':
        setState(() {
          _fontSizeMultiplier -= 0.2;
          if (_fontSizeMultiplier < 0.8) _fontSizeMultiplier = 0.8;
        });
        _speak("Font size decreased");
        return true;
        
      case 'high contrast':
        setState(() {
          _highContrastMode = !_highContrastMode;
        });
        _speak(_highContrastMode ? "High contrast mode enabled" : "High contrast mode disabled");
        return true;
        
      case 'stop speaking':
        flutterTts.stop();
        setState(() {
          _isProcessing = false;
        });
        return true;
        
      default:
        return false;
    }
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _addUserImageMessage(String imagePath) {
    setState(() {
      _messages.add(ChatMessage(
        text: "Image sent",
        isUser: true,
        timestamp: DateTime.now(),
        imagePath: imagePath,
      ));
    });
  }

  void _addAIMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _addSystemMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: false,
        isSystem: true,
        timestamp: DateTime.now(),
      ));
    });
    _speak(message);
  }
  
  void _handleCameraError(CameraException e) {
    String errorMessage;
    switch (e.code) {
      case 'CameraAccessDenied':
        errorMessage = 'Camera access was denied. Please grant camera permission in settings.';
        break;
      default:
        errorMessage = 'Camera error: ${e.description}';
    }
    _addSystemMessage(errorMessage);
    setState(() {
      _isCameraPermissionGranted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = _getThemeData();
    
    return Theme(
      data: themeData,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 20 * _fontSizeMultiplier,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline),
              onPressed: () => _handleSubmitted('help'),
              tooltip: 'Help',
      
            ),
            IconButton(
              icon: Icon(_highContrastMode ? Icons.contrast : Icons.contrast_outlined),
              onPressed: () => _handleSpecialCommands('high contrast'),
              tooltip: 'Toggle High Contrast',
   
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => _showAccessibilitySettings(),
              tooltip: 'Accessibility Settings',

            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: SafeArea(
            child: Column(
              children: [
                // Camera preview (when active)
                if (_isCameraVisible && _isCameraInitialized)
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onDoubleTap: _takePhoto,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CameraPreview(controller!),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                FloatingActionButton(
                                  heroTag: "closeCamera",
                                  onPressed: _toggleCamera,
                                  tooltip: 'Close Camera',
                                  child: Icon(Icons.close),
                                  backgroundColor: Colors.red.withOpacity(0.7),
                                ),
                                FloatingActionButton(
                                  heroTag: "takePhoto",
                                  onPressed: _takePhoto,
                                  tooltip: 'Take Photo',
                                  child: Icon(Icons.camera),
                                  backgroundColor: Colors.blue.withOpacity(0.7),
                                ),
                                FloatingActionButton(
                                  heroTag: "flashlight",
                                  onPressed: _toggleFlashlight,
                                  tooltip: 'Toggle Flashlight',
                                  child: Icon(_currentFlashMode == FlashMode.torch 
                                    ? Icons.flash_on 
                                    : Icons.flash_off),
                                  backgroundColor: Colors.amber.withOpacity(0.7),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Chat messages
                Expanded(
                  flex: _isCameraVisible ? 2 : 5,
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          reverse: true, // Display latest messages at the bottom
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageItem(
                              _messages[_messages.length - 1 - index],
                              themeData,
                            );
                          },
                        ),
                ),
                
                // Input area
                _buildInputArea(),
              ],
            ),
          ),
        ),
        floatingActionButton: _isProcessing
            ? FloatingActionButton(
                onPressed: () {
                  flutterTts.stop();
                  setState(() {
                    _isProcessing = false;
                  });
                },
                tooltip: 'Stop Speaking',
                child: Icon(Icons.stop),
                backgroundColor: Colors.red,
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: _highContrastMode ? Colors.white : Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            'Welcome to AI Assistant',
            style: TextStyle(
              fontSize: 20 * _fontSizeMultiplier,
              fontWeight: FontWeight.bold,
              color: _highContrastMode ? Colors.white : Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Start a conversation by typing a message or using voice input.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16 * _fontSizeMultiplier,
                color: _highContrastMode ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.help_outline),
            label: Text(
              'Show Commands',
              style: TextStyle(fontSize: 16 * _fontSizeMultiplier),
            ),
            onPressed: () => _handleSubmitted('help'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;
    final isSystem = message.isSystem;
    
    // Color settings for different message types
    Color backgroundColor;
    Color textColor;
    Color timeColor;
    
    if (_highContrastMode) {
      if (isSystem) {
        backgroundColor = Colors.amber[900]!;
        textColor = Colors.white;
        timeColor = Colors.white70;
      } else if (isUser) {
        backgroundColor = Colors.blue[800]!;
        textColor = Colors.white;
        timeColor = Colors.white70;
      } else {
        backgroundColor = Colors.grey[800]!;
        textColor = Colors.white;
        timeColor = Colors.white70;
      }
    } else {
      if (isSystem) {
        backgroundColor = Colors.amber[100]!;
        textColor = Colors.black87;
        timeColor = Colors.black54;
      } else if (isUser) {
        backgroundColor = theme.colorScheme.primary.withOpacity(0.2);
        textColor = theme.textTheme.bodyLarge!.color!;
        timeColor = theme.textTheme.bodySmall!.color!;
      } else {
        backgroundColor = theme.colorScheme.surface;
        textColor = theme.textTheme.bodyLarge!.color!;
        timeColor = theme.textTheme.bodySmall!.color!;
      }
    }

    return Semantics(
      label: "${isUser ? 'You' : 'AI'} said, ${message.text}",
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display image if present
                if (message.imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        File(message.imagePath!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                // Message text
                Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16 * _fontSizeMultiplier,
                  ),
                ),
                
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: timeColor,
                      fontSize: 12 * _fontSizeMultiplier,
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

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: _highContrastMode 
            ? Colors.grey[900] 
            : Colors.grey[200],
        border: Border(
          top: BorderSide(
            color: _highContrastMode 
                ? Colors.grey[800]! 
                : Colors.grey[300]!,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          // Camera button
          IconButton(
            icon: Icon(Icons.camera_alt),
            tooltip: 'Camera',
            onPressed: _toggleCamera,
            color: _highContrastMode ? Colors.white : null,
          ),
          
          // Gallery button
          IconButton(
            icon: Icon(Icons.photo_library),
            tooltip: 'Gallery',
            onPressed: _pickImage,
            color: _highContrastMode ? Colors.white : null,
          ),
          
          // Text input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _highContrastMode 
                    ? Colors.grey[800] 
                    : Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: _highContrastMode 
                      ? Colors.grey[700]! 
                      : Colors.grey[400]!,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: FocusNode(),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 16 * _fontSizeMultiplier,
                  color: _highContrastMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: TextStyle(
                    color: _highContrastMode 
                        ? Colors.grey[400] 
                        : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0, 
                    vertical: 12.0,
                  ),
                ),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                onSubmitted: _handleSubmitted,
              ),
            ),
          ),
          
          SizedBox(width: 8),
          
          // Voice input button
          GestureDetector(
            onLongPress: _startListening,
            onLongPressEnd: (details) => _stopListening(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening 
                    ? Colors.red 
                    : Theme.of(context).primaryColor,
              ),
              padding: EdgeInsets.all(10.0),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 28.0,
              ),
            ),
          ),
          
          SizedBox(width: 8),
          
          // Send button
          _isComposing
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send),
                    color: Colors.white,
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  void _showAccessibilitySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _highContrastMode ? Colors.black : Colors.white,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Accessibility Settings',
                      style: TextStyle(
                        fontSize: 20 * _fontSizeMultiplier,
                        fontWeight: FontWeight.bold,
                        color: _highContrastMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  
                  // Font size
                  Text(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 16 * _fontSizeMultiplier,
                      fontWeight: FontWeight.bold,
                      color: _highContrastMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Slider(
                    value: _fontSizeMultiplier,
                    min: 0.8,
                    max: 2.0,
                    divisions: 6,
                    label: '${(_fontSizeMultiplier * 100).round()}%',
                    onChanged: (value) {
                      setModalState(() {
                        setState(() {
                          _fontSizeMultiplier = value;
                        });
                      });
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Speech rate
                  Text(
                    'Speech Rate',
                    style: TextStyle(
                      fontSize: 16 * _fontSizeMultiplier,
                      fontWeight: FontWeight.bold,
                      color: _highContrastMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Slider(
                    value: 0.5,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: '${(0.5 * 100).round()}%',
                    onChanged: (value) async {
                      await flutterTts.setSpeechRate(value);
                    },
                  ),
                  
                                SizedBox(height: 16),

                  // High contrast toggle
                  SwitchListTile(
                    title: Text(
                      'High Contrast Mode',
                      style: TextStyle(
                        fontSize: 16 * _fontSizeMultiplier,
                        color: _highContrastMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    value: _highContrastMode,
                    onChanged: (value) {
                      setModalState(() {
                        setState(() {
                          _highContrastMode = value;
                        });
                      });
                      _speak(_highContrastMode ? "High contrast mode enabled" : "High contrast mode disabled");
                    },
                    activeColor: Colors.blue,
                    activeTrackColor: Colors.blue[200],
                  ),

                  SizedBox(height: 16),

                  // Close button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _speak("Accessibility settings closed");
                      },
                      child: Text(
                        'Close',
                        style: TextStyle(fontSize: 16 * _fontSizeMultiplier),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  ThemeData _getThemeData() {
    return ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: _highContrastMode ? Colors.black : Colors.white,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: _highContrastMode ? Colors.white : Colors.black87,
          fontSize: 16 * _fontSizeMultiplier,
        ),
        bodyMedium: TextStyle(
          color: _highContrastMode ? Colors.white70 : Colors.black54,
          fontSize: 14 * _fontSizeMultiplier,
        ),
        bodySmall: TextStyle(
          color: _highContrastMode ? Colors.white70 : Colors.black54,
          fontSize: 12 * _fontSizeMultiplier,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: _highContrastMode ? Colors.black : Colors.white,
          backgroundColor: _highContrastMode ? Colors.white : Colors.blue,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
  }
}

// ChatMessage class to hold message data
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;
  final String? imagePath;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isSystem = false,
    required this.timestamp,
    this.imagePath,
  });
}
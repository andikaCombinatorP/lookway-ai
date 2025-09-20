import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:lookway/Api/api_config.dart';
import 'package:lookway/Tools/ImageDescription/imagedescription.dart';
import 'package:lookway/Tools/Test/models.dart';
import 'package:lookway/Tools/Test/test3.dart';
import 'package:lookway/Tools/Test/testfeature.dart';
import 'package:lookway/Tools/TextToVoice/text_to_voice.dart';
import 'package:lookway/main.dart';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import '../ImageDescription/imgdescription.dart';

enum SharedContentType {
  video,
  image,
  carousel,
  story,
  unknown,
  audio,
  document
}

class FacebookMedia {
  final String url;
  final String type;
  final String? thumbnailUrl;

  FacebookMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });
}

class FacebookDownloader {
  static final RegExp _postRegex = RegExp(
    r'^https?:\/\/(www\.)?facebook\.com\/[\w.]+\/posts\/[\d]+\/?$',
    caseSensitive: false,
  );

  static final RegExp _videoRegex = RegExp(
    r'^https?:\/\/(www\.)?facebook\.com\/[\w.]+\/videos\/[\d]+\/?$',
    caseSensitive: false,
  );

  static bool isFacebookUrl(String url) {
    return url.startsWith('https://www.facebook.com/') ||
        url.startsWith('https://facebook.com/');
  }

  static bool isFacebookVideo(String url) {
    return _videoRegex.hasMatch(url);
  }

  static bool isFacebookPost(String url) {
    return _postRegex.hasMatch(url);
  }

  static Future<List<FacebookMedia>> extractFacebookMedia(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
      );

      if (response.statusCode != 200)
        throw Exception('Failed to fetch Facebook page');

      final document = html_parser.parse(response.body);
      final metaTags = document.getElementsByTagName('meta');

      String? videoUrl, imageUrl;

      for (final meta in metaTags) {
        if (meta.attributes['property'] == 'og:video') {
          videoUrl = meta.attributes['content'];
        } else if (meta.attributes['property'] == 'og:image') {
          imageUrl = meta.attributes['content'];
        }
      }

      // Pastikan bahwa video URL valid (mengandung .mp4 atau jenis file video lainnya)
      if (videoUrl != null && videoUrl.contains('.mp4')) {
        return [FacebookMedia(url: videoUrl, type: 'video')];
      } else if (imageUrl != null) {
        return [FacebookMedia(url: imageUrl, type: 'image')];
      }

      throw Exception('No valid media found');
    } catch (e) {
      throw Exception('Error extracting Facebook media: $e');
    }
  }
}

class InstagramMedia {
  final String url;
  final String type;
  final String? thumbnailUrl;

  InstagramMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });
}

class InstagramDownloader {
  static final RegExp _postRegex = RegExp(
    r'^https?:\/\/(www\.)?instagram\.com\/(p|reel|tv)\/[\w-]+\/?$',
    caseSensitive: false,
  );

  static final RegExp _storyRegex = RegExp(
    r'^https?:\/\/(www\.)?instagram\.com\/stories\/[\w\.]+\/\d+\/?$',
    caseSensitive: false,
  );

  static bool isInstagramUrl(String url) {
    return url.startsWith('https://www.instagram.com/') ||
        url.startsWith('https://instagram.com/');
  }

  static bool isInstagramStory(String url) {
    return _storyRegex.hasMatch(url);
  }

  static bool isInstagramPost(String url) {
    return _postRegex.hasMatch(url);
  }

  static Future<List<InstagramMedia>> extractInstagramMedia(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Instagram page');
      }

      final document = html_parser.parse(response.body);
      final metaTags = document.getElementsByTagName('meta');
      List<InstagramMedia> mediaList = [];

      // Check for carousel/multiple images
      final scripts = document.getElementsByTagName('script');
      for (final script in scripts) {
        if (script.text.contains('"carousel_media"')) {
          try {
            final jsonStart = script.text.indexOf('{');
            final jsonEnd = script.text.lastIndexOf('}') + 1;
            final jsonStr = script.text.substring(jsonStart, jsonEnd);
            final data = jsonDecode(jsonStr);

            if (data['carousel_media'] != null) {
              for (final media in data['carousel_media']) {
                if (media['video_url'] != null) {
                  mediaList.add(InstagramMedia(
                    url: media['video_url'],
                    type: 'video',
                    thumbnailUrl: media['image_versions2']?['candidates']?[0]
                        ?['url'],
                  ));
                } else if (media['image_versions2'] != null) {
                  mediaList.add(InstagramMedia(
                    url: media['image_versions2']['candidates'][0]['url'],
                    type: 'image',
                  ));
                }
              }
              return mediaList;
            }
          } catch (e) {
            print('Error parsing carousel data: $e');
          }
        }
      }

      // If no carousel found, check for single video/image
      String? videoUrl;
      String? imageUrl;
      String? thumbnailUrl;

      for (final meta in metaTags) {
        switch (meta.attributes['property']) {
          case 'og:video':
            videoUrl = meta.attributes['content'];
            break;
          case 'og:image':
            imageUrl = meta.attributes['content'];
            break;
          case 'og:video:secure_url':
            thumbnailUrl = meta.attributes['content'];
            break;
        }
      }

      if (videoUrl != null) {
        mediaList.add(InstagramMedia(
          url: videoUrl,
          type: 'video',
          thumbnailUrl: thumbnailUrl ?? imageUrl,
        ));
      } else if (imageUrl != null) {
        mediaList.add(InstagramMedia(
          url: imageUrl,
          type: 'image',
        ));
      }

      if (mediaList.isEmpty) {
        throw Exception('No media found in Instagram post');
      }

      return mediaList;
    } catch (e) {
      throw Exception('Error extracting Instagram media: $e');
    }
  }
}

class MediaCache {
  static const String _cachePrefix = 'media_';

  static Future<String?> getCachedPath(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_cachePrefix${_getUrlHash(url)}');
  }

  static Future<void> cacheMedia(String url, String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix${_getUrlHash(url)}', filePath);
  }

  static String _getUrlHash(String url) {
    return base64Url.encode(utf8.encode(url)).replaceAll(RegExp(r'[^\w]'), '');
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

    for (final key in keys) {
      final path = prefs.getString(key);
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error deleting cached file: $e');
        }
      }
      await prefs.remove(key);
    }
  }
}

class UniversalShareHandler extends StatefulWidget {
  const UniversalShareHandler({Key? key}) : super(key: key);

  @override
  _UniversalShareHandlerState createState() => _UniversalShareHandlerState();
}

class _UniversalShareHandlerState extends State<UniversalShareHandler> {
  dynamic _sharedContent;
  SharedContentType _contentType = SharedContentType.unknown;
  bool _isProcessing = false;
  String _processedDescription = '';
  final TextEditingController _urlController = TextEditingController();
  double _downloadProgress = 0.0;
  List<File> _carouselFiles = [];
  int _currentCarouselIndex = 0;
  String? userRole;
  static final FlutterTts tts = FlutterTts();
  VideoPlayerController? _videoPlayerController;
  late StreamSubscription _intentSub;
  final FocusNode _descriptionFocusNode = FocusNode();

  final apiUrl = "${ApiConfig.geminiApi}";

  @override
  void initState() {
    super.initState();
    loadAndApplySettings();
    _setupShareIntentListeners();
    _loadLoginStatus();
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

  Future<void> _loadLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Ambil role langsung dari SharedPreferences
    String? role = prefs.getString('role');

    setState(() {
      userRole = role; // Set userRole langsung dari shared preferences
    });
  }

  void _setupShareIntentListeners() {
    // Listen to media sharing (video/image)
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          // Navigate to the UniversalShareHandler page

          _processSharedContent(value.first);
        }
      },
      onError: (err) {
        _handleError('Gagal memproses konten berbagi: $err');
      },
    );

    // Get initial shared media (video/image)
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        // Navigate to the UniversalShareHandler page

        _processSharedContent(value.first);
      }
      // Reset intent after processing
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _processSharedContent(SharedMediaFile sharedFile) async {
    setState(() {
      _isProcessing = true;
      _sharedContent = null;
      _processedDescription = '';
      _downloadProgress = 0.0;
      _carouselFiles = [];
    });

    print('Shared file details: ${sharedFile.toMap()}');

    try {
      if (sharedFile.type == SharedMediaType.text) {
        if (InstagramDownloader.isInstagramUrl(sharedFile.path)) {
          await _processInstagramContent(sharedFile.path);
        } else if (FacebookDownloader.isFacebookUrl(sharedFile.path)) {
          await _processFacebookContent(sharedFile.path);
        } else {
          _handleError(
              'URL tidak didukung. Silakan bagikan URL Instagram atau Facebook.');
        }
      } else {
        switch (sharedFile.type) {
          case SharedMediaType.video:
            _processVideo(File(sharedFile.path));
            break;
          case SharedMediaType.image:
            _processImage(File(sharedFile.path));
            break;
          case SharedMediaType.file:
            // Cek apakah file yang dibagikan adalah audio
            if (sharedFile.path.endsWith('.mp3') ||
                sharedFile.path.endsWith('.wav') ||
                sharedFile.path.endsWith('.opus')) {
              _processAudio(File(sharedFile.path));
            }
            // Cek apakah file yang dibagikan adalah PDF
            else if (sharedFile.path.endsWith('.pdf')) {
              _processPDF(File(sharedFile.path));
            } else {
              _handleError('Tipe file tidak didukung');
            }
            break;
          default:
            _handleError('Tipe konten tidak didukung');
        }
      }
    } catch (e) {
      _handleError('Error processing content: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _processPDF(File pdfFile) {
    setState(() {
      _contentType = SharedContentType.document;
      _sharedContent = pdfFile;
    });
    _analyzeContentWithAI(pdfFile, 'pdf');
    // Tampilkan PDF dalam viewer atau olah lebih lanjut
    print('PDF File Path: ${pdfFile.path}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF berhasil dibagikan: ${pdfFile.path}')),
    );

    // Bisa tambahkan logika seperti preview PDF atau mengubah ke teks dengan OCR
  }

  void _processAudio(File audioFile) {
    setState(() {
      _contentType = SharedContentType.audio;
      _sharedContent = audioFile;
    });

    // Proses audio
    _analyzeContentWithAI(audioFile, 'audio');
  }

  void _processVideo(File videoFile) {
    setState(() {
      _contentType = SharedContentType.video;
      _sharedContent = videoFile;
    });

    _initializeVideoPlayer(videoFile);
    _analyzeContentWithAI(videoFile, 'video');
  }

  void _initializeVideoPlayer(File videoFile) {
    _videoPlayerController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController?.play();
      });
  }

  void _processImage(File imageFile) {
    setState(() {
      _contentType = SharedContentType.image;
      _sharedContent = imageFile;
    });

    _analyzeContentWithAI(imageFile, 'image');
  }

  void _handleError(String message) {
    setState(() {
      _isProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    // Debug: Print error message
    print('Error: $message');
  }

  Future<void> _analyzeContentWithAI(dynamic content, String type) async {
    try {
      String base64Content = '';
      String prompt = '';
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String promptQuality = prefs.getString('promptQuality') ?? 'detail';
      // Prepare content based on type
      switch (type) {
        case 'video':
          final videoBytes = await (content as File).readAsBytes();
          base64Content = base64Encode(videoBytes);
          prompt =
              "Deskripsikan video ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual nya, lalu tambahkan 'Linkara Access.";
          break;
        case 'image':
          final imageBytes = await (content as File).readAsBytes();
          base64Content = base64Encode(imageBytes);
          prompt =
              "Deskripsikan gambar ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual nya, lalu tambahkan 'Linkara Access.";
          break;
        case 'audio':
          final audioBytes = await (content as File).readAsBytes();
          base64Content = base64Encode(audioBytes);
          prompt =
              "Deskripsikan audio ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak mendengar nya, lalu tambahkan 'Linkara Access.";
          break;
        case 'pdf':
          final pdfBytes = await (content as File).readAsBytes();
          base64Content = base64Encode(pdfBytes);
          prompt =
              "Deskripsikan pdf ini dengan sangat ${promptQuality} dan mudah di mengerti oleh orang yang tidak melihat visual Dan isinya,jika ada gambar visualisasikan, lalu tambahkan 'Linkara Access.";
          break;
      }

      // Prepare API payload
      final data = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              if (base64Content.isNotEmpty)
                {
                  "inlineData": {
                    "mimeType": type == 'video'
                        ? "video/mp4"
                        : (type == 'image'
                            ? "image/jpeg"
                            : (type == 'audio'
                                ? "audio/mp3"
                                : (type == 'pdf'
                                    ? "application/pdf"
                                    : "text/plain"))),
                    "data": base64Content,
                  }
                }
            ]
          }
        ],
      };

      // Debug: Print API payload
      print('API Payload: ${jsonEncode(data)}');

      // Send to API
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Debug: Print API response
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final description =
            result['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          _processedDescription = description;
        });
         Future.delayed(Duration(milliseconds: 20), () {
      FocusScope.of(context).requestFocus(_descriptionFocusNode);
    });
   Future.delayed(const Duration(milliseconds: 100), () async {
   await tts.speak(description);

});
        // Use text-to-speech
     
      } else {
        final errorResponse = jsonDecode(response.body);
        final errorMessage =
            errorResponse['error']['message'] ?? 'Gagal menganalisis konten';
        _handleError(errorMessage);
      }
    } catch (e) {
      _handleError('Kesalahan dalam analisis: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processFacebookContent(String url) async {
    try {
      // Step 1: Check cache first
      final cachedPath = await MediaCache.getCachedPath(url);
      if (cachedPath != null) {
        final cachedFile = File(cachedPath);
        if (await cachedFile.exists()) {
          _processFile(cachedFile);
          return;
        }
      }

      // Step 2: Extract media information from Facebook
      final mediaList = await FacebookDownloader.extractFacebookMedia(url);

      if (mediaList.length > 1) {
        // Handle carousel or multiple media items
      } else if (mediaList.isNotEmpty) {
        // Handle single media item
        final media = mediaList.first;
        final file = await _downloadMedia(media.url);
        await MediaCache.cacheMedia(url, file.path);
        _processFile(file);
      }
    } catch (e) {
      _handleError('Error processing Facebook content: $e');
    }
  }

  Future<void> _processInstagramContent(String url) async {
    try {
      // Check cache first
      final cachedPath = await MediaCache.getCachedPath(url);
      if (cachedPath != null) {
        final cachedFile = File(cachedPath);
        if (await cachedFile.exists()) {
          _processFile(cachedFile);
          return;
        }
      }

      // Extract media information from Instagram
      final mediaList = await InstagramDownloader.extractInstagramMedia(url);

      if (mediaList.length > 1) {
        // Handle carousel
        await _processCarousel(mediaList);
      } else if (mediaList.isNotEmpty) {
        // Handle single media
        final media = mediaList.first;
        final file = await _downloadMedia(media.url);
        await MediaCache.cacheMedia(url, file.path);
        _processFile(file);
      }
    } catch (e) {
      _handleError('Error processing Instagram content: $e');
    }
  }

  Future<void> _processCarousel(List<InstagramMedia> mediaList) async {
    setState(() {
      _contentType = SharedContentType.carousel;
      _carouselFiles = [];
    });

    for (var i = 0; i < mediaList.length; i++) {
      setState(() {
        _downloadProgress = i / mediaList.length;
      });

      final media = mediaList[i];
      final file = await _downloadMedia(media.url);
      setState(() {
        _carouselFiles.add(file);
      });
    }

    if (_carouselFiles.isNotEmpty) {
      _processFile(_carouselFiles.first);
    }
  }

  Future<File> _downloadMedia(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36'
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download media');
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = url.toLowerCase().endsWith('.mp4') ? 'mp4' : 'jpg';
    final file = File('${directory.path}/media_${timestamp}.$extension');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  void _processFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'mp4') {
      _processVideo(file);
    } else {
      _processImage(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isProcessing
            ? _buildLoadingView()
            : (_sharedContent == null
                ? _buildInitialView(userRole)
                : (_contentType == SharedContentType.carousel
                    ? _buildCarouselView()
                    : SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        child: _buildContentView(),
                      ))),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            if (_downloadProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  children: [
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Downloading content...',
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

  Widget _buildInitialView(String? userRole) {
    return userRole == null ? MenuPage() : ImageDescriber();
  }

  Widget _buildCarouselView() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: _carouselFiles.length,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
              _processFile(_carouselFiles[index]);
            },
            itemBuilder: (context, index) {
              return _buildContentView();
            },
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _carouselFiles.length,
              (index) => AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: index == _currentCarouselIndex ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == _currentCarouselIndex
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentView() {
    if (_processedDescription.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            SizedBox(height: 16),
            Semantics(
              label: 'Anda di halaman Quick Send, Proses analisis sedang berlangsung dengan cermat. Harap tunggu sejenak, kami sedang menyiapkan hasil yang akurat dan relevan. Hasil analisis akan segera tersedia dan siap untuk anda dengarkan.',
              child: Text(
                "Processing content...",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMediaContent(),
          SizedBox(height: 16),
          _buildDescription(),
          if (_shouldShowAskMoreButton()) _buildAskMoreButton(),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (_contentType) {
      case SharedContentType.video:
        return _buildVideoPlayer();
      case SharedContentType.image:
        return _buildImageViewer();
      case SharedContentType.audio:
        return _buildAudioPlayer();
      case SharedContentType.document:
        return _buildDocumentViewer();
      default:
        return Container();
    }
  }

  Widget _buildVideoPlayer() {
    return _videoPlayerController != null
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              ),
            ),
          )
        : Container();
  }

  Widget _buildImageViewer() {
    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _sharedContent!,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.audio_file,
              size: 48, color: Theme.of(context).primaryColor),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Audio Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.description,
              size: 48, color: Theme.of(context).primaryColor),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Document Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Focus(
      focusNode: _descriptionFocusNode,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Semantics(
          label: 'Berikut Hasilnya',
          child: Text(
            _processedDescription,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  Widget _buildAskMoreButton() {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: () => _handleAskMore(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Text(
          'Ask More',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _shouldShowAskMoreButton() {
    return _contentType == SharedContentType.image ||
        _contentType == SharedContentType.audio ||
        _contentType == SharedContentType.video ||
        _contentType == SharedContentType.document;
  }

  void _handleAskMore() {
    if (_sharedContent == null) return;

    switch (_contentType) {
      case SharedContentType.image:
     showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) {
    return Semantics(
      label: 'Geser ke bawah untuk kembali',
      child:  ChatMoreCamera(
              imagePath: _sharedContent!.path,
              description: _processedDescription,
            ),
     
      
    );
  },
).whenComplete(() {
  // Memberi feedback suara saat modal ditutup, termasuk swipe down
  Future.delayed(Duration(milliseconds: 100), () {
    SemanticsService.announce(
      'Anda menutup tab',
      TextDirection.ltr,
    );
  });
});
        break;
      case SharedContentType.audio:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatMoreAudio(
              audioPath: _sharedContent!.path,
              description: _processedDescription,
            ),
          ),
        );
        break;
      case SharedContentType.video:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatMoreVideo(
              imagePath: _sharedContent!.path,
              description: _processedDescription,
            ),
          ),
        );
        break;
      case SharedContentType.document:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatMorePdf(
              pdfPath: _sharedContent!.path,
              description: _processedDescription,
            ),
          ),
        );
      default:
        break;
    }
  }
}

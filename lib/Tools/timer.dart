import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTS Timer for the Visually Impaired',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
          surface: Colors.grey[900]!,
          background: Colors.black,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 26.0),
          bodyMedium: TextStyle(fontSize: 22.0),
          titleLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold),
        ),
      ),
      home: AccessibilityIntroScreen(),
    );
  }
}

class AccessibilityIntroScreen extends StatefulWidget {
  @override
  _AccessibilityIntroScreenState createState() => _AccessibilityIntroScreenState();
}

class _AccessibilityIntroScreenState extends State<AccessibilityIntroScreen> {
  FlutterTts flutterTts = FlutterTts();
  bool _hasSpoken = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _checkFirstLaunch();
  }

  Future<void> _setupTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);
      _speakWelcome();
    } else {
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TimerScreen()),
        );
      });
    }
  }

  Future<void> _speakWelcome() async {
    if (_hasSpoken) return;

    setState(() {
      _hasSpoken = true;
    });

    await flutterTts.speak(
      "Welcome to the TTS Timer for the Visually Impaired. Touch and hold the screen to continue. "
      "This app features a timer with voice assistance. "
      "You can set the timer, hear the remaining time, and receive vibration alerts. "
      "Touch and hold to continue."
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPress: () {
          flutterTts.stop();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TimerScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.accessibility_new,
                  size: 120,
                  color: Colors.amber,
                ),
                SizedBox(height: 40),
                Text(
                  'TTS Timer for the Visually Impaired',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Colors.amber,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Text(
                  'Touch and hold to continue',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimerScreen extends StatefulWidget {
  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  FlutterTts flutterTts = FlutterTts();
  int _selectedHours = 0;
  int _selectedMinutes = 0;
  int _selectedSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  bool _isSettingsOpen = false;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  bool _vibrateOnComplete = true;
  bool _announceTimeIntervals = true;
  int _announceEveryMinutes = 5;
  bool _isVolumeButtonsControlEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupTts();
    _loadSettings();
    _speakInstructions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTimerState();
    } else if (state == AppLifecycleState.resumed) {
      _loadTimerState();
    }
  }

  Future<void> _setupTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(_speechRate);
    await flutterTts.setVolume(_speechVolume);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _speechVolume = prefs.getDouble('speech_volume') ?? 1.0;
      _vibrateOnComplete = prefs.getBool('vibrate_on_complete') ?? true;
      _announceTimeIntervals = prefs.getBool('announce_time_intervals') ?? true;
      _announceEveryMinutes = prefs.getInt('announce_every_minutes') ?? 5;
      _isVolumeButtonsControlEnabled = prefs.getBool('volume_buttons_control') ?? true;
    });
    await _setupTts();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setDouble('speech_volume', _speechVolume);
    await prefs.setBool('vibrate_on_complete', _vibrateOnComplete);
    await prefs.setBool('announce_time_intervals', _announceTimeIntervals);
    await prefs.setInt('announce_every_minutes', _announceEveryMinutes);
    await prefs.setBool('volume_buttons_control', _isVolumeButtonsControlEnabled);
  }

  Future<void> _saveTimerState() async {
    if (_isRunning) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('remaining_seconds', _remainingSeconds);
      await prefs.setBool('is_running', _isRunning);
      await prefs.setBool('is_paused', _isPaused);
      await prefs.setInt('pause_time', DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    int savedSeconds = prefs.getInt('remaining_seconds') ?? 0;
    bool wasRunning = prefs.getBool('is_running') ?? false;
    bool wasPaused = prefs.getBool('is_paused') ?? false;
    int pauseTime = prefs.getInt('pause_time') ?? 0;

    if (wasRunning && savedSeconds > 0) {
      if (!wasPaused) {
        int elapsedMs = DateTime.now().millisecondsSinceEpoch - pauseTime;
        int elapsedSeconds = (elapsedMs / 1000).floor();
        savedSeconds = savedSeconds > elapsedSeconds ? savedSeconds - elapsedSeconds : 0;
      }

      setState(() {
        _remainingSeconds = savedSeconds;
        _isRunning = savedSeconds > 0;
        _isPaused = wasPaused;
      });

      if (_isRunning && !_isPaused) {
        _startTimer();
        _speakRemainingTime();
      }
    }
  }

  void _speakInstructions() async {
    await flutterTts.speak(
      "Timer screen. Swipe up or down to adjust hours, minutes, and seconds. "
      "Double tap to start or pause the timer. "
      "Swipe right to open settings. "
      "Swipe left to hear the remaining time."
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });

        if (_announceTimeIntervals &&
            _remainingSeconds > 0 &&
            _remainingSeconds % (_announceEveryMinutes * 60) == 0) {
          _speakRemainingTime();
        }

        if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
          _speak("$_remainingSeconds");
        }
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _isPaused = false;
        });
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
    _speak("Timer paused. Remaining time ${_formatTime(_remainingSeconds)}");
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
    _speak("Timer resumed");
    _startTimer();
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = 0;
    });
    _speak("Timer stopped");
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = (_selectedHours * 3600) + (_selectedMinutes * 60) + _selectedSeconds;
    });
    _speak("Timer reset to ${_formatTime(_remainingSeconds)}");
  }

  void _onTimerComplete() async {
    _speak("Time's up! Timer completed!");

    if (_vibrateOnComplete && await Vibration.hasVibrator() ?? false) {
      for (int i = 0; i < 5; i++) {
        await Vibration.vibrate(duration: 500);
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
  }

  void _speak(String text) async {
    await flutterTts.speak(text);
  }

  void _speakRemainingTime() {
    if (_remainingSeconds > 0) {
      _speak("Remaining time ${_formatTime(_remainingSeconds)}");
    } else {
      _speak("Timer is not running");
    }
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;

    String hourText = h > 0 ? "$h hours " : "";
    String minuteText = m > 0 ? "$m minutes " : "";
    String secondText = s > 0 ? "$s seconds" : "";

    return "$hourText$minuteText$secondText".trim();
  }

  String _formatTimeDigital(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _increaseHours() {
    setState(() {
      _selectedHours = (_selectedHours + 1) % 24;
    });
    _speak("$_selectedHours hours");
  }

  void _decreaseHours() {
    setState(() {
      _selectedHours = (_selectedHours - 1 + 24) % 24;
    });
    _speak("$_selectedHours hours");
  }

  void _increaseMinutes() {
    setState(() {
      _selectedMinutes = (_selectedMinutes + 1) % 60;
    });
    _speak("$_selectedMinutes minutes");
  }

  void _decreaseMinutes() {
    setState(() {
      _selectedMinutes = (_selectedMinutes - 1 + 60) % 60;
    });
    _speak("$_selectedMinutes minutes");
  }

  void _increaseSeconds() {
    setState(() {
      _selectedSeconds = (_selectedSeconds + 1) % 60;
    });
    _speak("$_selectedSeconds seconds");
  }

  void _decreaseSeconds() {
    setState(() {
      _selectedSeconds = (_selectedSeconds - 1 + 60) % 60;
    });
    _speak("$_selectedSeconds seconds");
  }

  void _startOrPauseTimer() {
    if (!_isRunning) {
      setState(() {
        _isRunning = true;
        _remainingSeconds = (_selectedHours * 3600) + (_selectedMinutes * 60) + _selectedSeconds;
      });
      _speak("Timer started for ${_formatTime(_remainingSeconds)}");
      _startTimer();
    } else if (_isPaused) {
      _resumeTimer();
    } else {
      _pauseTimer();
    }
  }

  void _toggleSettings() {
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
    });

    if (_isSettingsOpen) {
      _speak("Settings menu opened. Swipe up or down to navigate, double tap to change settings.");
    } else {
      _speak("Settings menu closed");
    }
  }

  Widget _buildTimeSelector() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Set Timer',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTimeColumn('Hours', _selectedHours, _increaseHours, _decreaseHours),
            _buildTimeColumn('Minutes', _selectedMinutes, _increaseMinutes, _decreaseMinutes),
            _buildTimeColumn('Seconds', _selectedSeconds, _increaseSeconds, _decreaseSeconds),
          ],
        ),
        SizedBox(height: 40),
        _isRunning
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    _isPaused ? 'Resume' : 'Pause',
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    () => _isPaused ? _resumeTimer() : _pauseTimer(),
                  ),
                  _buildControlButton(
                    'Stop',
                    Icons.stop,
                    _stopTimer,
                  ),
                  _buildControlButton(
                    'Reset',
                    Icons.replay,
                    _resetTimer,
                  ),
                ],
              )
            : GestureDetector(
                onDoubleTap: _startOrPauseTimer,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Double tap to start',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildTimeColumn(String label, int value, VoidCallback onIncrease, VoidCallback onDecrease) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                onIncrease();
              } else if (details.primaryVelocity! > 0) {
                onDecrease();
              }
            },
            onTap: () {
              _speak("$label: $value. Swipe up to increase, swipe down to decrease.");
            },
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                value.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        _speak(label);
      },
      onDoubleTap: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.amber),
          SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningTimer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Timer Running',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30),
        Text(
          _formatTimeDigital(_remainingSeconds),
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            fontFamily: 'monospace',
          ),
        ),
        SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              _isPaused ? 'Resume' : 'Pause',
              _isPaused ? Icons.play_arrow : Icons.pause,
              () => _isPaused ? _resumeTimer() : _pauseTimer(),
            ),
            _buildControlButton(
              'Stop',
              Icons.stop,
              _stopTimer,
            ),
            _buildControlButton(
              'Reset',
              Icons.replay,
              _resetTimer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30),
        // Speech rate
        Text(
          'Speech Rate',
          style: TextStyle(fontSize: 20),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _speechRate,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _speechRate.toStringAsFixed(1),
                onChanged: (value) async {
                  setState(() {
                    _speechRate = value;
                  });
                  await flutterTts.setSpeechRate(_speechRate);
                  await _saveSettings();
                },
                onChangeEnd: (value) async {
                  _speak("Speech rate set to ${(value * 10).round()} out of 10");
                },
              ),
            ),
            Text(
              "${(_speechRate * 10).round()}/10",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        SizedBox(height: 20),
        // Speech volume
        Text(
          'Speech Volume',
          style: TextStyle(fontSize: 20),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _speechVolume,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _speechVolume.toStringAsFixed(1),
                onChanged: (value) async {
                  setState(() {
                    _speechVolume = value;
                  });
                  await flutterTts.setVolume(_speechVolume);
                  await _saveSettings();
                },
                onChangeEnd: (value) async {
                  _speak("Speech volume set to ${(value * 10).round()} out of 10");
                },
              ),
            ),
            Text(
              "${(_speechVolume * 10).round()}/10",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        SizedBox(height: 20),
        // Vibration on completion
        GestureDetector(
          onTap: () {
            _speak("Vibration on completion: ${_vibrateOnComplete ? 'On' : 'Off'}. Double tap to ${_vibrateOnComplete ? 'disable' : 'enable'}.");
          },
          onDoubleTap: () async {
            setState(() {
              _vibrateOnComplete = !_vibrateOnComplete;
            });
            _speak("Vibration on completion ${_vibrateOnComplete ? 'enabled' : 'disabled'}");
            await _saveSettings();
            if (_vibrateOnComplete) {
              Vibration.vibrate(duration: 300);
            }
          },
          child: Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vibration on Completion',
                  style: TextStyle(fontSize: 20),
                ),
                Switch(
                  value: _vibrateOnComplete,
                  activeColor: Colors.amber,
                  onChanged: (newValue) async {
                    setState(() {
                      _vibrateOnComplete = newValue;
                    });
                    _speak("Vibration on completion ${_vibrateOnComplete ? 'enabled' : 'disabled'}");
                    await _saveSettings();
                    if (_vibrateOnComplete) {
                      Vibration.vibrate(duration: 300);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 15),
        // Time interval announcements
        GestureDetector(
          onTap: () {
            _speak("Time interval announcements: ${_announceTimeIntervals ? 'On' : 'Off'}. Double tap to ${_announceTimeIntervals ? 'disable' : 'enable'}.");
          },
          onDoubleTap: () async {
            setState(() {
              _announceTimeIntervals = !_announceTimeIntervals;
            });
            _speak("Time interval announcements ${_announceTimeIntervals ? 'enabled' : 'disabled'}");
            await _saveSettings();
          },
          child: Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Interval Announcements',
                  style: TextStyle(fontSize: 20),
                ),
                Switch(
                  value: _announceTimeIntervals,
                  activeColor: Colors.amber,
                  onChanged: (newValue) async {
                    setState(() {
                      _announceTimeIntervals = newValue;
                    });
                    _speak("Time interval announcements ${_announceTimeIntervals ? 'enabled' : 'disabled'}");
                    await _saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 15),
        // Announcement interval
        _announceTimeIntervals
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Announcement Interval (minutes)',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      _speak("Announcement interval every $_announceEveryMinutes minutes. Double tap to change.");
                    },
                    onDoubleTap: () async {
                      List<int> options = [1, 5, 10, 15, 30];
                      int currentIndex = options.indexOf(_announceEveryMinutes);
                      if (currentIndex == -1) currentIndex = 1; // Default to 5 minutes

                      int nextIndex = (currentIndex + 1) % options.length;
                      setState(() {
                        _announceEveryMinutes = options[nextIndex];
                      });
                      _speak("Announcement interval set to every $_announceEveryMinutes minutes");
                      await _saveSettings();
                    },
                    child: Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Every $_announceEveryMinutes minutes',
                            style: TextStyle(fontSize: 18),
                          ),
                          Icon(Icons.timer, color: Colors.amber),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(),
        SizedBox(height: 20),
        // Back button
        GestureDetector(
          onTap: () {
            _speak("Return to timer. Double tap to confirm.");
          },
          onDoubleTap: () {
            _toggleSettings();
          },
          child: Container(
            padding: EdgeInsets.all(15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Back to Timer',
              style: TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 15),
        // Help button
        GestureDetector(
          onTap: () {
            _speak("Help. Double tap to hear usage instructions.");
          },
          onDoubleTap: () {
            _speak(
              "App usage instructions. "
              "On the timer screen, swipe up or down to adjust hours, minutes, and seconds. "
              "Double tap to start or pause the timer. "
              "Swipe right to open the settings menu. "
              "Swipe left to hear the remaining time. "
              "Tap once on buttons to hear their function, double tap to activate them. "
              "In the settings menu, you can adjust speech rate, speech volume, "
              "enable or disable vibration, and set the time announcement interval."
            );
          },
          child: Container(
            padding: EdgeInsets.all(15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Help',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _speakRemainingTime();
          } else if (details.primaryVelocity! < 0) {
            _toggleSettings();
          }
        },
        onDoubleTap: !_isSettingsOpen ? _startOrPauseTimer : null,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          padding: EdgeInsets.all(20),
          child: _isSettingsOpen
              ? _buildSettingsPanel()
              : (_isRunning ? _buildRunningTimer() : _buildTimeSelector()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    flutterTts.stop();
    super.dispose();
  }
}
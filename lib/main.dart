import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

late List<CameraDescription> cameras;

// Theme Notifier for managing dark mode
class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference();
    notifyListeners();
  }
  
  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    _saveThemePreference();
    notifyListeners();
  }
  
  Future<void> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;
    notifyListeners();
  }
  
  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_enabled', _isDarkMode);
  }
}

// Global theme notifier instance
final themeNotifier = ThemeNotifier();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  
  // Load theme preference
  await themeNotifier.loadThemePreference();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Fruit Freshness Detector',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4CAF50),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4CAF50),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          themeMode: themeNotifier.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              .animate(controller: _controller)
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
                duration: const Duration(seconds: 1),
              )
              .then()
              .shimmer(
                duration: const Duration(seconds: 1),
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 32),
              Text(
                'Fruit Freshness',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 500), duration: const Duration(milliseconds: 800))
              .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Detect freshness with AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 700), duration: const Duration(milliseconds: 800))
              .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Fruit Freshness',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: themeNotifier,
                    builder: (context, child) {
                      return IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            themeNotifier.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            key: ValueKey(themeNotifier.isDarkMode),
                          ),
                        ),
                        onPressed: () {
                          themeNotifier.toggleTheme();
                        },
                        tooltip: themeNotifier.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.camera_alt_outlined),
                    text: 'Scan',
                  ),
                  Tab(
                    icon: Icon(Icons.history),
                    text: 'History',
                  ),
                  Tab(
                    icon: Icon(Icons.help_outline),
                    text: 'Guide',
                  ),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  ScanTab(),
                  HistoryTab(),
                  GuideTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with SingleTickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  String? _result;
  Color _resultColor = Colors.green;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = null;
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      // TODO: Replace with your actual API endpoint
      final apiUrl = 'https://fyp-fast-api-backend.onrender.com/predict';
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // Add file to request
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String prediction = data['prediction'];
        
        // Save to history
        _saveToHistory(_image!.path, prediction);
        
        // Set result color based on prediction
        Color resultColor;
        switch (prediction.toLowerCase()) {
          case 'ripe':
            resultColor = Colors.green;
            break;
          case 'unripe':
            resultColor = Colors.amber;
            break;
          case 'rotten':
            resultColor = Colors.red;
            break;
          default:
            resultColor = Colors.blue;
        }
        
        setState(() {
          _result = prediction;
          _resultColor = resultColor;
          _isAnalyzing = false;
        });
        
        _animationController.forward(from: 0.0);
      } else {
        setState(() {
          _result = 'Error: ${response.statusCode}';
          _resultColor = Colors.red;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _resultColor = Colors.red;
        _isAnalyzing = false;
      });
    }
  }
  
  Future<void> _saveToHistory(String imagePath, String result) async {
    try {
      // Copy image to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(imagePath).copy('${appDir.path}/$fileName');
      
      // Save scan data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('scan_history') ?? [];
      
      final scanData = json.encode({
        'image': savedImage.path,
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      history.add(scanData);
      await prefs.setStringList('scan_history', history);
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }

  Future<void> _shareResult() async {
    if (_image == null || _result == null) return;
    
    try {
      final XFile imageFile = XFile(_image!.path);
      await Share.shareXFiles(
        [imageFile],
        text: 'Fruit Freshness Analysis Result: $_result\n\nAnalyzed with Fruit Freshness Detector app 🍎',
        subject: 'Fruit Freshness Analysis',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _image == null
                ? Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Take or select a photo',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Capture a clear image of your fruit',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          _image!,
                          fit: BoxFit.cover,
                        ),
                        if (_result != null)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Curves.elasticOut,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      _resultColor.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Result',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                          Text(
                                            _result!,
                                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        onPressed: _shareResult,
                                        icon: const Icon(
                                          Icons.share,
                                          color: Colors.white,
                                        ),
                                        tooltip: 'Share Result',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_isAnalyzing)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Analyzing...',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please wait while we analyze your fruit',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.photo_camera,
                label: 'Camera',
                onPressed: () => _getImage(ImageSource.camera),
                color: Theme.of(context).colorScheme.primary,
              ),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: () => _getImage(ImageSource.gallery),
                color: Theme.of(context).colorScheme.secondary,
              ),
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Reset',
                onPressed: _image == null
                    ? null
                    : () {
                        setState(() {
                          _image = null;
                          _result = null;
                        });
                      },
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _image == null || _isAnalyzing ? null : _analyzeImage,
            icon: _isAnalyzing 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.psychology),
            label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Freshness'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )
          .animate(target: _image != null && !_isAnalyzing ? 1 : 0)
          .shimmer(duration: const Duration(seconds: 2), delay: const Duration(seconds: 1))
          .shake(hz: 2, curve: Curves.easeInOut),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color),
            iconSize: 28,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = prefs.getStringList('scan_history') ?? [];
      
      final history = historyData.map((item) {
        final data = json.decode(item) as Map<String, dynamic>;
        return data;
      }).toList();
      
      // Sort by timestamp (newest first)
      history.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] as String);
        final bTime = DateTime.parse(b['timestamp'] as String);
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all scan history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scan_history');
      
      setState(() {
        _history = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    }
  }

  Future<void> _shareHistoryItem(Map<String, dynamic> item) async {
    try {
      final XFile imageFile = XFile(item['image'] as String);
      final timestamp = DateTime.parse(item['timestamp'] as String);
      final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
      
      await Share.shareXFiles(
        [imageFile],
        text: 'Fruit Freshness Analysis Result: ${item['result']}\nAnalyzed on: $formattedDate\n\nShared from Fruit Freshness Detector app 🍎',
        subject: 'Fruit Freshness Analysis Result',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No scan history',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your scan results will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Scan History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final timestamp = DateTime.parse(item['timestamp'] as String);
              final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
              
              Color resultColor;
              IconData resultIcon;
              switch ((item['result'] as String).toLowerCase()) {
                case 'ripe':
                  resultColor = Colors.green;
                  resultIcon = Icons.check_circle;
                  break;
                case 'unripe':
                  resultColor = Colors.amber;
                  resultIcon = Icons.schedule;
                  break;
                case 'rotten':
                  resultColor = Colors.red;
                  resultIcon = Icons.cancel;
                  break;
                default:
                  resultColor = Colors.blue;
                  resultIcon = Icons.help;
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResultDetailPage(
                          imagePath: item['image'] as String,
                          result: item['result'] as String,
                          timestamp: timestamp,
                          resultColor: resultColor,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Image.file(
                              File(item['image'] as String),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    resultIcon,
                                    color: resultColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: resultColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item['result'] as String,
                                      style: TextStyle(
                                        color: resultColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formattedDate,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _shareHistoryItem(item),
                          icon: const Icon(Icons.share_outlined),
                          tooltip: 'Share',
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: index * 50),
              )
              .slideX(
                begin: 0.1,
                end: 0,
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: index * 50),
                curve: Curves.easeOutCubic,
              );
            },
          ),
        ),
      ],
    );
  }
}

class GuideTab extends StatelessWidget {
  const GuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Text(
          'How to Use',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildGuideItem(
          context,
          icon: Icons.camera_alt,
          title: 'Take a Photo',
          description: 'Capture a clear image of the fruit you want to analyze.',
          color: Theme.of(context).colorScheme.primary,
        ),
        _buildGuideItem(
          context,
          icon: Icons.psychology,
          title: 'Analyze',
          description: 'Tap the analyze button to check the freshness level.',
          color: Theme.of(context).colorScheme.secondary,
        ),
        _buildGuideItem(
          context,
          icon: Icons.share,
          title: 'Share Results',
          description: 'Share your analysis results with others directly from the app.',
          color: Theme.of(context).colorScheme.tertiary,
        ),
        _buildGuideItem(
          context,
          icon: Icons.history,
          title: 'View History',
          description: 'Check your previous scans in the history tab.',
          color: Colors.orange,
        ),
        const SizedBox(height: 32),
        Text(
          'Freshness Levels',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildFreshnessLevel(
          context,
          color: Colors.green,
          icon: Icons.check_circle,
          title: 'Ripe',
          description: 'Perfect for consumption. The fruit is at its peak freshness.',
        ),
        _buildFreshnessLevel(
          context,
          color: Colors.amber,
          icon: Icons.schedule,
          title: 'Unripe',
          description: 'Not ready for consumption yet. Wait a few days.',
        ),
        _buildFreshnessLevel(
          context,
          color: Colors.red,
          icon: Icons.cancel,
          title: 'Rotten',
          description: 'Not suitable for consumption. Discard the fruit.',
        ),
        const SizedBox(height: 32),
        Text(
          'Tips for Best Results',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTipItem(
                  context,
                  icon: Icons.lightbulb_outline,
                  title: 'Good Lighting',
                  subtitle: 'Take photos in well-lit environments for accurate results.',
                ),
                const SizedBox(height: 16),
                _buildTipItem(
                  context,
                  icon: Icons.center_focus_strong,
                  title: 'Clear Focus',
                  subtitle: 'Ensure the fruit is clearly visible and in focus.',
                ),
                const SizedBox(height: 16),
                _buildTipItem(
                  context,
                  icon: Icons.crop_free,
                  title: 'Proper Framing',
                  subtitle: 'Frame the entire fruit in the image for best analysis.',
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: themeNotifier,
                  builder: (context, child) {
                    return _buildTipItem(
                      context,
                      icon: themeNotifier.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      title: 'Dark Mode',
                      subtitle: 'Toggle between light and dark themes for comfortable viewing.',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ]
      .animate(interval: const Duration(milliseconds: 100))
      .fadeIn(duration: const Duration(milliseconds: 400))
      .slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildGuideItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildFreshnessLevel(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ResultDetailPage extends StatelessWidget {
  final String imagePath;
  final String result;
  final DateTime timestamp;
  final Color resultColor;

  const ResultDetailPage({
    super.key,
    required this.imagePath,
    required this.result,
    required this.timestamp,
    required this.resultColor,
  });

  Future<void> _shareResult(BuildContext context) async {
    try {
      final XFile imageFile = XFile(imagePath);
      final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(timestamp);
      
      await Share.shareXFiles(
        [imageFile],
        text: 'Fruit Freshness Analysis Result: $result\nAnalyzed on: $formattedDate\n\nShared from Fruit Freshness Detector app 🍎',
        subject: 'Fruit Freshness Analysis Result',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(timestamp);
    
    String recommendation;
    IconData resultIcon;
    switch (result.toLowerCase()) {
      case 'ripe':
        recommendation = 'This fruit is perfect for consumption now. Enjoy it at its peak freshness!';
        resultIcon = Icons.check_circle;
        break;
      case 'unripe':
        recommendation = 'This fruit needs more time to ripen. Store it at room temperature for a few days.';
        resultIcon = Icons.schedule;
        break;
      case 'rotten':
        recommendation = 'This fruit is not suitable for consumption. It\'s best to discard it.';
        resultIcon = Icons.cancel;
        break;
      default:
        recommendation = 'Check the fruit\'s appearance, smell, and texture to determine its freshness.';
        resultIcon = Icons.help;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(context),
            tooltip: 'Share Result',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: imagePath,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(File(imagePath)),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          resultIcon,
                          color: resultColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: resultColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Confidence: 95%',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Recommendation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: resultColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.lightbulb,
                              color: resultColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              recommendation,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Nutritional Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildNutritionItem(
                            context,
                            icon: Icons.local_fire_department,
                            title: 'Calories',
                            value: '52 kcal',
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          _buildNutritionItem(
                            context,
                            icon: Icons.water_drop,
                            title: 'Water',
                            value: '86%',
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          _buildNutritionItem(
                            context,
                            icon: Icons.grain,
                            title: 'Fiber',
                            value: '2.4g',
                            color: Colors.brown,
                          ),
                          const SizedBox(height: 16),
                          _buildNutritionItem(
                            context,
                            icon: Icons.bolt,
                            title: 'Vitamin C',
                            value: '8.7mg',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _shareResult(context),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Result'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  Widget _buildNutritionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _apiEndpoint = 'https://fyp-fast-api-backend.onrender.com/predict';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _apiEndpoint = prefs.getString('api_endpoint') ?? 'https://fyp-fast-api-backend.onrender.com/predict';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('api_endpoint', _apiEndpoint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.api,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('API Endpoint'),
                  subtitle: Text(_apiEndpoint),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final controller = TextEditingController(text: _apiEndpoint);
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('API Endpoint'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter API endpoint URL',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(controller.text),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    
                    if (result != null && result.isNotEmpty) {
                      setState(() {
                        _apiEndpoint = result;
                      });
                      await _saveSettings();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: themeNotifier,
                  builder: (context, child) {
                    return SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme'),
                      value: themeNotifier.isDarkMode,
                      onChanged: (value) {
                        themeNotifier.setTheme(value);
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          themeNotifier.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive alerts about scan results'),
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    await _saveSettings();
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                    ),
                  ),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Fruit Freshness Detector',
                      applicationVersion: '1.0.0',
                      applicationIcon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.eco_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      children: [
                        const Text(
                          'This app uses machine learning to detect the freshness level of fruits and vegetables. Share your results with friends and family!',
                        ),
                      ],
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help & Support coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text('Share App'),
                  subtitle: const Text('Tell others about this app'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Share.share(
                      'Check out the Fruit Freshness Detector app! 🍎 It uses AI to analyze the freshness of fruits and vegetables. Download it now!',
                      subject: 'Fruit Freshness Detector App',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

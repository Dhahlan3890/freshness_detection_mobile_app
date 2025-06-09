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

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
    return MaterialApp(
      title: 'Fruit Freshness Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
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
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
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
            const SizedBox(height: 24),
            Text(
              'Fruit Freshness',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
              style: Theme.of(context).textTheme.bodyLarge,
            )
            .animate()
            .fadeIn(delay: const Duration(milliseconds: 700), duration: const Duration(milliseconds: 800))
            .slideY(begin: 0.2, end: 0),
          ],
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.eco_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fruit Freshness',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Scan'),
                Tab(text: 'History'),
                Tab(text: 'Guide'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              indicatorColor: Theme.of(context).colorScheme.primary,
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
    final pickedFile = await picker.pickImage(source: source);

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _image == null
                ? Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Take or select a photo',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _resultColor.withOpacity(0.8),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _result!,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        if (_isAnalyzing)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Analyzing...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
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
              ),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: () => _getImage(ImageSource.gallery),
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
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _image == null || _isAnalyzing ? null : _analyzeImage,
            icon: const Icon(Icons.search),
            label: const Text('Analyze Freshness'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          heroTag: label,
          child: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(label),
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
          TextButton(
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
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No scan history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Your scan results will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Scan History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final timestamp = DateTime.parse(item['timestamp'] as String);
              final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
              
              Color resultColor;
              switch ((item['result'] as String).toLowerCase()) {
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
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
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
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Image.file(
                          File(item['image'] as String),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: resultColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  item['result'] as String,
                                  style: TextStyle(
                                    color: resultColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formattedDate,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.chevron_right),
                      ),
                    ],
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
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'How to Use',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildGuideItem(
          context,
          icon: Icons.photo_camera,
          title: 'Take a Photo',
          description: 'Capture a clear image of the fruit you want to analyze.',
        ),
        _buildGuideItem(
          context,
          icon: Icons.search,
          title: 'Analyze',
          description: 'Tap the analyze button to check the freshness level.',
        ),
        _buildGuideItem(
          context,
          icon: Icons.history,
          title: 'View History',
          description: 'Check your previous scans in the history tab.',
        ),
        const SizedBox(height: 32),
        Text(
          'Freshness Levels',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFreshnessLevel(
          context,
          color: Colors.green,
          title: 'Ripe',
          description: 'Perfect for consumption. The fruit is at its peak freshness.',
        ),
        _buildFreshnessLevel(
          context,
          color: Colors.amber,
          title: 'Unripe',
          description: 'Not ready for consumption yet. Wait a few days.',
        ),
        _buildFreshnessLevel(
          context,
          color: Colors.red,
          title: 'Rotten',
          description: 'Not suitable for consumption. Discard the fruit.',
        ),
        const SizedBox(height: 32),
        Text(
          'Tips for Best Results',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Good Lighting'),
                  subtitle: const Text('Take photos in well-lit environments for accurate results.'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.center_focus_strong),
                  title: const Text('Clear Focus'),
                  subtitle: const Text('Ensure the fruit is clearly visible and in focus.'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.crop_free),
                  title: const Text('Proper Framing'),
                  subtitle: const Text('Frame the entire fruit in the image for best analysis.'),
                  contentPadding: EdgeInsets.zero,
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
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

  Widget _buildFreshnessLevel(
    BuildContext context, {
    required Color color,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
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

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(timestamp);
    
    String recommendation;
    switch (result.toLowerCase()) {
      case 'ripe':
        recommendation = 'This fruit is perfect for consumption now. Enjoy it at its peak freshness!';
        break;
      case 'unripe':
        recommendation = 'This fruit needs more time to ripen. Store it at room temperature for a few days.';
        break;
      case 'rotten':
        recommendation = 'This fruit is not suitable for consumption. It\'s best to discard it.';
        break;
      default:
        recommendation = 'Check the fruit\'s appearance, smell, and texture to determine its freshness.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: imagePath,
              child: Image.file(
                File(imagePath),
                height: 300,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: resultColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Confidence: 95%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recommendation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: resultColor,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(recommendation),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nutritional Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildNutritionItem(
                            context,
                            icon: Icons.local_fire_department,
                            title: 'Calories',
                            value: '52 kcal',
                          ),
                          const Divider(),
                          _buildNutritionItem(
                            context,
                            icon: Icons.water_drop,
                            title: 'Water',
                            value: '86%',
                          ),
                          const Divider(),
                          _buildNutritionItem(
                            context,
                            icon: Icons.grain,
                            title: 'Fiber',
                            value: '2.4g',
                          ),
                          const Divider(),
                          _buildNutritionItem(
                            context,
                            icon: Icons.bolt,
                            title: 'Vitamin C',
                            value: '8.7mg',
                          ),
                        ],
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
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
      ),
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
  bool _darkModeEnabled = false;
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
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _apiEndpoint = prefs.getString('api_endpoint') ?? 'https://fyp-fast-api-backend.onrender.com/predict';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
    await prefs.setString('api_endpoint', _apiEndpoint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API Endpoint'),
            subtitle: Text(_apiEndpoint),
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
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
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
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkModeEnabled,
            onChanged: (value) async {
              setState(() {
                _darkModeEnabled = value;
              });
              await _saveSettings();
              // Note: In a real app, you would use a theme provider to change the theme
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Fruit Freshness Detector',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.eco_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                children: [
                  const Text(
                    'This app uses machine learning to detect the freshness level of fruits and vegetables.',
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              // TODO: Implement help and support
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

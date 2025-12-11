import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
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

// Helper function to parse Python-like dictionary from header
Map<String, dynamic> parsePythonDict(String pythonDictStr) {
  try {
    print('Attempting to parse: $pythonDictStr');
    
    // First try to parse as JSON (in case it's already valid JSON with double quotes)
    try {
      var result = json.decode(pythonDictStr);
      print('Successfully parsed as JSON: $result');
      return Map<String, dynamic>.from(result);
    } catch (jsonError) {
      print('JSON parsing failed, trying Python dict parsing: $jsonError');
    }
    
    // Remove outer braces and spaces
    String cleaned = pythonDictStr.trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    
    Map<String, dynamic> result = {};
    
    // Split by comma, but be careful with nested structures
    List<String> pairs = [];
    int braceCount = 0;
    int quoteCount = 0;
    String currentPair = '';
    
    for (int i = 0; i < cleaned.length; i++) {
      String char = cleaned[i];
      
      if (char == "'" && (i == 0 || cleaned[i-1] != '\\')) {
        quoteCount++;
      } else if (char == '{') {
        braceCount++;
      } else if (char == '}') {
        braceCount--;
      } else if (char == ',' && braceCount == 0 && quoteCount % 2 == 0) {
        pairs.add(currentPair.trim());
        currentPair = '';
        continue;
      }
      
      currentPair += char;
    }
    
    if (currentPair.trim().isNotEmpty) {
      pairs.add(currentPair.trim());
    }
    
    // Parse each key-value pair
    for (String pair in pairs) {
      List<String> parts = pair.split(':');
      if (parts.length >= 2) {
        String key = parts[0].trim();
        String value = parts.sublist(1).join(':').trim();
        
        // Remove quotes from key and value
        key = key.replaceAll("'", "").replaceAll('"', '');
        value = value.replaceAll("'", "").replaceAll('"', '');
        
        result[key] = value;
      }
    }
    
    print('Successfully parsed as Python dict: $result');
    return result;
  } catch (e) {
    print('Error parsing Python dict: $e');
    print('Input was: $pythonDictStr');
    return {};
  }
}

// Helper function to parse complex nutrition data with nested objects and arrays
Map<String, dynamic> parseNutritionData(String nutritionStr) {
  try {
    print('Attempting to parse nutrition data: $nutritionStr');
    
    // First try to parse as JSON directly
    try {
      var result = json.decode(nutritionStr);
      print('Successfully parsed nutrition as JSON: $result');
      return Map<String, dynamic>.from(result);
    } catch (jsonError) {
      print('JSON parsing failed for nutrition data, trying manual parsing: $jsonError');
    }
    
    // Manual parsing for Python-like dictionary with complex nested structures
    String cleaned = nutritionStr.trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    
    Map<String, dynamic> result = {};
    
    // Parse main key-value pairs (e.g., "1: [{'name': 'Banana'...}]")
    List<String> mainPairs = _splitTopLevelPairs(cleaned);
    
    for (String pair in mainPairs) {
      int colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        String key = pair.substring(0, colonIndex).trim();
        String value = pair.substring(colonIndex + 1).trim();
        
        // Remove quotes from key
        key = key.replaceAll("'", "").replaceAll('"', '');
        
        // Parse the value (which should be an array of objects)
        if (value.startsWith('[') && value.endsWith(']')) {
          result[key] = _parseNutritionArray(value);
        }
      }
    }
    
    print('Successfully parsed nutrition data: $result');
    return result;
  } catch (e) {
    print('Error parsing nutrition data: $e');
    print('Input was: $nutritionStr');
    return {};
  }
}

// Helper function to split top-level key-value pairs
List<String> _splitTopLevelPairs(String str) {
  List<String> pairs = [];
  String currentPair = '';
  int bracketCount = 0;
  int braceCount = 0;
  bool inQuotes = false;
  bool inSingleQuotes = false;
  
  for (int i = 0; i < str.length; i++) {
    String char = str[i];
    
    if (char == '"' && !inSingleQuotes && (i == 0 || str[i-1] != '\\')) {
      inQuotes = !inQuotes;
    } else if (char == "'" && !inQuotes && (i == 0 || str[i-1] != '\\')) {
      inSingleQuotes = !inSingleQuotes;
    } else if (!inQuotes && !inSingleQuotes) {
      if (char == '[') {
        bracketCount++;
      } else if (char == ']') {
        bracketCount--;
      } else if (char == '{') {
        braceCount++;
      } else if (char == '}') {
        braceCount--;
      } else if (char == ',' && bracketCount == 0 && braceCount == 0) {
        if (currentPair.trim().isNotEmpty) {
          pairs.add(currentPair.trim());
        }
        currentPair = '';
        continue;
      }
    }
    
    currentPair += char;
  }
  
  if (currentPair.trim().isNotEmpty) {
    pairs.add(currentPair.trim());
  }
  
  return pairs;
}

// Helper function to parse nutrition array [{'name': 'Banana',...}]
List<Map<String, dynamic>> _parseNutritionArray(String arrayStr) {
  List<Map<String, dynamic>> result = [];
  
  // Remove outer brackets
  String cleaned = arrayStr.trim();
  if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  
  // Split array elements (objects)
  List<String> objects = _splitArrayObjects(cleaned);
  
  for (String objStr in objects) {
    if (objStr.startsWith('{') && objStr.endsWith('}')) {
      Map<String, dynamic> obj = _parseNutritionObject(objStr);
      if (obj.isNotEmpty) {
        result.add(obj);
      }
    }
  }
  
  return result;
}

// Helper function to split array objects
List<String> _splitArrayObjects(String str) {
  List<String> objects = [];
  String currentObj = '';
  int braceCount = 0;
  bool inQuotes = false;
  bool inSingleQuotes = false;
  
  for (int i = 0; i < str.length; i++) {
    String char = str[i];
    
    if (char == '"' && !inSingleQuotes && (i == 0 || str[i-1] != '\\')) {
      inQuotes = !inQuotes;
    } else if (char == "'" && !inQuotes && (i == 0 || str[i-1] != '\\')) {
      inSingleQuotes = !inSingleQuotes;
    } else if (!inQuotes && !inSingleQuotes) {
      if (char == '{') {
        braceCount++;
      } else if (char == '}') {
        braceCount--;
      } else if (char == ',' && braceCount == 0) {
        if (currentObj.trim().isNotEmpty) {
          objects.add(currentObj.trim());
        }
        currentObj = '';
        continue;
      }
    }
    
    currentObj += char;
  }
  
  if (currentObj.trim().isNotEmpty) {
    objects.add(currentObj.trim());
  }
  
  return objects;
}

// Helper function to parse individual nutrition object
Map<String, dynamic> _parseNutritionObject(String objStr) {
  Map<String, dynamic> result = {};
  
  // Remove outer braces
  String cleaned = objStr.trim();
  if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  
  // Parse key-value pairs within the object
  List<String> pairs = _splitObjectPairs(cleaned);
  
  for (String pair in pairs) {
    int colonIndex = pair.indexOf(':');
    if (colonIndex > 0) {
      String key = pair.substring(0, colonIndex).trim();
      String value = pair.substring(colonIndex + 1).trim();
      
      // Remove quotes from key
      key = key.replaceAll("'", "").replaceAll('"', '');
      
      // Parse value (could be string or array)
      if (value.startsWith('[') && value.endsWith(']')) {
        // Parse array value
        result[key] = _parseStringArray(value);
      } else {
        // Parse string value
        value = value.replaceAll("'", "").replaceAll('"', '');
        result[key] = value;
      }
    }
  }
  
  return result;
}

// Helper function to split object key-value pairs
List<String> _splitObjectPairs(String str) {
  List<String> pairs = [];
  String currentPair = '';
  int bracketCount = 0;
  bool inQuotes = false;
  bool inSingleQuotes = false;
  
  for (int i = 0; i < str.length; i++) {
    String char = str[i];
    
    if (char == '"' && !inSingleQuotes && (i == 0 || str[i-1] != '\\')) {
      inQuotes = !inQuotes;
    } else if (char == "'" && !inQuotes && (i == 0 || str[i-1] != '\\')) {
      inSingleQuotes = !inSingleQuotes;
    } else if (!inQuotes && !inSingleQuotes) {
      if (char == '[') {
        bracketCount++;
      } else if (char == ']') {
        bracketCount--;
      } else if (char == ',' && bracketCount == 0) {
        if (currentPair.trim().isNotEmpty) {
          pairs.add(currentPair.trim());
        }
        currentPair = '';
        continue;
      }
    }
    
    currentPair += char;
  }
  
  if (currentPair.trim().isNotEmpty) {
    pairs.add(currentPair.trim());
  }
  
  return pairs;
}

// Helper function to parse string arrays like ['item1', 'item2']
List<String> _parseStringArray(String arrayStr) {
  List<String> result = [];
  
  // Remove outer brackets
  String cleaned = arrayStr.trim();
  if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  
  if (cleaned.trim().isEmpty) {
    return result;
  }
  
  // Split by comma but respect quotes
  List<String> items = [];
  String currentItem = '';
  bool inQuotes = false;
  bool inSingleQuotes = false;
  
  for (int i = 0; i < cleaned.length; i++) {
    String char = cleaned[i];
    
    if (char == '"' && !inSingleQuotes && (i == 0 || cleaned[i-1] != '\\')) {
      inQuotes = !inQuotes;
    } else if (char == "'" && !inQuotes && (i == 0 || cleaned[i-1] != '\\')) {
      inSingleQuotes = !inSingleQuotes;
    } else if (char == ',' && !inQuotes && !inSingleQuotes) {
      if (currentItem.trim().isNotEmpty) {
        items.add(currentItem.trim());
      }
      currentItem = '';
      continue;
    }
    
    currentItem += char;
  }
  
  if (currentItem.trim().isNotEmpty) {
    items.add(currentItem.trim());
  }
  
  // Clean up each item
  for (String item in items) {
    String cleanItem = item.trim().replaceAll("'", "").replaceAll('"', '');
    if (cleanItem.isNotEmpty) {
      result.add(cleanItem);
    }
  }
  
  return result;
}

// Zoomable Image Widget for displaying prediction results
class ZoomableImage extends StatelessWidget {
  final File imageFile;
  final Widget? overlay;
  final double? height;

  const ZoomableImage({
    super.key,
    required this.imageFile,
    this.overlay,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ZoomableImageViewer(
              imageFile: imageFile,
              overlay: overlay,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: Container(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                imageFile,
                fit: BoxFit.cover,
              ),
              if (overlay != null) overlay!,
              // Tap indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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

// Full screen zoomable image viewer
class ZoomableImageViewer extends StatefulWidget {
  final File imageFile;
  final Widget? overlay;

  const ZoomableImageViewer({
    super.key,
    required this.imageFile,
    this.overlay,
  });

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer> {
  final TransformationController _transformationController = TransformationController();
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Prediction Results'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetZoom,
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Stack(
                children: [
                  Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                  if (widget.overlay != null) widget.overlay!,
                ],
              ),
            ),
          ),
          // Instructions overlay
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pinch to zoom • Drag to pan • Tap reset to fit screen',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          title: 'AI Food Assistant',
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
          pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
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
                'AI Food Assistant',
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
                'Smart nutrition & freshness analysis',
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

class MainPage extends StatelessWidget {
  const MainPage({super.key});

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
                    'AI Food Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to AI Food Assistant',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: const Duration(milliseconds: 600))
                    .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a feature to get started with smart food analysis',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: const Duration(milliseconds: 200), duration: const Duration(milliseconds: 600))
                    .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 32),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildFeatureCard(
                          context,
                          icon: Icons.eco_outlined,
                          title: 'Freshness\nClassification',
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FreshnessClassificationPage(),
                              ),
                            );
                          },
                          index: 0,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.science_outlined,
                          title: 'Natural vs\nArtificial',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NaturalArtificialPage(),
                              ),
                            );
                          },
                          index: 1,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.restaurant_menu_outlined,
                          title: 'Nutrition\nFinder',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NutritionFinderPage(),
                              ),
                            );
                          },
                          index: 2,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.psychology_outlined,
                          title: 'Food\nSuggestions',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FoodSuggestionsPage(),
                              ),
                            );
                          },
                          index: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.lightbulb_outline,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Quick Tips',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '• Take clear, well-lit photos for better analysis\n'
                              '• Use the fruit selection feature for group photos\n'
                              '• Check nutrition info to make healthier choices\n'
                              '• Get personalized suggestions based on your needs',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: const Duration(milliseconds: 800), duration: const Duration(milliseconds: 600))
                    .slideY(begin: 0.2, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
                FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1,
                  ),
                ),
                
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(
      delay: Duration(milliseconds: 300 + (index * 100)),
      duration: const Duration(milliseconds: 600),
    )
    .slideY(
      begin: 0.2,
      end: 0,
      delay: Duration(milliseconds: 300 + (index * 100)),
      duration: const Duration(milliseconds: 600),
    )
    .scale(
      begin: const Offset(0.8, 0.8),
      end: const Offset(1.0, 1.0),
      delay: Duration(milliseconds: 300 + (index * 100)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
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
      // API endpoint for freshness detection
      final apiUrl = 'https://stable-famous-flea.ngrok-free.app/predict';
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // Add file to request
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        // Get ripeness data from response headers
        String ripenessHeader = response.headers['ripeness'] ?? '{}';
        
        // Parse the ripeness data using the helper function
        Map<String, dynamic> ripenessData = parsePythonDict(ripenessHeader);
        
        // Debug logging
        print('Raw ripeness header: $ripenessHeader');
        print('Parsed ripeness data: $ripenessData');
        
        // Extract results for display
        String resultText = '';
        Color resultColor = Colors.blue;
        
        if (ripenessData.isNotEmpty) {
          List<String> detections = [];
          ripenessData.forEach((id, value) {
            detections.add('$id: ${value.toString()}');
          });
          resultText = detections.join('\n');
          
          // Set color based on detections
          String allResults = ripenessData.values.join(' ').toLowerCase();
          if (allResults.contains('fresh') || allResults.contains('ripe')) {
            resultColor = Colors.green;
          } else if (allResults.contains('intermediate') || allResults.contains('unripe')) {
            resultColor = Colors.amber;
          } else if (allResults.contains('rotten')) {
            resultColor = Colors.red;
          }
        } else {
          resultText = 'No detections found';
        }
        
        // Save the processed image with bounding boxes
        if (response.bodyBytes.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(imagePath);
          await file.writeAsBytes(response.bodyBytes);
          
          setState(() {
            _image = file; // Update with processed image
          });
        }
        
        // Save to history
        _saveToHistory(_image!.path, resultText);
        
        setState(() {
          _result = resultText;
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
                : Stack(
                    children: [
                      ZoomableImage(
                        imageFile: _image!,
                        overlay: _result != null
                            ? Positioned(
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
                              )
                            : null,
                      ),
                      if (_isAnalyzing)
                        Positioned.fill(
                          child: Container(
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
                        ),
                    ],
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
  String _apiEndpoint = 'https://stable-famous-flea.ngrok-free.app/predict';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _apiEndpoint = prefs.getString('api_endpoint') ?? 'https://stable-famous-flea.ngrok-free.app/predict';
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

// Freshness Classification Page with Object Detection
class FreshnessClassificationPage extends StatefulWidget {
  const FreshnessClassificationPage({super.key});

  @override
  State<FreshnessClassificationPage> createState() => _FreshnessClassificationPageState();
}

class _FreshnessClassificationPageState extends State<FreshnessClassificationPage> with SingleTickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  late AnimationController _animationController;
  Map<String, dynamic>? _freshnessData;
  
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
        _freshnessData = null;
        _isAnalyzing = false;
      });
      
      // Automatically analyze the image when selected
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
      _freshnessData = null;
    });

    try {
      // API endpoint for freshness detection
      final apiUrl = 'https://stable-famous-flea.ngrok-free.app/predict';
      
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        // Get ripeness data from response headers
        String ripenessHeader = response.headers['ripeness'] ?? '{}';
        
        // Parse the ripeness data using the helper function
        Map<String, dynamic> ripenessData = parsePythonDict(ripenessHeader);
        
        // Debug logging
        print('Raw ripeness header: $ripenessHeader');
        print('Parsed ripeness data: $ripenessData');
        
        // Save the processed image with bounding boxes
        if (response.bodyBytes.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/freshness_analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(imagePath);
          await file.writeAsBytes(response.bodyBytes);
          
          setState(() {
            _image = file; // Update with processed image showing bounding boxes
          });
        }
        
        setState(() {
          _freshnessData = ripenessData;
          _isAnalyzing = false;
        });
        
        _animationController.forward(from: 0.0);
      } else {
        setState(() {
          _freshnessData = {'error': 'Error: ${response.statusCode}'};
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _freshnessData = {'error': 'Error: $e'};
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freshness Classification'),
        backgroundColor: Colors.green.withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: _freshnessData != null ? 3 : 4,
              child: _image == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.eco_outlined,
                                size: 48,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Select fruit to analyze',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI will detect and classify fruit freshness',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        ZoomableImage(imageFile: _image!),
                        if (_isAnalyzing)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 16),
                                    Text(
                                      'Analyzing freshness...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onPressed: () => _getImage(ImageSource.camera),
                  color: Colors.green,
                ),
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: () => _getImage(ImageSource.gallery),
                  color: Colors.green.shade600,
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  onPressed: _image == null
                      ? null
                      : () {
                          setState(() {
                            _image = null;
                            _freshnessData = null;
                          });
                        },
                  color: Colors.green.shade700,
                ),
              ],
            ),
            // Results Section
            if (_freshnessData != null) ...[
              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: _buildFreshnessResults(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreshnessResults() {
    if (_freshnessData!.containsKey('error')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _freshnessData!['error'],
                style: TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_freshnessData!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No freshness detected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try uploading a clearer image with visible fruits.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(minHeight: 300),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.eco,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Analysis',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _freshnessData!.length,
                  itemBuilder: (context, index) {
                    final entry = _freshnessData!.entries.elementAt(index);
                    final id = entry.key;
                    final freshness = entry.value.toString();
                    
                    Color statusColor = _getFreshnessColor(freshness);
                    IconData statusIcon = _getFreshnessIcon(freshness);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Item $id',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  freshness.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFreshnessColor(String freshness) {
    final lowerFreshness = freshness.toLowerCase();
    if (lowerFreshness.contains('fresh') || lowerFreshness.contains('ripe')) {
      return Colors.green;
    } else if (lowerFreshness.contains('intermediate') || lowerFreshness.contains('unripe')) {
      return Colors.amber;
    } else if (lowerFreshness.contains('rotten') || lowerFreshness.contains('overripe')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  IconData _getFreshnessIcon(String freshness) {
    final lowerFreshness = freshness.toLowerCase();
    if (lowerFreshness.contains('fresh') || lowerFreshness.contains('ripe')) {
      return Icons.check_circle;
    } else if (lowerFreshness.contains('intermediate') || lowerFreshness.contains('unripe')) {
      return Icons.access_time;
    } else if (lowerFreshness.contains('rotten') || lowerFreshness.contains('overripe')) {
      return Icons.dangerous;
    }
    return Icons.help_outline;
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



// Natural vs Artificial Detection Page
class NaturalArtificialPage extends StatefulWidget {
  const NaturalArtificialPage({super.key});

  @override
  State<NaturalArtificialPage> createState() => _NaturalArtificialPageState();
}

class _NaturalArtificialPageState extends State<NaturalArtificialPage> with SingleTickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  late AnimationController _animationController;
  Map<String, dynamic>? _classificationData;
  
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
        _classificationData = null;
        _isAnalyzing = false;
      });
      
      // Automatically analyze the image when selected
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
      _classificationData = null;
    });

    try {
      // API endpoint for natural vs artificial detection
      final apiUrl = 'https://stable-famous-flea.ngrok-free.app/natural-artificial';
      
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        // Get freshness data from response headers
        String freshnessHeader = response.headers['freshness'] ?? '{}';
        
        // Parse the freshness data using the helper function
        Map<String, dynamic> freshnessData = parsePythonDict(freshnessHeader);
        
        // Debug logging
        print('Raw freshness header: $freshnessHeader');
        print('Parsed freshness data: $freshnessData');
        
        // Save the processed image with bounding boxes
        if (response.bodyBytes.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/natural_artificial_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(imagePath);
          await file.writeAsBytes(response.bodyBytes);
          
          setState(() {
            _image = file; // Update with processed image showing bounding boxes
          });
        }
        
        setState(() {
          _classificationData = freshnessData;
          _isAnalyzing = false;
        });
        
        _animationController.forward(from: 0.0);
        if (response.bodyBytes.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/natural_artificial_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(imagePath);
          await file.writeAsBytes(response.bodyBytes);
          
          setState(() {
            _image = file; // Update with processed image showing bounding boxes
          });
        }
        
        _animationController.forward(from: 0.0);
      } else {
        setState(() {
          _classificationData = {'error': 'Error: ${response.statusCode}'};
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _classificationData = {'error': 'Error: $e'};
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Natural vs Artificial'),
        backgroundColor: Colors.blue.withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: _classificationData != null ? 3 : 4,
              child: _image == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.science_outlined,
                                size: 48,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Detect Natural vs Artificial',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload fruit image to analyze',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        ZoomableImage(imageFile: _image!),
                        if (_isAnalyzing)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 16),
                                    Text(
                                      'Analyzing...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onPressed: () => _getImage(ImageSource.camera),
                  color: Colors.blue,
                ),
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: () => _getImage(ImageSource.gallery),
                  color: Colors.blue.shade600,
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  onPressed: _image == null
                      ? null
                      : () {
                          setState(() {
                            _image = null;
                            _classificationData = null;
                          });
                        },
                  color: Colors.blue.shade700,
                ),
              ],
            ),
            // Results Section
            if (_classificationData != null) ...[
              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: _buildClassificationResults(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationResults() {
    if (_classificationData!.containsKey('error')) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _classificationData!['error'],
                  style: TextStyle(color: Colors.red, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_classificationData!.isEmpty) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  'No classification detected',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Try uploading a clearer image with visible fruits.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(minHeight: 300),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.science,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Results',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _classificationData!.length,
                  itemBuilder: (context, index) {
                    final entry = _classificationData!.entries.elementAt(index);
                    final id = entry.key;
                    final classification = entry.value.toString();
                    
                    Color statusColor = _getClassificationColor(classification);
                    IconData statusIcon = _getClassificationIcon(classification);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Item $id',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  classification.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getClassificationColor(String classification) {
    final lowerClassification = classification.toLowerCase();
    if (lowerClassification.contains('natural')) {
      return Colors.green;
    } else if (lowerClassification.contains('artificial')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  IconData _getClassificationIcon(String classification) {
    final lowerClassification = classification.toLowerCase();
    if (lowerClassification.contains('natural')) {
      return Icons.nature;
    } else if (lowerClassification.contains('artificial')) {
      return Icons.precision_manufacturing;
    }
    return Icons.help_outline;
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

// Nutrition Finder Page
class NutritionFinderPage extends StatefulWidget {
  const NutritionFinderPage({super.key});

  @override
  State<NutritionFinderPage> createState() => _NutritionFinderPageState();
}

class _NutritionFinderPageState extends State<NutritionFinderPage> {
  File? _image;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _nutritionData;
  
  @override
  void dispose() {
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
        _nutritionData = null;
        _isAnalyzing = false;
      });
      
      // Automatically analyze the image when selected
      _analyzeNutrition();
    }
  }

  Future<void> _analyzeNutrition() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
      _nutritionData = null;
    });

    try {
      // API endpoint for nutrition analysis
      final apiUrl = 'https://stable-famous-flea.ngrok-free.app/nutrition-analysis';
      
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        // Get nutrition data from response headers
        String nutritionHeader = response.headers['nutrition'] ?? '{}';
        
        // Parse the nutrition data using the specialized nutrition parser
        Map<String, dynamic> nutritionData = parseNutritionData(nutritionHeader);
        
        // Debug logging
        print('Raw nutrition header: $nutritionHeader');
        print('Parsed nutrition data: $nutritionData');
        
        // Process nutrition data for display
        Map<String, dynamic> processedData = {'foods': []};
        
        if (nutritionData.isNotEmpty) {
          List<dynamic> foodItems = [];
          nutritionData.forEach((id, nutritionList) {
            if (nutritionList is List && nutritionList.isNotEmpty) {
              foodItems.addAll(nutritionList);
            } else if (nutritionList is Map) {
              // Handle case where each ID maps to a single object instead of array
              foodItems.add(nutritionList);
            }
          });
          processedData['foods'] = foodItems;
        }
        
        // Save the processed image with bounding boxes
        if (response.bodyBytes.isNotEmpty) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/nutrition_analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File(imagePath);
          await file.writeAsBytes(response.bodyBytes);
          
          setState(() {
            _image = file; // Update with processed image showing bounding boxes
          });
        }
        
        setState(() {
          _nutritionData = processedData;
          _isAnalyzing = false;
        });
      } else {
        setState(() {
          _nutritionData = {'error': 'Error: ${response.statusCode}'};
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _nutritionData = {'error': 'Error: $e'};
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Finder'),
        backgroundColor: Colors.orange.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Food Image',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload an image of fruits or vegetables to get detailed nutrition information',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _image == null
                ? Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu_outlined,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          Text('Select food image', style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  )
                : ZoomableImage(
                    imageFile: _image!,
                    height: 200,
                  ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onPressed: () => _getImage(ImageSource.camera),
                  color: Colors.orange,
                ),
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onPressed: () => _getImage(ImageSource.gallery),
                  color: Colors.orange.shade600,
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  onPressed: _image == null
                      ? null
                      : () {
                          setState(() {
                            _image = null;
                            _nutritionData = null;
                          });
                        },
                  color: Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _image == null || _isAnalyzing 
                  ? null 
                  : _analyzeNutrition,
              icon: _isAnalyzing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.analytics),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Get Nutrition Info'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_nutritionData != null) ...[
              const SizedBox(height: 24),
              _buildNutritionResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionResults() {
    if (_nutritionData!.containsKey('error')) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _nutritionData!['error'],
                  style: TextStyle(color: Colors.red, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final foods = _nutritionData!['foods'] as List<dynamic>;

    if (foods.isEmpty) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  'No food items detected',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Try uploading a clearer image with visible food items.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: foods.map<Widget>((food) {
        final foodItem = food as Map<String, dynamic>;
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            foodItem['name']?.toString().toUpperCase() ?? 'Unknown Food',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          if (foodItem['calories'] != null)
                            Text(
                              '� ${foodItem['calories'].toString()}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (foodItem['nutrition'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🍎 Nutrition Information:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNutritionList(foodItem['nutrition']),
                      ],
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNutritionList(dynamic nutrition) {
    if (nutrition is List) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: nutrition.map<Widget>((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              item.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          nutrition.toString(),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
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

// Food Suggestions Page
class FoodSuggestionsPage extends StatefulWidget {
  const FoodSuggestionsPage({super.key});

  @override
  State<FoodSuggestionsPage> createState() => _FoodSuggestionsPageState();
}

class _FoodSuggestionsPageState extends State<FoodSuggestionsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  
  String _gender = 'Male';
  String _activityLevel = 'Moderate';
  String _goal = 'Maintain Weight';
  bool _isGenerating = false;
  Map<String, dynamic>? _suggestions;

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestions() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _suggestions = null;
    });

    try {
      // API endpoint for food suggestions
      final apiUrl = 'https://stable-famous-flea.ngrok-free.app/food-suggestions';
      
      // Create form data request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // Add form fields
      request.fields['age'] = _ageController.text;
      request.fields['gender'] = _gender;
      request.fields['height'] = _heightController.text;
      request.fields['weight'] = _weightController.text;
      request.fields['activity_level'] = _activityLevel;
      request.fields['goal'] = _goal;
      request.fields['allergies'] = _allergiesController.text;
      request.fields['health_conditions'] = _conditionsController.text;
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        setState(() {
          // Handle both array and object responses
          if (data is List && data.isNotEmpty) {
            _suggestions = data.first as Map<String, dynamic>;
          } else if (data is Map<String, dynamic>) {
            _suggestions = data;
          } else {
            _suggestions = {'error': 'Invalid response format'};
          }
          _isGenerating = false;
        });
      } else {
        setState(() {
          _suggestions = {'error': 'Error: ${response.statusCode}'};
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _suggestions = {'error': 'Error: $e'};
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Suggestions'),
        backgroundColor: Colors.purple.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Age',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.cake, size: 20),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your age';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                // prefixIcon: const Icon(Icons.person, size: 20),
                              ),
                              items: ['Male', 'Female', 'Other'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _gender = newValue!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Height (cm)',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.height, size: 20),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your height';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Weight (kg)',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.monitor_weight, size: 20),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your weight';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _activityLevel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Activity Level',
                          labelStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.fitness_center, size: 20),
                        ),
                        items: ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _activityLevel = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _goal,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Goal',
                          labelStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.flag, size: 20),
                        ),
                        items: ['Lose Weight', 'Maintain Weight', 'Gain Weight', 'Build Muscle'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _goal = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _allergiesController,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Allergies (optional)',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintText: 'e.g., nuts, dairy, gluten',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.warning, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _conditionsController,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Health Conditions (optional)',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintText: 'e.g., diabetes, hypertension',
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.medical_services, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isGenerating ? null : _generateSuggestions,
                icon: _isGenerating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.psychology),
                label: Text(_isGenerating ? 'Generating...' : 'Get Suggestions'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_suggestions != null) ...[
                const SizedBox(height: 24),
                _buildSuggestionsResults(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsResults() {
    if (_suggestions!.containsKey('error')) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _suggestions!['error'],
                  style: TextStyle(color: Colors.red, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // _suggestions now contains the first object from the array response
    Map<String, dynamic> suggestion = _suggestions!;

    // Check if suggestion has meaningful data
    if (suggestion.isEmpty || 
        (suggestion['breakfast_calories_per_day'] == null && 
         suggestion['lunch_calories_per_day'] == null &&
         suggestion['dinner_calories_per_day'] == null &&
         suggestion['snacks_calories_per_day'] == null)) {
      return Card(
        elevation: 4,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  'No suggestions generated',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please try again with different information.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Meal Plan Header
        Card(
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple, Colors.purple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Personalized Meal Plan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Daily Calories: ${_calculateTotalCalories(suggestion)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Breakfast
        _buildMealCard(
          title: 'Breakfast',
          calories: suggestion['breakfast_calories_per_day']?.toString() ?? 'N/A',
          example: suggestion['example_breakfast']?.toString() ?? 'No breakfast suggestion available',
          icon: Icons.wb_sunny,
          color: Colors.orange,
        ),
        
        const SizedBox(height: 12),
        
        // Lunch
        _buildMealCard(
          title: 'Lunch',
          calories: suggestion['lunch_calories_per_day']?.toString() ?? 'N/A',
          example: suggestion['example_lunch']?.toString() ?? 'No lunch suggestion available',
          icon: Icons.lunch_dining,
          color: Colors.green,
        ),
        
        const SizedBox(height: 12),
        
        // Dinner
        _buildMealCard(
          title: 'Dinner',
          calories: suggestion['dinner_calories_per_day']?.toString() ?? 'N/A',
          example: suggestion['example_dinner']?.toString() ?? 'No dinner suggestion available',
          icon: Icons.dinner_dining,
          color: Colors.blue,
        ),
        
        const SizedBox(height: 12),
        
        // Snacks
        _buildMealCard(
          title: 'Snacks',
          calories: suggestion['snacks_calories_per_day']?.toString() ?? 'N/A',
          example: suggestion['example_snacks']?.toString() ?? 'No snack suggestions available',
          icon: Icons.cookie,
          color: Colors.purple,
        ),
        
        const SizedBox(height: 16),
        
        // Foods to Avoid
        if (suggestion['need_to_avoid'] != null && suggestion['need_to_avoid'].toString().isNotEmpty) ...[
          Card(
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Foods to Avoid',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        suggestion['need_to_avoid'].toString(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _calculateTotalCalories(Map<String, dynamic> suggestion) {
    int total = 0;
    
    if (suggestion['breakfast_calories_per_day'] != null) {
      total += int.tryParse(suggestion['breakfast_calories_per_day'].toString()) ?? 0;
    }
    if (suggestion['lunch_calories_per_day'] != null) {
      total += int.tryParse(suggestion['lunch_calories_per_day'].toString()) ?? 0;
    }
    if (suggestion['dinner_calories_per_day'] != null) {
      total += int.tryParse(suggestion['dinner_calories_per_day'].toString()) ?? 0;
    }
    if (suggestion['snacks_calories_per_day'] != null) {
      total += int.tryParse(suggestion['snacks_calories_per_day'].toString()) ?? 0;
    }
    
    return total > 0 ? '$total calories' : 'N/A';
  }

  Widget _buildMealCard({
    required String title,
    required String calories,
    required String example,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '🔥 $calories calories',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Color.lerp(color, Colors.black, 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meal Example:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Color.lerp(color, Colors.black, 0.3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      example,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: Color.lerp(color, Colors.black, 0.4),
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
}

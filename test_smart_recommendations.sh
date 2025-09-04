#!/bin/bash

# Test script for Smart Recommendations system
echo "🧪 Testing Smart Recommendations System"
echo "======================================"
echo ""

# Source the smart recommendations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/shared/smart_recommendations.sh"

# Create a test Flutter project with patterns to detect
TEST_PROJECT="/tmp/flutter_test_smart_recommendations"
mkdir -p "$TEST_PROJECT/lib"

echo "📂 Creating test Flutter project with detectable patterns..."

# Create main.dart with setState patterns
cat > "$TEST_PROJECT/lib/main.dart" << 'EOF'
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int counter = 0;
  String userData = '';

  void incrementCounter() {
    setState(() {
      counter++;
    });
  }

  void updateUserData() async {
    setState(() {
      userData = 'Loading...';
    });
    
    // Manual HTTP call
    final response = await http.get(Uri.parse('https://api.example.com/user'));
    
    setState(() {
      userData = response.body;
    });
  }

  void saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('counter', counter);
    prefs.setString('userData', userData);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          padding: EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              margin: EdgeInsets.all(8),
              child: Column(
                children: [
                  Text('Counter: $counter'),
                  Text('User Data: $userData'),
                  Image.network('https://example.com/image.jpg'),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => SecondPage(),
            ));
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('Debug: Navigated to second page');
    return Scaffold(
      body: Text('Second Page'),
    );
  }
}
EOF

# Create auth service with manual authentication
cat > "$TEST_PROJECT/lib/auth_service.dart" << 'EOF'
class AuthService {
  static AuthService? _instance;
  
  static AuthService getInstance() {
    _instance ??= AuthService();
    return _instance!;
  }

  Future<bool> login(String email, String password) async {
    print('Attempting login...');
    // Manual authentication logic
    if (email.isNotEmpty && password.isNotEmpty) {
      return true;
    }
    return false;
  }

  void signOut() {
    print('User signed out');
  }
}
EOF

# Create form with multiple controllers
cat > "$TEST_PROJECT/lib/form_page.dart" << 'EOF'
import 'package:flutter/material.dart';

class FormPage extends StatefulWidget {
  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  void submitForm() {
    print('Name: ${nameController.text}');
    print('Email: ${emailController.text}');
    print('Phone: ${phoneController.text}');
    print('Address: ${addressController.text}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(controller: nameController),
          TextField(controller: emailController),
          TextField(controller: phoneController),
          TextField(controller: addressController),
        ],
      ),
    );
  }
}
EOF

# Create animation with manual controller
cat > "$TEST_PROJECT/lib/animated_widget.dart" << 'EOF'
import 'package:flutter/material.dart';

class AnimatedWidget extends StatefulWidget {
  @override
  _AnimatedWidgetState createState() => _AnimatedWidgetState();
}

class _AnimatedWidgetState extends State<AnimatedWidget> with TickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: Duration(seconds: 2), vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller);
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
EOF

echo "✅ Test project created at $TEST_PROJECT"
echo ""

# Run the smart recommendations analysis
echo "🔍 Running Smart Recommendations Analysis..."
echo ""

analyze_code_patterns "$TEST_PROJECT"

echo ""
echo "🧪 **Test Results:**"
echo "   The system should have detected:"
echo "   ✓ setState patterns (recommending Riverpod/Provider)"
echo "   ✓ SharedPreferences usage (recommending Hive)"
echo "   ✓ Manual HTTP calls (recommending Dio)"
echo "   ✓ Navigator.push usage (recommending GoRouter)"
echo "   ✓ Multiple Container widgets (recommending styling solutions)"
echo "   ✓ Multiple TextEditingController (recommending reactive forms)"
echo "   ✓ Manual authentication (recommending Firebase Auth)"
echo "   ✓ Print debugging (recommending Logger)"
echo "   ✓ Image.network usage (recommending cached_network_image)"
echo "   ✓ Manual animation controllers (recommending flutter_animate)"
echo "   ✓ Manual singleton pattern (recommending get_it)"
echo ""

# Cleanup
echo "🧹 Cleaning up test project..."
rm -rf "$TEST_PROJECT"
echo "✅ Test completed!"
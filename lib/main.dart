import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
// import 'package:lottie/lottie.dart';
// Firebase placeholders (add packages later)
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// ================= MODEL =================
class Animal {
  final String name;
  final String type;
  final String breed;
  final String age;
  final String description;
  final String image;
  final String vaccination;
  final String locality;
  final String contact;
  Animal({
    required this.name,
    required this.type,
    required this.breed,
    required this.age,
    required this.description,
    required this.image,
    required this.vaccination,
    required this.locality,
    required this.contact,
  });
}

// ======== HEALTH RECORD MODEL ========
class HealthRecord {
  final String petName;
  final String vaccination;
  final String medicalReport;
  final String date;

  HealthRecord({
    required this.petName,
    required this.vaccination,
    required this.medicalReport,
    required this.date,
  });
}

class AdoptionRequest {
  final String id;
  final String name;
  final String age;
  final String contact;
  final String email;
  final Animal? animal;
  String status; // Pending, Adopted, Declined

  AdoptionRequest({
    required this.id,
    required this.name,
    required this.age,
    required this.contact,
    required this.email,
    required this.animal,
    this.status = "Pending",
  });
}

class AppData {
  static List<AdoptionRequest> requests = [];
  static List<Animal> favorites = [];
  static List<Match> matches = [];
  static Map<String, List<Message>> chats = {};
  static List<HealthRecord> healthRecords = [];
}

// ========== MATCH & CHAT MODELS ==========
class Match {
  final Animal animal;
  Match(this.animal);
}

class Message {
  final String text;
  final bool isUser;
  Message(this.text, this.isUser);
}

// ================= MAIN =================
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    loadTheme();
    initNotifications();
  }

  // ================= THEME =================
  void toggleTheme() {
    setState(() {
      isDark = !isDark;
    });
    saveTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDark = prefs.getBool('isDark') ?? true;
    });
  }

  Future<void> saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
  }

  // ================= NOTIFICATIONS =================
  void initNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            message.notification?.title ?? "New Notification",
          ),
        ),
      );
    });

    FirebaseMessaging.instance.getToken().then((token) {
      print("FCM TOKEN: $token");
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: const AuthCheck(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFFC1D3B8),
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Color(0xFFC1D3B8),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
// ================= AUTH CHECK (AUTO LOGIN) =================
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final state = context.findAncestorStateOfType<_MyAppState>();

          return FutureBuilder<String>(
            future: SharedPreferences.getInstance()
                .then((prefs) => prefs.getString('role') ?? "Adopter"),
            builder: (context, roleSnap) {
              if (!roleSnap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return MainScreen(
                role: roleSnap.data!,
                toggleTheme: state!.toggleTheme,
                isDark: state.isDark,
              );
            },
          );
        }

        final state = context.findAncestorStateOfType<_MyAppState>();
        return LoginPage(
          toggleTheme: state!.toggleTheme,
          isDark: state.isDark,
        );
      },
    );
  }
}

// ================= SPLASH SCREEN =================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seenOnboarding') ?? false;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => seen
              ? const WelcomePageWrapper()
              : const OnboardingPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 150,
                child: Center(
                  // Icon(Icons.pets, size: 100, color: Colors.white),
                  // Lottie.asset('assets/animation.json')
                  child: Icon(Icons.pets, size: 100, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "PawConnect",
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                "Developed by",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 5),
              const Text(
                "Yogya\nSachin\nRupesh\nYashwardhan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= WELCOME PAGE WRAPPER =================
class WelcomePageWrapper extends StatelessWidget {
  const WelcomePageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    return WelcomePage(
      toggleTheme: state!.toggleTheme,
      isDark: state.isDark,
    );
  }
}

// ================= ONBOARDING =================
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController controller = PageController();
  int index = 0;

  final pages = [
    {
      "title": "Find Your Perfect Pet 🐶",
      "desc": "Swipe and discover pets",
      "img": "https://images.unsplash.com/photo-1558788353-f76d92427f16"
    },
    {
      "title": "Adopt Easily ❤️",
      "desc": "Fast adoption process",
      "img": "https://images.unsplash.com/photo-1548199973-03cce0bbc87b"
    },
    {
      "title": "Chat with Rescuers 💬",
      "desc": "Connect instantly",
      "img": "https://images.unsplash.com/photo-1518791841217-8f162f1e1131"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
            child: LinearProgressIndicator(
              value: (index + 1) / pages.length,
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC1D3B8)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('seenOnboarding', true);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WelcomePageWrapper(),
                  ),
                );
              },
              child: const Text("Skip"),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => index = i),
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        i == 0
                            ? Icons.pets
                            : i == 1
                            ? Icons.favorite
                            : Icons.chat,
                        size: 80,
                        color: Color(0xFFC1D3B8),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            pages[i]["img"]!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        pages[i]["title"]!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pages[i]["desc"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
                  (i) => Container(
                margin: const EdgeInsets.all(4),
                width: index == i ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == i ? Color(0xFFC1D3B8) : Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC1D3B8),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              if (index == pages.length - 1) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('seenOnboarding', true);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WelcomePageWrapper(),
                  ),
                );
              } else {
                controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Text(index == pages.length - 1 ? "Start" : "Next"),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ================= WELCOME PAGE =================
class WelcomePage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const WelcomePage({super.key, required this.toggleTheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pets, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "Welcome to PawConnect 🐾",
                style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => LoginPage(toggleTheme: toggleTheme, isDark: isDark),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: const Text("Get Started", style: TextStyle(color: Colors.black)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ================= LOGIN =================
class LoginPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const LoginPage({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  // ================= GOOGLE LOGIN =================
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'name': user.displayName ?? "User",
        'email': user.email ?? "",
        'uid': user.uid,
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: "Adopter",
            toggleTheme: toggleTheme,
            isDark: isDark,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In Failed: $e")),
      );
    }
  }

  // ================= APPLE LOGIN =================
  Future<void> signInWithApple(BuildContext context) async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      String name = "User";
      if (appleCredential.givenName != null) {
        name =
        "${appleCredential.givenName} ${appleCredential.familyName ?? ""}";
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'name': name,
        'email': user.email ?? "",
        'uid': user.uid,
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: "Adopter",
            toggleTheme: toggleTheme,
            isDark: isDark,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Apple Sign-In Failed: $e")),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Glass container
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pets, size: 60, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text(
                        "PawConnect",
                        style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdopterLoginPage(
                                  toggleTheme: toggleTheme,
                                  isDark: isDark,
                                ),
                              ),
                            );
                          },
                          child: Text("Login as Adopter")
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RescuerLoginPage(
                                toggleTheme: toggleTheme,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                        child: Text("Login as Rescuer"),
                      ),

                      const SizedBox(height: 15),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => signInWithGoogle(context),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text("Continue login with Google"),
                      ),

                      const SizedBox(height: 10),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => signInWithApple(context),
                        icon: const Icon(Icons.apple, size: 22),
                        label: const Text("Continue with Apple"),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Colors.white70),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SignupPage(
                                    toggleTheme: toggleTheme,
                                    isDark: isDark,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MAIN SCREEN =================
class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppData.matches.isEmpty) {
      return const Center(
        child: Text(
          "No Matches Yet 🐾",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: AppData.matches.length,
      itemBuilder: (context, index) {
        final match = AppData.matches[index];
        final animal = match.animal;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: animal.image.startsWith('http')
                  ? NetworkImage(animal.image)
                  : FileImage(File(animal.image)) as ImageProvider,
            ),
            title: Text(animal.name),
            subtitle: Text(animal.breed),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(animal: animal),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
class MainScreen extends StatefulWidget {
  final String role;
  final VoidCallback toggleTheme;
  final bool isDark;

  const MainScreen({
    super.key,
    required this.role,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late bool isDarkLocal;
  int index = 0;

  List<Animal> animals = [];
  String selectedLocality = "Localities";
  Animal? selectedAnimal;
  StreamSubscription? _animalsSubscription;

  @override
  void initState() {
    super.initState();
    isDarkLocal = widget.isDark;

    /// 🔥 LOAD ANIMALS FROM FIREBASE
    _animalsSubscription = FirebaseFirestore.instance
        .collection('animals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.docs.map((doc) {
        final d = doc.data();

        return Animal(
          name: d['name'] ?? "",
          type: d['type'] ?? "",
          breed: d['breed'] ?? "",
          age: d['age'] ?? "",
          description: d['description'] ?? "",
          image: d['image'] ?? "",
          vaccination: d['vaccination'] ?? "",
          locality: d['locality'] ?? "",
          contact: d['contact'] ?? "",
        );
      }).toList();

      setState(() {
        animals = data;
      });
    });
  }

  @override
  void dispose() {
    _animalsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Locality filter logic
    List<Animal> filteredAnimals = selectedLocality == "Localities"
        ? animals
        : animals.where((a) => a.locality == selectedLocality).toList();

    final adopterPages = [
      SwipePage(
        animals: filteredAnimals,
        onLike: (animal) {
          setState(() {
            AppData.favorites.add(animal);

            if (!AppData.matches.any((m) => m.animal.name == animal.name)) {
              AppData.matches.add(Match(animal));
            }
          });
        },
      ),
      AdoptionFormPage(selectedAnimal: selectedAnimal),
      const FavoritesPage(),
      MatchesPage(),
      PetCarePage(),
      SettingsPage(
        toggleTheme: () {
          widget.toggleTheme();
          setState(() {
            isDarkLocal = !isDarkLocal;
          });
        },
        isDark: isDarkLocal,
      ),
    ];
    final rescuerPages = [
    AddAnimalPage(
      onAdd: (animal) {
        setState(() => animals.add(animal));
      },
    ),
    const RescuerRequestsPage(),
    RescuerDashboardPage(animals: animals),
    ChatInboxPage(), // ✅ NO const
    const PetCarePage(),
    SettingsPage(
      toggleTheme: widget.toggleTheme,
      isDark: widget.isDark,
    ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text("Welcome ${widget.role}", key: ValueKey(widget.role))
        ),
        actions: [
          // Locality dropdown
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: selectedLocality,
              dropdownColor: Colors.black,
              style: const TextStyle(color: Colors.white),
              items: [
                "Localities",
                "PCMC",
                "Pune City"
              ].map((loc) {
                return DropdownMenuItem(
                  value: loc,
                  child: Row(
                    children: [
                      Icon(
                        loc == "Localities"
                            ? Icons.location_on
                            : loc == "PCMC"
                            ? Icons.location_city
                            : Icons.location_city,
                        color: Color(0xFFC1D3B8),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loc == "Localities"
                            ? " Localities"
                            : loc == "PCMC"
                            ? "PCMC"
                            : "Pune City",
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLocality = value!;
                });
              },
            ),
          ),
          // Modern sliding toggle for theme
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: isDarkLocal
                    ? [Colors.black, Colors.grey.shade800]
                    : [Colors.yellow.shade200, Color(0xFFC1D3B8)],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(Icons.light_mode, color: Colors.white70),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(Icons.dark_mode, color: Colors.white70),
                    ),
                  ],
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  alignment: isDarkLocal
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      widget.toggleTheme();
                      setState(() {
                        isDarkLocal = !isDarkLocal;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: Icon(
                        isDarkLocal ? Icons.dark_mode : Icons.light_mode,
                        color: isDarkLocal ? Colors.black : Color(0xFFC1D3B8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkLocal
                  ? [Colors.black, Colors.grey.shade900]
                  : [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
            ),
          ),
        ),
      ),
      body: widget.role == "Adopter"
          ? adopterPages[index]
          : rescuerPages[index],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) {
              setState(() => index = i);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Color(0xFFC1D3B8),
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: widget.role == "Adopter"
                ? [
              const BottomNavigationBarItem(icon: Icon(Icons.pets), label: "Animals"),
              const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Adopt"),
              const BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.chat),
                    if (AppData.matches.isNotEmpty)
                      Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            AppData.matches.length.toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                label: "Matches",
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Guide"),
              const BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
            ]
                : [
              const BottomNavigationBarItem(icon: Icon(Icons.add), label: "Add"),
              const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Requests"),
              const BottomNavigationBarItem(icon: Icon(Icons.pets), label: "My Pets"),
              const BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chats"),
              const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Guide"),
              const BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= MATCHES PAGE =================
class ChatInboxPage extends StatelessWidget {
  const ChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }
    final chatsRef = FirebaseFirestore.instance.collection('chats');

    return Scaffold(
      appBar: AppBar(title: const Text("Chats 💬")),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatsRef
            .where('users', arrayContains: currentUser.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No chats yet 😔"));
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final lastMessage = data['lastMessage'] ?? "No messages yet";
              final users = (chats[index]['users'] as List).cast<String>();
              final otherUserId =
              users.firstWhere((id) => id != currentUser.uid);
              final userNames =
              Map<String, dynamic>.from(data['userNames'] ?? {});
              final otherUserName = userNames[otherUserId] ?? "User";

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(otherUserName),
                subtitle: Text(lastMessage),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        animal: Animal(
                          name: otherUserName,
                          type: "",
                          breed: "",
                          age: "",
                          description: "",
                          image: "",
                          vaccination: "",
                          locality: "",
                          contact: otherUserId,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
class ChatPage extends StatefulWidget {
  final Animal animal;

  const ChatPage({super.key, required this.animal});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  final controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;

  String get chatId {
    final userId = currentUser!.uid;
    final otherId = widget.animal.contact;

    final ids = [userId, otherId];
    ids.sort();
    return ids.join("_");
  }

  CollectionReference get messagesRef => FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages');

  Stream<QuerySnapshot> get messagesStream =>
      messagesRef.orderBy('time', descending: false).snapshots();

  void send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (currentUser == null) return;

    await messagesRef.add({
      'text': text,
      'senderId': currentUser!.uid,
      'time': FieldValue.serverTimestamp(),
    });

    controller.clear();
  }

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.animal.name),
      ),
      body: Column(
        children: [

          /// 🔥 MESSAGES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                    docs[index].data() as Map<String, dynamic>;

                    final isMe =
                        data['senderId'] == currentUser?.uid;

                    final text = data['text'] ?? "";
                    final time = data['time'] as Timestamp?;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth:
                              MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFFC1D3B8)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(text),
                          ),
                          Text(
                            formatTime(time),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// 🔥 INPUT BOX (ONLY ONCE!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFC1D3B8),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ✅ MESSAGE INPUT BOX

// ================= PET DETAIL PAGE =================
class PetDetailPage extends StatelessWidget {
  final Animal animal;
  const PetDetailPage({super.key, required this.animal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(animal.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Hero(
            tag: animal.image,
            child: animal.image.startsWith('http')
                ? Image.network(animal.image, height: 200, fit: BoxFit.cover)
                : Image.file(File(animal.image), height: 200, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text(
            animal.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            animal.breed,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text("Type: ${animal.type}"),
          Text("Age: ${animal.age}"),
          Text("Vaccination: ${animal.vaccination}"),
          Text("Locality: ${animal.locality}"),
          const SizedBox(height: 8),
          Text(
            animal.description,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone, color: Color(0xFFC1D3B8)),
              const SizedBox(width: 6),
              Text(
                animal.contact.isNotEmpty ? animal.contact : "Not provided",
                style: TextStyle(
                  color: animal.contact.isNotEmpty ? Color(0xFFC1D3B8) : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC1D3B8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(animal: animal),
                ),
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text("Chat with Rescuer"),
          ),
        ],
      ),
    );
  }
}
// ================= SETTINGS PAGE =================
class SettingsPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const SettingsPage({super.key, required this.toggleTheme, required this.isDark});

  Widget buildTile({required IconData icon, required String title, VoidCallback? onTap, Widget? trailing}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Color(0xFFC1D3B8)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "⚙️ Settings",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Theme toggle
        buildTile(
          icon: Icons.dark_mode,
          title: "Dark Mode",
          trailing: Switch(
            value: isDark,
            onChanged: (val) {
              toggleTheme();
            },
          ),
        ),

        // Health Records
        buildTile(
          icon: Icons.health_and_safety,
          title: "Health Records",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthRecordPage()),
            );
          },
        ),

        // Profile
        buildTile(
          icon: Icons.person,
          title: "Profile",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),

        // Notifications
        buildTile(
          icon: Icons.notifications,
          title: "Notifications",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Notification settings coming soon 🔔")),
            );
          },
        ),

        // Privacy Policy
        buildTile(
          icon: Icons.privacy_tip,
          title: "Privacy Policy",
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Privacy Policy"),
                content: const Text("Your data is Safe and used only for improving pet adoption experience."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                ],
              ),
            );
          },
        ),

        // Terms & Conditions
        buildTile(
          icon: Icons.description,
          title: "Terms & Conditions",
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Terms & Conditions"),
                content: const Text("Use this app responsibly. Pet adoption is a serious commitment."),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                ],
              ),
            );
          },
        ),

        // About App
        buildTile(
          icon: Icons.info,
          title: "About App",
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: "PawConnect",
              applicationVersion: "1.0.0",
              children: const [
                Text(
                    "PawConnect is a modern pet adoption platform designed to bridge the gap between animal rescuers and loving adopters 🐾\n\n"
                        "✨ Key Features:\n"
                        "• Browse and adopt pets easily\n"
                        "• Real-time chat with rescuers\n"
                        "• Smart matching system\n"
                        "• Health records tracking\n"
                        "• Multi-language support\n\n"
                        "💡 Our Mission:\n"
                        "To ensure every pet finds a safe, loving, and permanent home.\n\n"
                        "👨‍💻 Developed by:\n"
                        "Yogya, Sachin, Rupesh, Yashwardhan\n\n"
                        "Thank you for using PawConnect ❤️"
                )
              ],
            );
          },
        ),

        // Feedback
        buildTile(
          icon: Icons.feedback_outlined,
          title: "Feedback",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Feedback feature coming soon ✍️")),
            );
          },
        ),

        // Help & Support
        buildTile(
          icon: Icons.support_agent,
          title: "Help & Support",
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Help & Support"),
                content: const Text("Contact us at support pawconnect.app53@gmail.com"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
                ],
              ),
            );
          },
        ),


        // Share App
        buildTile(
          icon: Icons.share,
          title: "Share App",
          onTap: () {
            Share.share(
              "🐾 Check out PawConnect!\n\nAdopt pets easily ❤️\n\nDownload here:\nhttps://play.google.com/store/apps/details?id=com.sahil.pawconnect",
            );
          },
        ),

        // Logout
        buildTile(
          icon: Icons.logout,
          title: "Logout",
          onTap: () async {
            try {
              await GoogleSignIn().signOut();
            } catch (_) {}

            await FirebaseAuth.instance.signOut();

            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('role');

            if (!context.mounted) return;
            final state = context.findAncestorStateOfType<_MyAppState>();

            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  toggleTheme: state!.toggleTheme,
                  isDark: state.isDark,
                ),
              ),
                  (route) => false,
            );
          },
          trailing: const Icon(Icons.logout, color: Colors.red),
        ),
      ],
    );
  }
}

// ================= PROFILE PAGE =================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  File? imageFile;
  Uint8List? webImage;
  final ImagePicker picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    nameController.text = user?.displayName ?? "";
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => webImage = bytes);
      } else {
        setState(() => imageFile = File(picked.path));
      }
    }
  }

  Future<void> updateProfile() async {
    try {
      await user?.updateDisplayName(nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated ✅")),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: webImage != null
                    ? MemoryImage(webImage!)
                    : imageFile != null
                    ? FileImage(imageFile!) as ImageProvider
                    : user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: (user?.photoURL == null && imageFile == null && webImage == null)
                    ? const Icon(Icons.camera_alt, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📧 Email",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "No Email",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: updateProfile,
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}

// ================= ANIMAL LIST =================
class AnimalListPage extends StatelessWidget {
  final List<Animal> animals;
  final Function(Animal) onSelect;

  const AnimalListPage({super.key, required this.animals, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
      const Text(
      "🐾 Suggested Pets",
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 10),

    // Suggested static animals
    ...[
    {
    "name": "Buddy",
    "breed": "Golden Retriever",
    "image": "https://images.unsplash.com/photo-1558788353-f76d92427f16",
    "contact": "7006312560",
    },
    {
    "name": "Luna",
    "breed": "Husky",
    "image": "https://images.unsplash.com/photo-1548199973-03cce0bbc87b",
    "contact": "7006312560",
    }
    ].map((pet) {
    return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
    child: Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 5,
    margin: const EdgeInsets.only(bottom: 10),
    child: Column(
    children: [
    AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
    child: Stack(
    children: [
    AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    child: Hero(
    tag: pet["image"]!,
    child: Image.network(
    pet["image"]!,
    fit: BoxFit.cover,
    width: double.infinity,
    alignment: Alignment.center,
    errorBuilder: (context, error, stackTrace) {
    return const Center(child: Icon(Icons.broken_image, size: 80));
    },
    ),
    ),
    ),
    Container(
    decoration: const BoxDecoration(
    gradient: LinearGradient(
    colors: [Colors.transparent, Colors.black54],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    ),
    ),
    ),
    Positioned(
    bottom: 10,
    left: 10,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    pet["name"]!,
    style: const TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
    ),
    Text(
    pet["breed"]!,
    style: const TextStyle(color: Colors.white70),
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    ),
    const SizedBox.shrink(),
    ],
    ),
    ),
    );
    }).toList(),

    const SizedBox(height: 20),

    const Text(
    "📋 Available Animals",
    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 10),

    ...animals.map((a) {
    return GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => PetDetailPage(animal: a),
    ),
    );
    },
    child: AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
    child: Dismissible(
    key: Key(a.name),
    background: Container(color: Colors.green),
    secondaryBackground: Container(color: Colors.red),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onSelect(a);
        }
      },
      child: StatefulBuilder(
        builder: (context, setState) {
          bool liked = AppData.favorites.contains(a);
          bool isChecked = AppData.matches.any((m) => m.animal == a);

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 5,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          child: Hero(
                            tag: a.image,
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: a.image.startsWith('http')
                                    ? SizedBox.expand(
                                  child: Image.network(
                                    a.image,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                    : SizedBox.expand(
                                  child: Image.file(
                                    File(a.image),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black54],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                a.breed,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                if (liked) {
                                  AppData.favorites.remove(a);
                                } else {
                                  AppData.favorites.add(a);
                                }
                                liked = !liked;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CheckboxListTile(
                  title: const Text("I'm interested"),
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val!) {
                        AppData.matches.add(Match(a));
                      } else {
                        AppData.matches.removeWhere((m) => m.animal == a);
                      }
                    });
                  },
                ),
                // --- Chat button added below ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC1D3B8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(animal: a),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text("Chat with Rescuer"),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    ),
    );
    }).toList(),
      ],
    );
  }
}

// ================= ADD ANIMAL =================
class AddAnimalPage extends StatefulWidget {
  final Function(Animal) onAdd;

  const AddAnimalPage({super.key, required this.onAdd});

  @override
  State<AddAnimalPage> createState() => _AddAnimalPageState();
}

// ✅ OUTSIDE (IMPORTANT)
class _AddAnimalPageState extends State<AddAnimalPage> {

  final name = TextEditingController();
  final type = TextEditingController();
  final breed = TextEditingController();
  final age = TextEditingController();
  final desc = TextEditingController();
  final vacc = TextEditingController();
  final contact = TextEditingController();

  File? pickedImage;
  Uint8List? webImage;

  final ImagePicker picker = ImagePicker();

  /// ✅ PICK IMAGE (FIXED + DEBUG)
  Future<void> pickImage() async {
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 🔥 compress image
      );

      if (picked != null) {
        print("IMAGE PICKED: ${picked.path}");

        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() {
            webImage = bytes;
          });
        } else {
          setState(() {
            pickedImage = File(picked.path);
          });
        }
      } else {
        print("NO IMAGE SELECTED");
      }
    } catch (e) {
      print("ERROR PICKING IMAGE: $e");
    }
  }

  // --- AUTO-SAVE DRAFT METHODS ---
  Future<void> saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_name', name.text);
    await prefs.setString('draft_type', type.text);
    await prefs.setString('draft_breed', breed.text);
    await prefs.setString('draft_age', age.text);
    await prefs.setString('draft_contact', contact.text);
    await prefs.setString('draft_vacc', vacc.text);
    await prefs.setString('draft_desc', desc.text);
  }

  Future<void> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name.text = prefs.getString('draft_name') ?? '';
      type.text = prefs.getString('draft_type') ?? '';
      breed.text = prefs.getString('draft_breed') ?? '';
      age.text = prefs.getString('draft_age') ?? '';
      contact.text = prefs.getString('draft_contact') ?? '';
      vacc.text = prefs.getString('draft_vacc') ?? '';
      desc.text = prefs.getString('draft_desc') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  void add() async {
    print("ADD BUTTON CLICKED");
    if (name.text.trim().isEmpty ||
        type.text.trim().isEmpty ||
        breed.text.trim().isEmpty ||
        age.text.trim().isEmpty ||
        contact.text.trim().isEmpty) {
      print("VALIDATION FAILED");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill all required fields")),
      );
      return;
    }

    try {
      String imageUrl = "";

      /// 🔥 Upload Image
      if (pickedImage != null || webImage != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();

        final ref = FirebaseStorage.instance
            .ref()
            .child('animal_images/$fileName.jpg');

        if (kIsWeb && webImage != null) {
          await ref.putData(webImage!);
        } else if (pickedImage != null) {
          await ref.putFile(pickedImage!);
        }

        imageUrl = await ref.getDownloadURL();
      } else {
        imageUrl =
        "https://images.unsplash.com/photo-1558788353-f76d92427f16";
      }

      /// 🔥 Save to Firestore
      await FirebaseFirestore.instance.collection('animals').add({
        'name': name.text.trim(),
        'type': type.text.trim(),
        'breed': breed.text.trim(),
        'age': age.text.trim(),
        'description': desc.text.trim(),
        'image': imageUrl,
        'vaccination': vacc.text.trim(),
        'locality': "Pune",
        'contact': FirebaseAuth.instance.currentUser!.uid,
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
        'status': "Available",
        'createdAt': FieldValue.serverTimestamp(),
      });

      /// 🔥 CLEAR FORM
      name.clear();
      type.clear();
      breed.clear();
      age.clear();
      desc.clear();
      vacc.clear();
      contact.clear();

      setState(() {
        pickedImage = null;
        webImage = null;
      });

      if (!mounted) return;
      /// 🔥 SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Animal Added Successfully")),
      );

      /// 🔥 IMPORTANT: CLEAR FORM (tab-based page, do NOT Navigator.pop)
      // Navigator.pop removed — AddAnimalPage is a bottom-nav tab, not a pushed route
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🐾 Animal Details",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC1D3B8),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Name",
                    prefixIcon: Icon(Icons.pets),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: type,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Type",
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: breed,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Breed",
                    prefixIcon: Icon(Icons.pets),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: age,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Age",
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contact,
                  onChanged: (_) => saveDraft(),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Contact Number *",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vacc,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Vaccination Details",
                    prefixIcon: Icon(Icons.medical_services),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Description",
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "📸 Upload Animal Image",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await picker.pickImage(source: ImageSource.camera);
                          if (picked != null) {
                            if (kIsWeb) {
                              final bytes = await picked.readAsBytes();
                              setState(() => webImage = bytes);
                            } else {
                              setState(() => pickedImage = File(picked.path));
                            }
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Camera"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => pickImage(),
                        icon: const Icon(Icons.photo),
                        label: const Text("Gallery"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (webImage != null)
                  Image.memory(webImage!, height: 120)
                else if (pickedImage != null)
                  Image.file(pickedImage!, height: 120),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Color(0xFF000000),
                    ),
                    onPressed: add,
                    child: const Text(
                      "➕ Add Animal",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================= ADOPTION FORM =================
class AdoptionFormPage extends StatefulWidget {
  final Animal? selectedAnimal;

  const AdoptionFormPage({super.key, this.selectedAnimal});

  @override
  State<AdoptionFormPage> createState() => _AdoptionFormPageState();
}

class _AdoptionFormPageState extends State<AdoptionFormPage> {

  // Controllers
  final TextEditingController name = TextEditingController();
  final TextEditingController age = TextEditingController();
  final TextEditingController contact = TextEditingController();
  final TextEditingController email = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool terms = false;
  String balcony = "No";
  String locality = "";

  File? pickedImage;
  Uint8List? webImage;

  final ImagePicker _picker = ImagePicker();

  // ✅ MOVE THESE INSIDE CLASS
  Future<void> saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adopt_name', name.text);
    await prefs.setString('adopt_age', age.text);
    await prefs.setString('adopt_contact', contact.text);
    await prefs.setString('adopt_email', email.text);
    await prefs.setString('adopt_locality', locality);
  }

  Future<void> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name.text = prefs.getString('adopt_name') ?? '';
      age.text = prefs.getString('adopt_age') ?? '';
      contact.text = prefs.getString('adopt_contact') ?? '';
      email.text = prefs.getString('adopt_email') ?? '';
      locality = prefs.getString('adopt_locality') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    contact.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => webImage = bytes);
      } else {
        setState(() => pickedImage = File(picked.path));
      }
    }
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please accept the terms & conditions")),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      String imageUrl = "";
      if (pickedImage != null || webImage != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance
            .ref()
            .child('adoption_docs/$fileName.jpg');
        if (kIsWeb && webImage != null) {
          await ref.putData(webImage!);
        } else if (pickedImage != null) {
          await ref.putFile(pickedImage!);
        }
        imageUrl = await ref.getDownloadURL();
      }

      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      await FirebaseFirestore.instance.collection('requests').doc(requestId).set({
        'id': requestId,
        'name': name.text.trim(),
        'age': age.text.trim(),
        'contact': contact.text.trim(),
        'email': email.text.trim(),
        'locality': locality,
        'balcony': balcony,
        'animalName': widget.selectedAnimal?.name ?? "",
        'adopterId': user?.uid ?? "",
        'status': "Pending",
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppData.requests.add(AdoptionRequest(
        id: requestId,
        name: name.text.trim(),
        age: age.text.trim(),
        contact: contact.text.trim(),
        email: email.text.trim(),
        animal: widget.selectedAnimal,
        status: "Pending",
      ));

      // Clear draft
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('adopt_name');
      await prefs.remove('adopt_age');
      await prefs.remove('adopt_contact');
      await prefs.remove('adopt_email');
      await prefs.remove('adopt_locality');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Adoption Request Submitted!")),
      );

      name.clear();
      age.clear();
      contact.clear();
      email.clear();
      setState(() {
        locality = "";
        balcony = "No";
        terms = false;
        pickedImage = null;
        webImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Adoption Form 🐾")),
        body: Form(
          key: _formKey,
          child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          // ── Header banner ──
          Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(Icons.pets, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.selectedAnimal != null
                      ? "Adopting: ${widget.selectedAnimal!.name}"
                      : "Fill in your details to adopt a pet",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Personal details card ──
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "👤 Personal Details",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  onChanged: (_) => saveDraft(),
                  decoration: const InputDecoration(
                    labelText: "Full Name *",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Enter your name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: age,
                  onChanged: (_) => saveDraft(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Age *",
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Enter your age" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contact,
                  onChanged: (_) => saveDraft(),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Contact Number *",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Enter contact number";
                    if (v.trim().length < 10) return "Enter a valid number";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  onChanged: (_) => saveDraft(),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email *",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Enter email";
                    if (!v.contains('@')) return "Invalid email";
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Living situation card ──
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🏠 Living Situation",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: locality.isEmpty ? null : locality,
                  decoration: const InputDecoration(
                    labelText: "Locality *",
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  items: ["PCMC", "Pune City", "Other"].map((l) {
                    return DropdownMenuItem(value: l, child: Text(l));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => locality = val ?? "");
                    saveDraft();
                  },
                  validator: (v) =>
                  (v == null || v.isEmpty) ? "Select your locality" : null,
                ),
                const SizedBox(height: 12),
                const Text("Are the Windows and Balcony of Your House Netted?"),
                Row(
                  children: ["Yes", "No"].map((opt) {
                    return Row(
                      children: [
                        Radio<String>(
                          value: opt,
                          groupValue: balcony,
                          onChanged: (v) =>
                              setState(() => balcony = v ?? "No"),
                          activeColor: const Color(0xFFC1D3B8),
                        ),
                        Text(opt),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Document upload card ──
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📎 Upload ID / Document (optional)",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Camera"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: const Text("Gallery"),
                      ),
                    ),
                  ],
                ),
                if (webImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(webImage!, height: 120,
                          fit: BoxFit.cover, width: double.infinity),
                    ),
                  )
                else if (pickedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(pickedImage!, height: 120,
                          fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Terms checkbox ──
        Row(
          children: [
            Checkbox(
              value: terms,
              activeColor: const Color(0xFFC1D3B8),
              onChanged: (v) => setState(() => terms = v ?? false),
            ),
            const Expanded(
              child: Text(
                "I agree to the Terms & Conditions and commit to responsible pet ownership.",
              ),
            ),
          ],
        ),
                const SizedBox(height: 20),

                // ── Submit button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CAF88),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: submitForm,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      "Submit Adoption Request",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
          ),
        ),
    );
  }
}



// ================= FAVORITES PAGE =================
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListView(
          padding: const EdgeInsets.all(10),
          children: AppData.favorites.map((a) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.pets),
                title: Text(a.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.breed),
                    const SizedBox(height: 4),
                    a.contact.isNotEmpty
                        ? Text(
                      "📞 ${a.contact}",
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFC1D3B8)),
                    )
                        : const Text(
                      "📞 Not provided",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      AppData.favorites.remove(a);
                    });
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ================= PET CARE =================
class RescuerRequestsPage extends StatefulWidget {
  const RescuerRequestsPage({super.key});

  @override
  State<RescuerRequestsPage> createState() => _RescuerRequestsPageState();
}

class _RescuerRequestsPageState extends State<RescuerRequestsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: AppData.requests.map((req) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Name: ${req.name}"),
                Text("Age: ${req.age}"),
                Text("Contact: ${req.contact == "9876543210" || req.contact == "1234567890" || req.contact == "9999999999" ? "7006312560" : req.contact}"),
                Text("Email: ${req.email}"),
                if (req.animal != null)
                  Text("Animal: ${req.animal!.name}"),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: req.status == "Adopted"
                        ? Colors.green.withOpacity(0.2)
                        : req.status == "Declined"
                        ? Colors.red.withOpacity(0.2)
                        : Color(0xFFC1D3B8).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Status: ${req.status}",
                    style: TextStyle(
                      color: req.status == "Adopted"
                          ? Colors.green
                          : req.status == "Declined"
                          ? Colors.red
                          : Color(0xFFC1D3B8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          req.status = "Adopted";
                        });

                        FirebaseFirestore.instance
                            .collection('requests')
                            .doc(req.id)
                            .update({
                          'status': "Adopted",
                        });
                      },
                      child: const Text("Approve"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          req.status = "Declined";
                        });

                        await FirebaseFirestore.instance
                            .collection('requests')
                            .doc(req.id)
                            .update({
                          'status': "Declined",
                        });
                      },
                      child: const Text("Decline"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(), // ✅ IMPORTANT
    );
  }
}
class PetCarePage extends StatelessWidget {
  const PetCarePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "🐾 Pet Care Guide",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Decorative banner
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.pets, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Learn how to take the best care of your pet 🐶",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 10),

        //  Healthy Diet
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.restaurant, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Healthy Diet",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "A balanced diet is essential for your pet’s growth, immunity, and overall well-being.\n\n"
                        "Provide species-appropriate food\n"
                        "Include: Proteins, Carbohydrates, Fats, Vitamins\n"
                        "Avoid: Junk food, chocolate, onions, grapes\n"
                        "Always provide fresh water\n\n"
                        "Tip: Follow feeding schedules to prevent obesity.",
                  )
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        //  Vet
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.local_hospital, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Regular Vet Visits",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Routine care prevents diseases.\n\n"
                      "Vaccinations protect pets\n"
                      "Regular checkups detect hidden issues\n"
                      "Parasite control is important\n\n"
                      "Schedule:\nPuppies: 3–4 weeks\nAdults: yearly\nSeniors: frequent visits",
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        //  Exercise
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.directions_run, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Daily Exercise",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Exercise keeps pets fit and active.\n\n"
                      "Dogs: walking, running\n"
                      "Cats: toys, climbing\n\n"
                      "Duration:\nDogs: 30–120 min\nCats: 15–30 min",
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        // ️ Grooming
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.content_cut, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Grooming",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Maintain hygiene:\n\n"
                      "Bathing\nBrushing\nNail trimming\nEar cleaning\nDental care\n\n"
                      "Prevents infections and keeps pets healthy.",
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        //  Love
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.favorite, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Love & Attention",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Build strong bond:\n\n"
                      "Play daily\nSpend time\nReward behavior\n\n"
                      "Pets need emotional care too.",
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        //  Safety
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.security, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Safety Measures",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Remove toxic plants\nKeep wires safe\nSecure balconies\nStore harmful items",
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 5),

        //  Comfort
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.home, color: Color(0xFFC1D3B8), size: 28),
            title: const Text(
              " Comfort Essentials",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Provide cozy bed\nClean environment\nMaintain temperature\nEnsure safe resting area",
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}


// ================= RESCUER DASHBOARD PAGE =================

class RescuerDashboardPage extends StatefulWidget {
  final List<Animal> animals;

  const RescuerDashboardPage({super.key, required this.animals});

  @override
  State<RescuerDashboardPage> createState() => _RescuerDashboardPageState();
}

class _RescuerDashboardPageState extends State<RescuerDashboardPage> {
  late List<Animal> _animals;

  @override
  void initState() {
    super.initState();
    _animals = List<Animal>.from(widget.animals);
  }

  @override
  Widget build(BuildContext context) {
    int total = AppData.requests.length;
    int adopted = AppData.requests.where((r) => r.status == "Adopted").length;
    int pending = AppData.requests.where((r) => r.status == "Pending").length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFC1D3B8),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Go to Add Animal page ➕")),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.pets, color: Colors.white, size: 30),
                SizedBox(width: 10),
                Text(
                  "Rescuer Dashboard",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // STATS
          Row(
            children: [
              Expanded(child: statCard("Total", total, Colors.blue)),
              Expanded(child: statCard("Adopted", adopted, Colors.green)),
              Expanded(child: statCard("Pending", pending, Color(0xFFC1D3B8))),
            ],
          ),

          const SizedBox(height: 20),

          // 🔥 ANALYTICS CHART
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📊 Adoption Analytics",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end, // keeps base aligned
                  children: [
                    chartBar("Total", total, Colors.blue),
                    chartBar("Adopted", adopted, Colors.green),
                    chartBar("Pending", pending, Color(0xFFC1D3B8)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // PET LIST WITH SWIPE
          ..._animals.map((a) {
            return Dismissible(
              key: Key(a.name),

              background: Container(color: Colors.green),
              secondaryBackground: Container(color: Colors.red),

              onDismissed: (_) {
                final removedAnimal = a;

                setState(() {
                  _animals.removeWhere((animal) =>
                  animal.name == removedAnimal.name &&
                      animal.breed == removedAnimal.breed);
                });
              },

              child: Card(   // ✅ THIS LINE WILL WORK NOW
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                margin: const EdgeInsets.only(bottom: 15),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: a.image.startsWith('http')
                              ? Image.network(
                            a.image,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                              : Image.file(
                            File(a.image),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          height: 180,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black54],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 12,
                          child: Text(
                            a.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(a.breed),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _animals.remove(a);
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget statCard(String title, int value, Color color) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(value.toString(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title),
        ],
      ),
    );
  }

  // ANALYTICS CHART BAR
  Widget chartBar(String label, int value, Color color) {
    double height = value == 0 ? 10 : (value * 20).toDouble();

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: height,
          width: 30,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ================= SWIPE PAGE =================
class SwipePage extends StatefulWidget {
  final List<Animal> animals;
  final Function(Animal) onLike;

  const SwipePage({super.key, required this.animals, required this.onLike});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  int currentIndex = 0;
  double offsetX = 0;
  double rotation = 0;
  bool showLike = false;
  bool showDislike = false;

  @override
  Widget build(BuildContext context) {
    if (widget.animals.isEmpty) {
      return const Center(child: Text("No animals available"));
    }

    if (currentIndex >= widget.animals.length) {
      return const Center(child: Text("No more pets 😢"));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background stacked cards
        for (int i = currentIndex + 1;
        i < widget.animals.length && i < currentIndex + 3;
        i++)
          Positioned(
            top: 10.0 * (i - currentIndex),
            child: Opacity(
              opacity: 0.6,
              child: Transform.scale(
                scale: 0.9,
                child: buildCard(widget.animals[i]),
              ),
            ),
          ),

        // Top swipe card
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              offsetX += details.delta.dx;
              rotation = offsetX / 300;

              if (offsetX > 50) {
                showLike = true;
                showDislike = false;
              } else if (offsetX < -50) {
                showDislike = true;
                showLike = false;
              } else {
                showLike = false;
                showDislike = false;
              }
            });
          },
          onPanEnd: (details) {
            if (offsetX > 150) {
              final likedAnimal = widget.animals[currentIndex];
              widget.onLike(likedAnimal);

              // AI recommendation: smarter scoring
              final scored = widget.animals.map((a) {
                int score = 0;
                if (a.type == likedAnimal.type) score += 2;
                if (a.breed == likedAnimal.breed) score += 3;
                if (a.age == likedAnimal.age) score += 1;
                return {"animal": a, "score": score};
              }).toList();
              scored.sort((a, b) => (b["score"] as int).compareTo(a["score"] as int));
              if (scored.isNotEmpty && (scored.first["animal"] as Animal) != likedAnimal) {
                AppData.matches.add(Match(scored.first["animal"] as Animal));
              }
            }

            setState(() {
              currentIndex++;
              offsetX = 0;
              rotation = 0;
              showLike = false;
              showDislike = false;
            });
          },
          child: Transform.translate(
            offset: Offset(offsetX, 0),
            child: Transform.rotate(
              angle: rotation,
              child: Stack(
                children: [
                  buildCard(widget.animals[currentIndex]),

                  if (showLike)
                    Positioned(
                      top: 40,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 3),
                        ),
                        child: const Text(
                          "LIKE",
                          style: TextStyle(color: Colors.green, fontSize: 24),
                        ),
                      ),
                    ),

                  if (showDislike)
                    Positioned(
                      top: 40,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 3),
                        ),
                        child: const Text(
                          "NOPE",
                          style: TextStyle(color: Colors.red, fontSize: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildCard(Animal a) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.6,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: a.image.startsWith('http')
                  ? SizedBox.expand(
                child: Image.network(
                  a.image,
                  fit: BoxFit.cover,
                ),
              )
                  : SizedBox.expand(
                child: Image.file(
                  File(a.image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: Icon(
                  AppData.favorites.contains(a)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.red,
                  size: 30,
                ),
                onPressed: () {
                  if (AppData.favorites.contains(a)) {
                    AppData.favorites.remove(a);
                  } else {
                    AppData.favorites.add(a);
                  }
                  setState(() {});
                },
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Text(
                "${a.name} • ${a.breed}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DEVELOPER INTRO PAGE =================
class DeveloperIntroPage extends StatefulWidget {
  const DeveloperIntroPage({super.key});

  @override
  State<DeveloperIntroPage> createState() => _DeveloperIntroPageState();
}

class _DeveloperIntroPageState extends State<DeveloperIntroPage> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.pets, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "PawConnect 🐾",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 30),
            Text(
              "Developed By",
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            SizedBox(height: 10),
            Text(
              "Sahil Raina",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              "Team PawConnect",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= LOGIN PAGE =================

void _dummyToggle() {}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Welcome Back 🐾", style: TextStyle(fontSize: 22)),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdopterLoginPage(toggleTheme: _dummyToggle, isDark: false)),
                    );
                  },
                  icon: const Icon(Icons.pets),
                  label: const Text("Login as Adopter"),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RescuerLoginPage(toggleTheme: _dummyToggle, isDark: false)),
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text("Login as Rescuer"),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupPage(toggleTheme: _dummyToggle, isDark: false)),
                  ),
                  child: const Text("Create Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class AccountPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const AccountPage({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  String role = "Adopter";
  final _formKey = GlobalKey<FormState>();

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      if (!mounted) return;
      final state = context.findAncestorStateOfType<_MyAppState>();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: role,
            toggleTheme: state!.toggleTheme,
            isDark: state.isDark,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup Failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: "Full Name"),
                validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: email,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter email";
                  if (!v.contains('@')) return "Invalid email";
                  return null;
                },
              ),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
                validator: (v) {
                  if (v == null || v.length < 6) return "Min 6 chars";
                  return null;
                },
              ),
              TextFormField(
                controller: confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                validator: (v) {
                  if (v != password.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: role,
                items: ["Adopter", "Rescuer"].map((r) {
                  return DropdownMenuItem(value: r, child: Text(r));
                }).toList(),
                onChanged: (value) => setState(() => role = value!),
                decoration: const InputDecoration(labelText: "Select Role"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: register,
                child: const Text("Create Account"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ================= ACCOUNT PAGE =================
// (Second occurrence of AccountPage is retained below)

// ================= HEALTH RECORD PAGE =================
class HealthRecordPage extends StatefulWidget {
  const HealthRecordPage({super.key});

  @override
  State<HealthRecordPage> createState() => _HealthRecordPageState();
}

class _HealthRecordPageState extends State<HealthRecordPage> {
  final petName = TextEditingController();
  final vaccination = TextEditingController();
  final report = TextEditingController();

  void addRecord() {
    setState(() {
      AppData.healthRecords.add(
        HealthRecord(
          petName: petName.text,
          vaccination: vaccination.text,
          medicalReport: report.text,
          date: DateTime.now().toString().split(" ")[0],
        ),
      );
    });

    petName.clear();
    vaccination.clear();
    report.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Records 🏥")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(controller: petName, decoration: const InputDecoration(labelText: "Pet Name")),
                TextField(controller: vaccination, decoration: const InputDecoration(labelText: "Vaccination Details")),
                TextField(controller: report, decoration: const InputDecoration(labelText: "Medical Report")),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: addRecord, child: const Text("Add Record")),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: AppData.healthRecords.map((r) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.medical_services, color: Colors.green),
                    title: Text(r.petName),
                    subtitle: Text("${r.vaccination}\n${r.medicalReport}\nDate: ${r.date}"),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
// ================= OPTIONAL: AUTO LOAD SAVED LANGUAGE =================
// You can add this in main() or initState of MyApp
// Example for main():



// ================= ADOPTER LOGIN PAGE =================
class AdopterLoginPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const AdopterLoginPage({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<AdopterLoginPage> createState() => _AdopterLoginPageState();
}
class _AdopterLoginPageState extends State<AdopterLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', "Adopter");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: "Adopter",
            toggleTheme: widget.toggleTheme,
            isDark: widget.isDark,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Adopter Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text("Login as Adopter"),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= RESCUER LOGIN PAGE =================
class RescuerLoginPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const RescuerLoginPage({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<RescuerLoginPage> createState() => _RescuerLoginPageState();
}

class _RescuerLoginPageState extends State<RescuerLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', "Rescuer");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: "Rescuer",
            toggleTheme: widget.toggleTheme,
            isDark: widget.isDark,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rescuer Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: const Text("Login as Rescuer"),
            ),
          ],
        ),
      ),
    );
  }
}
// ================= SIGNUP PAGE =================

class SignupPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const SignupPage({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();

  String role = "Adopter"; // 🔥 NEW

  Future<void> signUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);

      if (!mounted) return;
      final state = context.findAncestorStateOfType<_MyAppState>();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            role: role,
            toggleTheme: state!.toggleTheme,
            isDark: state.isDark,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup Failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌿 Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC1D3B8), Color(0xFF9CAF88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 💎 Glass UI
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 330,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 60, color: Colors.black),
                    const SizedBox(height: 10),
                    const Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 👤 Name
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        hintText: "Name",
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 📧 Email
                    TextField(
                      controller: email,
                      decoration: InputDecoration(
                        hintText: "Email",
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔒 Password
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Password",
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🔥 ROLE SELECTION (NEW)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text("Adopter"),
                          selected: role == "Adopter",
                          onSelected: (_) {
                            setState(() => role = "Adopter");
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text("Rescuer"),
                          selected: role == "Rescuer",
                          onSelected: (_) {
                            setState(() => role = "Rescuer");
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 🚀 SIGN UP BUTTON
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: signUp,
                      child: const Text("Create Account"),
                    ),

                    const SizedBox(height: 10),

                    // 🔙 Back to Login
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ================= SET DEVELOPER INTRO PAGE AS HOME =================

// Somewhere above or in your MyApp/MaterialApp widget, set:
// home: const DeveloperIntroPage(),
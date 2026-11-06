import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nvtwndkuzwiaihnohkzs.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_RWmzysWOzzqoWtOacwfOzw_WD8LeeKa',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the app launchable even when Supabase keys have not been supplied.
  // Supabase features become available when a publishable key is configured.
  if (_supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabasePublishableKey,
      );
    } catch (error, stackTrace) {
      debugPrint('Supabase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  } else {
    debugPrint(
      'Supabase key not provided. MyServe will open in demo mode. '
      'Use --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY to enable it.',
    );
  }

  runApp(const MyServeApp());
}

String getMyServeProfileName() {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'MyServe Member';
  } catch (_) {
    return 'MyServe Member';
  }
}

String getMyServeEmail() {
  try {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  } catch (_) {
    return '';
  }
}

String getMyServeBusinessName() {
  try {
    final value = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['business_name']
        ?.toString()
        .trim();
    return value == null || value.isEmpty ? getMyServeProfileName() : value;
  } catch (_) {
    return getMyServeProfileName();
  }
}

/// Creates the owner's business row after authentication. Safe to call after
/// registration and login because it first checks whether a row already exists.
Future<void> ensureBusinessRecordExists({
  required String userId,
  required Map<String, dynamic> metadata,
}) async {
  final accountType = (metadata['account_type'] ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_');
  if (accountType != 'business_owner') return;

  final supabase = Supabase.instance.client;

  // Do not create a duplicate business for an owner.
  final existing = await supabase
      .from('businesses')
      .select('id')
      .eq('owner_id', userId)
      .limit(1)
      .maybeSingle();
  if (existing != null) return;

  final businessName = (metadata['business_name'] ?? '').toString().trim();
  if (businessName.isEmpty) {
    throw const FormatException(
      'Business name is missing from the registered account metadata.',
    );
  }

  // The registration form uses friendly category labels, while the database
  // stores the standard categories seeded in public.categories.
  final enteredCategory = (metadata['business_category'] ?? '')
      .toString()
      .trim();
  const categoryMap = <String, String>{
    'Retail Shop': 'Food & Groceries',
    'Restaurant / Food Business': 'Food & Groceries',
    'Fashion / Tailoring': 'Fashion & Clothing',
    'Beauty / Hair Salon': 'Beauty & Cosmetics',
    'Health / Pharmacy': 'Health & Wellness',
    'Technology / Electronics': 'Electronics',
    'Repairs / Auto Services': 'Repairs & Maintenance',
    'Cleaning Services': 'Cleaning Services',
    'Education / Training': 'Education & Training',
    'Photography / Videography': 'Event Services',
    'Content Creator': 'Professional Services',
    'Other': 'Other',
  };
  final categoryName = categoryMap[enteredCategory] ?? 'Other';

  final category = await supabase
      .from('categories')
      .select('id')
      .eq('name', categoryName)
      .maybeSingle();
  final categoryId = category?['id'];

  final location = (metadata['business_location'] ?? '').toString().trim();
  final description = (metadata['business_description'] ?? '')
      .toString()
      .trim();
  final phone = (metadata['phone'] ?? '').toString().trim();

  // Request the inserted row back so any database/RLS error is surfaced here.
  final inserted = await supabase
      .from('businesses')
      .insert({
        'owner_id': userId,
        'name': businessName,
        if (categoryId != null) 'category_id': categoryId,
        'description': description,
        'phone': phone,
        'location': location,
        'address': location,
        'is_active': true,
      })
      .select('id, name, owner_id')
      .single();

  debugPrint('MyServe business profile created: $inserted');
}

// ============================================================
// COLORS
// ============================================================
class AppColors {
  static const navy = Color(0xFF0B3D91);
  static const royal = Color(0xFF2563EB);
  static const gold = Color(0xFFFBBF24);
  static const teal = Color(0xFF10B981);
  static const lightGray = Color(0xFFF3F4F6);
  static const textDark = Color(0xFF111827);
  static const textGrey = Color(0xFF6B7280);
}

// ============================================================
// APP ROOT
// ============================================================
class MyServeApp extends StatelessWidget {
  const MyServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyServe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.royal),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGray,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE6EAF1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.royal, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EDF4)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// MODELS (sample data)
// ============================================================
class Business {
  final String name;
  final String category;
  final String distance;
  final double rating;
  final int reviews;
  final bool open;
  final IconData icon;
  final Color color;

  const Business({
    required this.name,
    required this.category,
    required this.distance,
    required this.rating,
    required this.reviews,
    required this.open,
    required this.icon,
    required this.color,
  });
}

const List<Business> kBusinesses = [
  Business(
    name: 'Tech Hub Solutions',
    category: 'Electronics & Gadgets',
    distance: '800 m',
    rating: 4.8,
    reviews: 322,
    open: true,
    icon: Icons.devices,
    color: AppColors.royal,
  ),
  Business(
    name: 'Bella Fashion Store',
    category: 'Fashion & Clothing',
    distance: '1.1 km',
    rating: 4.6,
    reviews: 198,
    open: true,
    icon: Icons.checkroom,
    color: Colors.pink,
  ),
  Business(
    name: 'Swift Auto Garage',
    category: 'Auto Services',
    distance: '1.5 km',
    rating: 4.5,
    reviews: 176,
    open: true,
    icon: Icons.car_repair,
    color: Colors.deepOrange,
  ),
  Business(
    name: 'Healthy Life Pharmacy',
    category: 'Health & Wellness',
    distance: '1.8 km',
    rating: 4.7,
    reviews: 289,
    open: true,
    icon: Icons.local_pharmacy,
    color: AppColors.teal,
  ),
];

const Business kGoldenEats = Business(
  name: 'Golden Eats Restaurant',
  category: 'Restaurant & Food',
  distance: '1.2 km',
  rating: 4.8,
  reviews: 322,
  open: true,
  icon: Icons.restaurant,
  color: AppColors.gold,
);

// All sample listings used by Explore and search.
const List<Business> kAllBusinesses = [...kBusinesses, kGoldenEats];

// ============================================================
// SMALL REUSABLE WIDGETS
// ============================================================
class SearchBox extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const SearchBox({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textGrey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller != null && onChanged != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        controller!.clear();
                        onChanged!.call('');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
        ],
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    // MyServe's custom gold-and-navy monogram, matching the brand artwork.
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MyServeLogoPainter()),
    );
  }
}

class _MyServeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final navy = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = Path()
      ..moveTo(12, 69)
      ..lineTo(12, 38)
      ..lineTo(31, 18)
      ..lineTo(51, 39);
    canvas.drawPath(left, gold);

    final right = Path()
      ..moveTo(34, 62)
      ..lineTo(57, 78)
      ..lineTo(87, 40);
    canvas.drawPath(right, navy);

    final highlight = Path()
      ..moveTo(58, 18)
      ..lineTo(72, 31);
    canvas.drawPath(highlight, white);

    final dot = Paint()..color = AppColors.royal;
    canvas.drawCircle(const Offset(82, 18), 6, dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.verified, color: AppColors.royal, size: 16);
}

class BusinessAvatar extends StatelessWidget {
  final Business b;
  final double size;
  const BusinessAvatar({super.key, required this.b, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: b.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(b.icon, color: b.color, size: size * 0.5),
    );
  }
}

// ============================================================
// 1. SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071D42), AppColors.navy, Color(0xFF1769E0)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -65,
              child: _SplashOrb(size: 230, color: AppColors.gold),
            ),
            Positioned(
              bottom: -90,
              left: -65,
              child: _SplashOrb(size: 270, color: AppColors.teal),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const LogoMark(size: 72),
                    ),
                    const SizedBox(height: 24),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'My',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Serve',
                            style: TextStyle(color: AppColors.gold),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Every Service. Every Business.\nOne Platform.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Find the right service',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explore Services',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Text(
                'DISCOVER  •  CONNECT  •  GROW',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _SplashOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.09),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1.5,
      ),
    ),
  );
}

// ============================================================
// 2. ONBOARDING
// ============================================================
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _go(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const LogoMark(size: 64),
                      const SizedBox(height: 14),
                      const Text(
                        'MyServe',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find the right service',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Every Service. Every Business.\nOne Platform.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront,
                          size: 110,
                          color: AppColors.royal,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Discover amazing businesses,\nfind the services you need,\nall in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Explore Services',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.royal,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _go(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _go(context),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN AND REGISTRATION
// Supabase authentication for real customer and business-owner accounts.
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = Supabase.instance.client.auth;
      final result = await auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = result.user;
      if (user == null) {
        throw const AuthException('Login failed. Please try again.');
      }

      final metadata = user.userMetadata ?? {};
      final rawAccountType = (metadata['account_type'] ?? 'customer')
          .toString()
          .toLowerCase();
      final accountType =
          rawAccountType == 'business_owner' ||
              rawAccountType == 'business owner'
          ? 'Business Owner'
          : 'Customer';

      if (accountType == 'Business Owner') {
        try {
          await ensureBusinessRecordExists(userId: user.id, metadata: metadata);
        } catch (error, stackTrace) {
          debugPrint('Business record creation failed after login: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Business profile could not be saved: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainShell(accountType: accountType)),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not connect to the server. Check your Supabase setup and internet connection.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LogoMark(size: 68)),
                    const SizedBox(height: 12),
                    const Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue to MyServe',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Email Address',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 6
                          ? 'Password must be at least 6 characters.'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Forgot password?'),
                            content: const Text(
                              'Password recovery will work after an authentication service is connected.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _accountType = 'Customer';
  String _businessCategory = 'Retail Shop';
  final _businessNameController = TextEditingController();
  final _businessLocationController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final Map<String, TextEditingController> _businessAnswerControllers = {};
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _businessNameController.dispose();
    _businessLocationController.dispose();
    _businessDescriptionController.dispose();
    for (final controller in _businessAnswerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static const List<String> _businessCategories = [
    'Retail Shop',
    'Restaurant / Food Business',
    'Fashion / Tailoring',
    'Beauty / Hair Salon',
    'Health / Pharmacy',
    'Technology / Electronics',
    'Repairs / Auto Services',
    'Cleaning Services',
    'Education / Training',
    'Photography / Videography',
    'Content Creator',
    'Other',
  ];

  static const Map<String, List<String>> _businessQuestions = {
    'Retail Shop': [
      'What products do you sell?',
      'Do you offer delivery or pickup?',
      'What makes your shop different from others?',
    ],
    'Restaurant / Food Business': [
      'What food or drinks do you offer?',
      'Do you provide dine-in, takeaway, or delivery?',
      'What are your opening hours?',
    ],
    'Fashion / Tailoring': [
      'What fashion or tailoring services do you provide?',
      'Do you accept custom orders?',
      'How long does a typical order take?',
    ],
    'Beauty / Hair Salon': [
      'Which beauty, hair, or grooming services do you offer?',
      'Do customers need to book an appointment?',
      'Do you provide services at customers’ locations?',
    ],
    'Health / Pharmacy': [
      'What products or services does your business provide?',
      'What are your business opening hours?',
      'How can customers contact you for enquiries?',
    ],
    'Technology / Electronics': [
      'What devices, products, or technology services do you offer?',
      'Do you provide repairs, sales, or both?',
      'Do you offer a warranty or after-sales support?',
    ],
    'Repairs / Auto Services': [
      'What types of repair or maintenance do you provide?',
      'Which vehicles, devices, or equipment do you work on?',
      'Do you offer on-site or emergency service?',
    ],
    'Cleaning Services': [
      'What types of cleaning do you provide?',
      'Do you serve homes, offices, or both?',
      'Do customers need to book in advance?',
    ],
    'Education / Training': [
      'What subjects or skills do you teach?',
      'Are your lessons online, in-person, or both?',
      'Who are your target learners?',
    ],
    'Photography / Videography': [
      'What types of photography or video work do you specialise in?',
      'Do you cover events, studio sessions, or outdoor shoots?',
      'How can customers view your portfolio?',
    ],
    'Content Creator': [
      'What type of content do you create (e.g. video, writing, tutorials, comedy, reviews)?',
      'Which platforms do you publish on (e.g. TikTok, YouTube, Instagram, Facebook)?',
      'What topics or niche do you focus on, and who is your audience?',
      'Do you offer paid promotions, brand partnerships, or content production services?',
    ],
    'Other': [
      'Describe the products or services you provide.',
      'Who are your main customers?',
      'What makes your business or service unique?',
    ],
  };

  List<String> get _questionsForCategory =>
      _businessQuestions[_businessCategory] ?? _businessQuestions['Other']!;

  void _updateBusinessCategory(String? category) {
    if (category == null) return;
    setState(() {
      _businessCategory = category;
      for (final controller in _businessAnswerControllers.values) {
        controller.dispose();
      }
      _businessAnswerControllers.clear();
    });
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final metadata = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'account_type': _accountType == 'Business Owner'
            ? 'business_owner'
            : 'customer',
      };

      if (_accountType == 'Business Owner') {
        metadata.addAll({
          'business_name': _businessNameController.text.trim(),
          'business_category': _businessCategory,
          'business_location': _businessLocationController.text.trim(),
          'business_description': _businessDescriptionController.text.trim(),
          'business_answers': {
            for (final entry in _businessAnswerControllers.entries)
              entry.key: entry.value.text.trim(),
          },
        });
      }

      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: metadata,
      );

      if (!mounted) return;

      if (response.session != null) {
        if (_accountType == 'Business Owner' && response.user != null) {
          try {
            await ensureBusinessRecordExists(
              userId: response.user!.id,
              metadata: metadata,
            );
          } catch (error, stackTrace) {
            debugPrint(
              'Business record creation failed after registration: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Your account was created, but your business profile could not be saved. Please sign in again or contact support.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainShell(accountType: _accountType),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Check your email and confirm it, then sign in.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account creation failed. Check your connection and Supabase setup.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Registration error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon) =>
      InputDecoration(hintText: hint, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LogoMark(size: 54)),
                    const SizedBox(height: 10),
                    const Text(
                      'Join MyServe',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create an account to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'I want to join as',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _AccountTypeCard(
                            title: 'Customer',
                            subtitle: 'Find services',
                            icon: Icons.person_outline,
                            selected: _accountType == 'Customer',
                            onTap: () =>
                                setState(() => _accountType = 'Customer'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AccountTypeCard(
                            title: 'Business Owner',
                            subtitle: 'Promote my business',
                            icon: Icons.storefront_outlined,
                            selected: _accountType == 'Business Owner',
                            onTap: () =>
                                setState(() => _accountType = 'Business Owner'),
                          ),
                        ),
                      ],
                    ),
                    if (_accountType == 'Business Owner') ...[
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.royal.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE1E9F8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Business Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Tell customers about your business or creator profile.',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Business / Creator Name',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _businessNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _decoration(
                                'Enter business or creator name',
                                Icons.storefront_outlined,
                              ),
                              validator: (v) =>
                                  _accountType == 'Business Owner' &&
                                      (v?.trim().isEmpty ?? true)
                                  ? 'Please enter your business or creator name.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Business Category',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 7),
                            DropdownButtonFormField<String>(
                              initialValue: _businessCategory,
                              isExpanded: true,
                              decoration: _decoration(
                                'Choose a category',
                                Icons.category_outlined,
                              ),
                              items: _businessCategories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _updateBusinessCategory,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Location',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _businessLocationController,
                              decoration: _decoration(
                                'City / area where you operate',
                                Icons.location_on_outlined,
                              ),
                              validator: (v) =>
                                  _accountType == 'Business Owner' &&
                                      (v?.trim().isEmpty ?? true)
                                  ? 'Please enter your business location.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Short Description',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _businessDescriptionController,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: _decoration(
                                'Describe your business or content',
                                Icons.description_outlined,
                              ),
                              validator: (v) =>
                                  _accountType == 'Business Owner' &&
                                      (v?.trim().isEmpty ?? true)
                                  ? 'Please add a short description.'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Questions About Your Business',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Answer these questions to help customers understand what you offer.',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._questionsForCategory.asMap().entries.map((
                              entry,
                            ) {
                              final questionIndex = entry.key;
                              final question = entry.value;
                              final controller = _businessAnswerControllers
                                  .putIfAbsent(
                                    question,
                                    () => TextEditingController(),
                                  );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${questionIndex + 1}. $question',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    TextFormField(
                                      controller: controller,
                                      minLines: 2,
                                      maxLines: 4,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: _decoration(
                                        'Type your answer here',
                                        Icons.edit_note_outlined,
                                      ),
                                      validator: (v) =>
                                          _accountType == 'Business Owner' &&
                                              (v?.trim().isEmpty ?? true)
                                          ? 'Please answer this question.'
                                          : null,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Full Name',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Enter your full name',
                        Icons.person_outline,
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Please enter your name.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Email Address',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration(
                        'Enter your email',
                        Icons.email_outlined,
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Phone Number',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration(
                        'Enter your phone number',
                        Icons.phone_outlined,
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 7
                          ? 'Enter a valid phone number.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration:
                          _decoration(
                            'At least 6 characters',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                      validator: (v) => (v ?? '').length < 6
                          ? 'Password must be at least 6 characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Confirm Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: _decoration(
                        'Re-enter your password',
                        Icons.lock_reset_outlined,
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.royal.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.royal : const Color(0xFFE6EAF1),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 27,
            color: selected ? AppColors.royal : AppColors.textGrey,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.navy : AppColors.textDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
// BUSINESS OWNER DASHBOARD (demo UI)
// ============================================================
class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  Widget _metric(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Business Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const Text(
          'Manage your business on MyServe',
          style: TextStyle(color: AppColors.textGrey),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.royal],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${getMyServeProfileName()}!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your business tools are ready to explore.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(Icons.storefront, size: 48, color: AppColors.gold),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _metric(
              '0',
              'Profile Views',
              Icons.visibility_outlined,
              AppColors.royal,
            ),
            const SizedBox(width: 10),
            _metric(
              '0',
              'Enquiries',
              Icons.mark_chat_unread_outlined,
              AppColors.teal,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _metric(
              '0',
              'Bookings',
              Icons.calendar_month_outlined,
              Colors.deepOrange,
            ),
            const SizedBox(width: 10),
            _metric('0.0', 'Rating', Icons.star_outline, AppColors.gold),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Business Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...[
          [
            'Manage Business Profile',
            Icons.store_mall_directory_outlined,
            'Update your business name, description, location and contact details.',
          ],
          [
            'Products & Services',
            Icons.inventory_2_outlined,
            'Add and manage products or services.',
          ],
          [
            'Orders & Bookings',
            Icons.calendar_month_outlined,
            'Review customer requests and bookings.',
          ],
          [
            'Customer Messages',
            Icons.chat_bubble_outline,
            'Reply to customer enquiries.',
          ],
          [
            'Reviews & Ratings',
            Icons.star_outline,
            'See feedback from customers.',
          ],
          [
            'Business Analytics',
            Icons.bar_chart_outlined,
            'Track your business performance.',
          ],
        ].map(
          (item) => Card(
            child: ListTile(
              leading: Icon(item[1] as IconData, color: AppColors.royal),
              title: Text(
                item[0] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(item[2] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (item[0] == 'Products & Services') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductManagementScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${item[0]} will be connected when backend services are added.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// PRODUCTS BACKEND
// Business-owner product CRUD, image upload, and customer catalogue.
// ============================================================

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String? _businessId;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AuthException('Please sign in to manage your products.');
      }

      final business = await _supabase
          .from('businesses')
          .select('id')
          .eq('owner_id', user.id)
          .limit(1)
          .maybeSingle();

      if (business == null) {
        throw const FormatException(
          'Your business profile was not found. Please sign out and sign in again.',
        );
      }

      _businessId = business['id'].toString();
      final rows = await _supabase
          .from('products')
          .select()
          .eq('business_id', _businessId!)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? product}) async {
    final businessId = _businessId;
    if (businessId == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductEditorScreen(businessId: businessId, product: product),
      ),
    );
    if (saved == true) await _loadProducts();
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${product['name']}" from your product list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final imageUrl = product['image_url']?.toString();
      await _supabase
          .from('products')
          .delete()
          .eq('id', product['id'].toString())
          .eq('business_id', _businessId!);

      // Remove the old object only when it belongs to the current user's folder.
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final marker = '/object/public/product-images/';
        final index = imageUrl.indexOf(marker);
        if (index >= 0) {
          final objectPath = imageUrl.substring(index + marker.length);
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null && objectPath.startsWith('$userId/')) {
            try {
              await _supabase.storage.from('product-images').remove([
                objectPath,
              ]);
            } catch (storageError) {
              debugPrint('Product image cleanup failed: $storageError');
            }
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );
      await _loadProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete product: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _productCard(Map<String, dynamic> product) {
    final imageUrl = product['image_url']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = (product['stock_quantity'] as num?)?.toInt() ?? 0;
    final available = product['is_available'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: 88,
                height: 88,
                color: AppColors.lightGray,
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.royal,
                        size: 34,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textGrey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? 'Unnamed product',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Stock: $stock',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    available ? 'Available' : 'Unavailable',
                    style: TextStyle(
                      color: available ? AppColors.teal : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openEditor(product: product),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteProduct(product),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products & Services',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh products',
            onPressed: _loading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _businessId == null ? null : () => _openEditor(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadProducts,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.royal,
                      size: 58,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No products yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add your first product and customers will be able to discover it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Product'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Text(
                    '${_products.length} product${_products.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._products.map(_productCard),
                ],
              ),
            ),
    );
  }
}

class ProductEditorScreen extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic>? product;

  const ProductEditorScreen({
    super.key,
    required this.businessId,
    this.product,
  });

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;
  bool _available = true;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _nameController.text = product['name']?.toString() ?? '';
      _descriptionController.text = product['description']?.toString() ?? '';
      _priceController.text = product['price']?.toString() ?? '0';
      _stockController.text = product['stock_quantity']?.toString() ?? '0';
      _existingImageUrl = product['image_url']?.toString();
      _available = product['is_available'] == true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open image picker: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage() async {
    final image = _selectedImage;
    if (image == null) return _existingImageUrl;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in again.');

    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Image must be 5 MB or smaller.');
    }

    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowed.contains(extension)) {
      throw const FormatException('Choose a JPG, PNG, or WebP image.');
    }

    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await Supabase.instance.client.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(path);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final price = double.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());
      final imageUrl = await _uploadImage();

      final values = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': price,
        'stock_quantity': stock,
        'is_available': _available,
        'image_url': imageUrl,
      };

      if (_isEditing) {
        await supabase
            .from('products')
            .update(values)
            .eq('id', widget.product!['id'].toString())
            .eq('business_id', widget.businessId);
      } else {
        await supabase.from('products').insert({
          ...values,
          'business_id': widget.businessId,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save product: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _selectedImageBytes == null
        ? null
        : Image.memory(_selectedImageBytes!, fit: BoxFit.cover);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Product' : 'Add Product',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: InkWell(
                  onTap: _chooseImage,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 160,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6EAF1)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImage != null
                        ? preview
                        : (_existingImageUrl != null &&
                                  _existingImageUrl!.isNotEmpty
                              ? Image.network(
                                  _existingImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppColors.royal,
                                    size: 38,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: AppColors.royal,
                                      size: 38,
                                    ),
                                    SizedBox(height: 8),
                                    Text('Add Product Image'),
                                  ],
                                )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the image area to choose a photo (max 5 MB).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 22),
              const Text(
                'Product Name',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter product name',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the product name.'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe this product',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Price (₦)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid price.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Stock Quantity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a whole number (0 or more).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.teal,
                title: const Text(
                  'Product is available',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Customers can see available products.'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _saveProduct,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Publish Product',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final rows = await Supabase.instance.client
        .from('products')
        .select(
          'id,business_id,name,description,price,image_url,stock_quantity,is_available,created_at,businesses!inner(name,location,is_active)',
        )
        .eq('is_available', true)
        .eq('businesses.is_active', true)
        .gt('stock_quantity', 0)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() => _productsFuture = _fetchProducts());
    await _productsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load products: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.royal,
                      size: 58,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No products available yet.',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Products published by businesses will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final business =
                    product['businesses'] as Map<String, dynamic>? ?? {};
                final imageUrl = product['image_url']?.toString() ?? '';
                final price = (product['price'] as num?)?.toDouble() ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 13),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: imageUrl.isEmpty
                            ? Container(
                                color: AppColors.lightGray,
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 54,
                                  color: AppColors.royal,
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.lightGray,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 44,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if ((business['name']?.toString() ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  business['name'].toString(),
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if ((product['description']?.toString() ?? '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  product['description'].toString(),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              '₦${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if ((business['location']?.toString() ?? '')
                                .isNotEmpty)
                              Text(
                                business['location'].toString(),
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
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
          );
        },
      ),
    );
  }
}

// ============================================================
// MAIN SHELL (bottom navigation)
// ============================================================
class MainShell extends StatefulWidget {
  final String accountType;
  const MainShell({super.key, this.accountType = 'Customer'});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  List<Widget> get _pages => [
    widget.accountType == 'Business Owner'
        ? const BusinessDashboardScreen()
        : const HomeScreen(),
    const ExploreScreen(),
    const SizedBox(), // placeholder for Create
    const ChatListScreen(),
    ProfileScreen(accountType: widget.accountType),
  ];

  void _onTap(int i) {
    if (i == 2) {
      if (widget.accountType == 'Business Owner') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        );
      }
      return;
    }
    setState(() => _index = i);
  }

  Widget _navItem(IconData icon, String label, int i, {int badge = 0}) {
    final selected = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.royal : AppColors.textGrey,
                ),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.royal : AppColors.textGrey,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.search, 'Explore', 1),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _onTap(2),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ),
              ),
              _navItem(Icons.chat_bubble_outline, 'Chat', 3, badge: 3),
              _navItem(Icons.person_outline, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 3. HOME
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openExplore() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExploreScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stories = [
      'Add Story',
      'Tech Hub',
      'Golden Eats',
      'Fashion World',
      'Auto Care',
    ];
    final matches = kBusinesses.where((business) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty ||
          business.name.toLowerCase().contains(q) ||
          business.category.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 700
              ? (constraints.maxWidth - 680) / 2
              : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              24,
            ),
            children: [
              Row(
                children: [
                  const LogoMark(),
                  const SizedBox(width: 8),
                  const Text(
                    'MyServe',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Messages',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ),
                    icon: const Badge(
                      label: Text('3'),
                      child: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SearchBox(
                hint: 'Search businesses, services or categories...',
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              if (_query.trim().isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.royal],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Support Local\nBusinesses',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Shop • Book • Grow Together',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _openExplore,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.navy,
                              ),
                              child: const Text('Explore Now  →'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => i == 0
                              ? const CreatePostScreen()
                              : const StoryScreen(),
                        ),
                      ),
                      child: SizedBox(
                        width: 68,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.royal,
                              ),
                              child: CircleAvatar(
                                radius: 27,
                                backgroundColor: AppColors.lightGray,
                                child: Icon(
                                  i == 0 ? Icons.add : Icons.storefront,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              stories[i],
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured Businesses',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: _openExplore,
                      child: const Text('See All  ›'),
                    ),
                  ],
                ),
                const FeaturedPostCard(),
                const SizedBox(height: 20),
                const Text(
                  'Nearby Businesses',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...kBusinesses
                    .take(3)
                    .map((business) => NearbyTile(b: business)),
              ] else ...[
                Text(
                  'Search results (${matches.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (matches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 44,
                          color: AppColors.textGrey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No businesses found',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try another name or category.',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  )
                else
                  ...matches.map((business) => NearbyTile(b: business)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openExplore,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Browse all categories'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class FeaturedPostCard extends StatefulWidget {
  const FeaturedPostCard({super.key});

  @override
  State<FeaturedPostCard> createState() => _FeaturedPostCardState();
}

class _FeaturedPostCardState extends State<FeaturedPostCard> {
  bool _liked = false;
  int _likes = 1200;
  final List<String> _comments = [
    'Great food and excellent service!',
    'Do you offer delivery?',
  ];

  Future<void> _addComment() async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Write your comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || comment == null || comment.isEmpty) return;
    setState(() => _comments.add(comment));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Comment added locally.')));
  }

  void _showComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _comments.isEmpty
                      ? const Center(
                          child: Text('No comments yet. Be the first!'),
                        )
                      : ListView.separated(
                          itemCount: _comments.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            title: Text(_comments[i]),
                          ),
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _addComment();
                    },
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Write a comment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sharePost() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this business',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sharing is a frontend demo. External sharing will be connected later.',
                style: TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: AppColors.royal),
                title: const Text('Copy business link'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo link copied locally.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.message_outlined,
                  color: AppColors.teal,
                ),
                title: const Text('Share in MyServe chat'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EDF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BusinessAvatar(b: kGoldenEats, size: 42),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Golden Eats Restaurant',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 4),
                        VerifiedBadge(),
                      ],
                    ),
                    Text(
                      'Restaurant & Food • 1.2 km',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '● Live',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 155,
              width: double.infinity,
              color: const Color(0xFFFFF0D8),
              child: const Icon(
                Icons.rice_bowl_rounded,
                size: 68,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Delicious Meals, Great Moments!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Freshly prepared meals, tasty and affordable. Dine in, takeaway and delivery available.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'From ₦2,000',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14),
                  Text(' Kano, Nigeria', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _liked = !_liked;
                  _likes += _liked ? 1 : -1;
                }),
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? Colors.red : AppColors.textGrey,
                ),
                label: Text(
                  _likes >= 1000
                      ? '${(_likes / 1000).toStringAsFixed(1)}k'
                      : '$_likes',
                  style: TextStyle(
                    color: _liked ? Colors.red : AppColors.textGrey,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _showComments,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text('${_comments.length}'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _sharePost,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const BusinessProfileScreen(business: kGoldenEats),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Contact Business'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = <(IconData, Color, String, String)>[
      (
        Icons.verified_rounded,
        AppColors.teal,
        'Business verified',
        'Tech Hub Solutions is now verified.',
      ),
      (
        Icons.favorite_rounded,
        Colors.red,
        'New activity',
        'Someone liked a featured business post.',
      ),
      (
        Icons.chat_bubble_rounded,
        AppColors.royal,
        'New message',
        'You have a new message waiting in Chat.',
      ),
      (
        Icons.local_offer_rounded,
        AppColors.gold,
        'Special offer',
        'Discover offers from businesses near you.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EDF4)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: item.$2.withValues(alpha: 0.13),
                child: Icon(item.$1, color: item.$2),
              ),
              title: Text(
                item.$3,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.$4),
              ),
              trailing: const Icon(
                Icons.circle,
                size: 8,
                color: AppColors.royal,
              ),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This notification is a frontend demo.'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// 3. EXPLORE
// ============================================================
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final List<List<dynamic>> _categories = const [
    ['Food & Drinks', Icons.restaurant, Colors.orange],
    ['Shopping', Icons.shopping_bag, Colors.purple],
    ['Beauty & Wellness', Icons.spa, Colors.pink],
    ['Auto & Transport', Icons.directions_car, AppColors.royal],
    ['Education', Icons.school, AppColors.navy],
    ['Health & Fitness', Icons.favorite, AppColors.teal],
    ['Tech & Digital', Icons.computer, Colors.indigo],
    ['Home Services', Icons.home_repair_service, Colors.amber],
    ['Real Estate', Icons.apartment, Colors.teal],
    ['Events', Icons.event, Colors.deepPurple],
    ['Agriculture', Icons.agriculture, Colors.green],
    ['More', Icons.more_horiz, Colors.grey],
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = kAllBusinesses
        .where(
          (b) =>
              q.isEmpty ||
              b.name.toLowerCase().contains(q) ||
              b.category.toLowerCase().contains(q),
        )
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Explore',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Find the right business for your needs',
            style: TextStyle(color: AppColors.textGrey),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.navy,
                ),
              ),
              title: const Text(
                'Browse Products',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Explore products listed by MyServe businesses',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerProductsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SearchBox(
            hint: 'Search businesses, services or categories...',
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          const Text(
            'Browse Categories',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                  ? 6
                  : MediaQuery.sizeOf(context).width >= 600
                  ? 5
                  : 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final category = c[0] as String;
              final color = c[2] as Color;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CategoryBusinessesScreen(category: category),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(c[1] as IconData, color: color),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            q.isEmpty
                ? 'Nearby Businesses'
                : 'Search Results (${matches.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No matching businesses found.',
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            )
          else
            ...matches.map((b) => NearbyTile(b: b)),
        ],
      ),
    );
  }
}

class CategoryBusinessesScreen extends StatelessWidget {
  final String category;
  const CategoryBusinessesScreen({super.key, required this.category});

  bool _matchesCategory(Business b) {
    final c = b.category.toLowerCase();
    switch (category) {
      case 'Food & Drinks':
        return c.contains('restaurant') ||
            c.contains('food') ||
            c.contains('drink') ||
            c.contains('cafe');
      case 'Shopping':
        return c.contains('fashion') ||
            c.contains('clothing') ||
            c.contains('retail') ||
            c.contains('shopping');
      case 'Beauty & Wellness':
        return c.contains('beauty') ||
            c.contains('salon') ||
            c.contains('wellness');
      case 'Auto & Transport':
        return c.contains('auto') ||
            c.contains('transport') ||
            c.contains('garage');
      case 'Education':
        return c.contains('education') || c.contains('training');
      case 'Health & Fitness':
        return c.contains('health') ||
            c.contains('pharmacy') ||
            c.contains('fitness');
      case 'Tech & Digital':
        return c.contains('tech') ||
            c.contains('electronics') ||
            c.contains('digital') ||
            c.contains('gadget');
      case 'Home Services':
        return c.contains('home') ||
            c.contains('cleaning') ||
            c.contains('plumb') ||
            c.contains('electric');
      case 'Real Estate':
        return c.contains('real estate') || c.contains('property');
      case 'Events':
        return c.contains('event') || c.contains('photography');
      case 'Agriculture':
        return c.contains('agri') || c.contains('farm');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final businesses = kAllBusinesses.where(_matchesCategory).toList();
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$category Businesses',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Businesses listed under $category',
            style: const TextStyle(color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),
          if (businesses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No businesses found in this category yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'More businesses will appear here when they are added to MyServe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ],
              ),
            )
          else
            ...businesses.map((b) => NearbyTile(b: b)),
        ],
      ),
    );
  }
}

class NearbyTile extends StatelessWidget {
  final Business b;
  const NearbyTile({super.key, required this.b});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BusinessProfileScreen(business: b)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            BusinessAvatar(b: b, size: 58),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          b.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const VerifiedBadge(),
                    ],
                  ),
                  Text(
                    '${b.category} • ${b.distance}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.gold, size: 14),
                      Text(
                        ' ${b.rating} (${b.reviews})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 4. BUSINESS PROFILE
// ============================================================
class BusinessProfileScreen extends StatelessWidget {
  final Business business;
  const BusinessProfileScreen({super.key, required this.business});

  String get _description {
    switch (business.category) {
      case 'Electronics & Gadgets':
        return 'Explore devices, electronics, accessories, repairs, and technology solutions from ${business.name}.';
      case 'Fashion & Clothing':
        return 'Discover clothing, fashion items, styling, and tailoring options from ${business.name}.';
      case 'Auto Services':
        return 'Get vehicle maintenance, diagnostics, repairs, and dependable auto services from ${business.name}.';
      case 'Health & Wellness':
        return 'Learn more about health products and wellness services available from ${business.name}.';
      case 'Restaurant & Food':
        return '${business.name} offers delicious meals, freshly prepared food, and convenient service options.';
      default:
        return 'Discover products and services offered by ${business.name}. Contact the business to learn more.';
    }
  }

  String get _location =>
      business.category == 'Restaurant & Food' ? 'Kano, Nigeria' : 'Local area';

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label will be available when contact services are connected.',
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9EDF4)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 18,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurant = business.category == 'Restaurant & Food';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 190,
                  color: business.color.withValues(alpha: 0.88),
                  child: Center(
                    child: Icon(
                      isRestaurant ? Icons.restaurant_menu : business.icon,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: business.color.withValues(alpha: 0.15),
                      child: Icon(
                        business.icon,
                        color: business.color,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -34,
                  right: 16,
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Following will be available when accounts are connected.',
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Follow'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const VerifiedBadge(),
                    ],
                  ),
                  Text(
                    business.category,
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.gold, size: 18),
                      Text(
                        ' ${business.rating} ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '(${business.reviews} reviews)',
                        style: const TextStyle(color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: business.open ? AppColors.teal : Colors.red,
                        size: 16,
                      ),
                      Text(
                        business.open ? ' Open' : ' Closed',
                        style: TextStyle(
                          color: business.open ? AppColors.teal : Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        '   Hours may vary',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      Expanded(
                        child: Text(
                          ' $_location • ${business.distance}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _action(context, Icons.call, 'Call', AppColors.royal),
                      _action(context, Icons.chat, 'Message', AppColors.teal),
                      _action(
                        context,
                        Icons.directions,
                        'Directions',
                        AppColors.royal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              labelColor: AppColors.royal,
              unselectedLabelColor: AppColors.textGrey,
              indicatorColor: AppColors.royal,
              tabs: [
                const Tab(text: 'About'),
                Tab(text: isRestaurant ? 'Menu' : 'Services'),
                const Tab(text: 'Reviews'),
                const Tab(text: 'Gallery'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_description, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: isRestaurant
                        ? const [
                            _Feature(Icons.restaurant, 'Dine-in'),
                            _Feature(Icons.shopping_bag_outlined, 'Takeaway'),
                            _Feature(Icons.delivery_dining, 'Delivery'),
                            _Feature(Icons.deck, 'Outdoor Seating'),
                          ]
                        : [
                            _Feature(
                              Icons.storefront_outlined,
                              'Local business',
                            ),
                            _Feature(
                              Icons.verified_outlined,
                              'Business profile',
                            ),
                            _Feature(Icons.star_outline, 'Customer rated'),
                          ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Business Information',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Availability'),
                      Text(
                        business.open ? 'Currently open' : 'Currently closed',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_location • ${business.distance} away',
                    style: const TextStyle(color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(business: business),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contact Business'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.navy),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ============================================================
// 5. STORY
// ============================================================
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown.shade900, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black,
                    child: const Icon(
                      Icons.restaurant,
                      color: AppColors.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Golden Eats',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '2h ago',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.coffee, size: 90, color: Colors.white24),
                  const SizedBox(height: 20),
                  const Text(
                    'Good food\nGood mood ❤️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '#GoldenEats',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Send message...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.favorite_border, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 6. CREATE POST
// ============================================================
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  int _type = 0;
  bool _showContact = true;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ['Post', 'Story', 'Product'];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: List.generate(types.length, (i) {
              final sel = _type == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.navy : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        types[i],
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.black,
              child: const Icon(
                Icons.restaurant,
                color: AppColors.gold,
                size: 18,
              ),
            ),
            title: const Text(
              'Golden Eats Restaurant',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add, color: AppColors.royal),
                    Text(
                      'Add Photos/Videos',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ...[Colors.orange.shade200, Colors.red.shade200].map(
                (c) => Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fastfood, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What do you want to share?\ne.g. Special offer, new menu, business update...',
              hintStyle: const TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Add Location', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Kano, Nigeria'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: const [
              Chip(label: Text('Food & Drinks')),
              Chip(label: Text('Restaurant')),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Contact Button'),
            value: _showContact,
            activeThumbColor: AppColors.royal,
            onChanged: (v) => setState(() => _showContact = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Posted successfully!')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Post',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 7. CHAT LIST + CHAT
// ============================================================
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final all = [kGoldenEats, ...kBusinesses];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Chats',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...all.map(
            (b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: BusinessAvatar(b: b, size: 48),
              title: Text(
                b.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Tap to open conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(business: b)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool mine;
  final String time;
  ChatMessage(this.text, this.mine, this.time);
}

class ChatScreen extends StatefulWidget {
  final Business business;
  const ChatScreen({super.key, this.business = kGoldenEats});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      'Hello! 👋\nWelcome to our business chat.\nHow can we help you today?',
      false,
      '10:24 AM',
    ),
    ChatMessage(
      'I would like to know if you have jollof rice available and the price?',
      true,
      '10:26 AM',
    ),
    ChatMessage(
      'Yes! We have jollof rice. It\'s ₦2,000 per plate. You can also add chicken for an extra ₦800.',
      false,
      '10:27 AM',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(t, true, 'Now'));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              child: const Icon(
                Icons.restaurant,
                color: AppColors.gold,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Golden Eats Restaurant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  '● Online',
                  style: TextStyle(fontSize: 11, color: AppColors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.mine ? AppColors.royal : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          m.text,
                          style: TextStyle(
                            color: m.mine ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.time,
                          style: TextStyle(
                            fontSize: 10,
                            color: m.mine ? Colors.white70 : AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.lightGray,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.royal,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 8. PROFILE
// ============================================================
class ProfileScreen extends StatelessWidget {
  final String accountType;
  const ProfileScreen({super.key, this.accountType = 'Customer'});

  Widget _stat(String n, String l) => Column(
    children: [
      Text(
        n,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      Text(l, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final items = <List<dynamic>>[
      ['My Orders', Icons.inventory_2_outlined],
      ['Saved Businesses', Icons.favorite_border],
      ['Notifications', Icons.notifications_none],
      ['Settings', Icons.settings_outlined],
      ['Help & Support', Icons.help_outline],
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Text(
              'Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.lightGray,
                child: Icon(Icons.person, size: 40, color: AppColors.navy),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getMyServeProfileName(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      getMyServeEmail(),
                      style: const TextStyle(color: AppColors.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (accountType == 'Business Owner') ...[
                      const SizedBox(height: 3),
                      Text(
                        getMyServeBusinessName(),
                        style: const TextStyle(
                          color: AppColors.royal,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Edit Profile'),
                          content: const Text(
                            'Profile editing will be connected to your account when the backend is added.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.royal,
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('24', 'Posts'),
              _stat('1.2k', 'Followers'),
              _stat('356', 'Following'),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          ...items.map(
            (e) => ListTile(
              leading: Icon(e[1] as IconData, color: AppColors.navy),
              title: Text(e[0] as String),
              trailing: e[0] == 'Notifications'
                  ? const Badge(label: Text('3'))
                  : const Icon(Icons.chevron_right),
              onTap: () {
                final label = e[0] as String;
                if (label == 'Notifications') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                } else if (label == 'Help & Support') {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Help & Support'),
                      content: const Text(
                        'MyServe support will be available here. This is a frontend demo until backend services are connected.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$label will be connected when backend services are added.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            onTap: () async {
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                debugPrint('Sign out error: $e');
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@mit.edu');
  final _passwordController = TextEditingController(text: '123456');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF3366),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Invalid credentials. Min 6 characters required.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textMutedColor = isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF64748B);
    final cardBg = isDark ? Colors.white.withOpacity(0.03) : Colors.white;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);
    final inputFillColor = isDark ? Colors.white.withOpacity(0.01) : const Color(0xFFF1F5F9);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? const Color(0xFF0284C7).withValues(alpha: 0.15) 
                        : const Color(0xFFE3F2FD).withValues(alpha: 0.5),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? const Color(0xFFE040FB).withValues(alpha: 0.12)
                        : const Color(0xFFFCE7F3).withValues(alpha: 0.4),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding Logo
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/icon/crystal_drop.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LEVELS',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MIT ADT UNIVERSITY • WATER MONITORING SYSTEM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: borderCol,
                            width: 1.5,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'USER EMAIL',
                                  labelStyle: TextStyle(
                                    color: textMutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: textMutedColor,
                                    size: 20,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: inputFillColor,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: 'PASSWORD',
                                  labelStyle: TextStyle(
                                    color: textMutedColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: textMutedColor,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: textMutedColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: inputFillColor,
                                ),
                                validator: (value) {
                                  if (value == null || value.length < 6) {
                                    return 'Min 6 characters required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: auth.isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'SIGN IN',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

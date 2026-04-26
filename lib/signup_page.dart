import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedInputs();
  }

  Future<void> _loadSavedInputs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString('saved_name') ?? '';
      emailController.text = prefs.getString('saved_email') ?? '';
      passwordController.text = prefs.getString('saved_password') ?? '';
    });
  }

  Future<void> _register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_name', nameController.text.trim());
      await prefs.setString('saved_email', emailController.text.trim());
      await prefs.setString('saved_password', passwordController.text.trim());

      final success = await _authService.signUpWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
        nameController.text.trim(),
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created Successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().toLowerCase().contains('rate limit')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Developer rate limit hit! Entering as Testing Guest."),
            backgroundColor: Colors.amber[800],
          ),
        );
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -100,
            child: _buildGlowOrb(350, Color(0xFF7000FF).withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: _buildGlowOrb(400, Color(0xFF00F5FF).withValues(alpha: 0.15)),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 32),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.person_add_outlined,
                          size: 64,
                          color: Color(0xFF00F5FF),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Initialize your security profile",
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                        const SizedBox(height: 40),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildInputField(
                                    controller: nameController,
                                    label: "Full Name",
                                    icon: Icons.person_outline,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputField(
                                    controller: emailController,
                                    label: "Email Address",
                                    icon: Icons.email_outlined,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInputField(
                                    controller: passwordController,
                                    label: "Password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  const SizedBox(height: 40),
                                  _isLoading
                                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F5FF)))
                                      : _buildPrimaryButton("INITIALIZE IDENTITY", _register),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(color: Colors.white38),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Login Terminal",
                                style: TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF00F5FF), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white24,
                      size: 20,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00F5FF), width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF00F5FF), Color(0xFF7000FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00F5FF).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

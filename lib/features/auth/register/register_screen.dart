import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import 'dart:convert';
import 'dart:async';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _realNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _countryController = TextEditingController();

  final List<String> interests = [
    "Music", "Books", "Aesthetics", "Food", "Gaming",
    "Movies", "Anime", "Travel", "Fitness", "Art",
    "Photography", "Tech", "Coding", "Startups",
    "Fashion", "Sports", "Nature", "Meditation"
  ];

  List<String> selectedInterests = [];

  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameError;

  Timer? _debounce;

  // 🔥 FIXED USERNAME CHECK
  void _onUsernameChanged(String value) {
    _debounce?.cancel();

    if (!mounted) return;

    setState(() {
      _isUsernameAvailable = null;
      _usernameError = null;
      _isCheckingUsername = false;
    });

    if (value.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (value.length < 3) {
        if (!mounted) return;
        setState(() {
          _usernameError = "Minimum 3 characters";
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isCheckingUsername = true);

      try {
        final response = await _apiService.post(
          '/users/check-username',
          {'username': value},
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          setState(() {
            _isUsernameAvailable = data['available'];
            _usernameError =
            _isUsernameAvailable! ? null : "Username already taken";
            _isCheckingUsername = false;
          });
        } else {
          setState(() => _isCheckingUsername = false);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isCheckingUsername = false);
      }
    });
  }

  // 🔥 REGISTER FUNCTION (SAFE)
  Future<void> _register() async {
    if (_isUsernameAvailable != true) {
      if (_usernameController.text.isEmpty) {
        setState(() => _usernameError = "Username is required");
      }
      return;
    }

    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one interest")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text;

      final response = await _apiService.post('/auth/register', {
        'real_name': _realNameController.text,
        'email': email,
        'password': _passwordController.text,
        'username': _usernameController.text,
        'age': int.tryParse(_ageController.text) ?? 18,
        'country': _countryController.text,
        'interests': selectedInterests,
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent to your email!")),
        );

        context.push('/verify-otp', extra: email);
      } else {
        final error = jsonDecode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? "Registration failed"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _realNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _countryController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Your real name is private and will never be shown.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // USERNAME FIELD
            TextField(
              controller: _usernameController,
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                hintText: "Username",
                errorText: _usernameError,
                suffixIcon: _isCheckingUsername
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : _isUsernameAvailable == null
                    ? null
                    : Icon(
                  _isUsernameAvailable!
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _isUsernameAvailable!
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),

            const SizedBox(height: 16),
            TextField(controller: _realNameController, decoration: const InputDecoration(hintText: "Real Name")),
            const SizedBox(height: 16),
            TextField(controller: _emailController, decoration: const InputDecoration(hintText: "Email")),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: "Password")),
            const SizedBox(height: 16),
            TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Age")),
            const SizedBox(height: 16),
            TextField(controller: _countryController, decoration: const InputDecoration(hintText: "Country")),

            const SizedBox(height: 24),

            const Text("Select your interests (Max 5)", style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: interests.map((interest) {
                final selected = selectedInterests.contains(interest);

                return GestureDetector(
                  onTap: () {
                    if (!mounted) return;

                    setState(() {
                      if (selected) {
                        selectedInterests.remove(interest);
                      } else {
                        if (selectedInterests.length >= 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Max 5 interests")),
                          );
                          return;
                        }
                        selectedInterests.add(interest);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: (_isLoading || _isUsernameAvailable != true)
                  ? null
                  : _register,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("REGISTER"),
            ),
          ],
        ),
      ),
    );
  }
}
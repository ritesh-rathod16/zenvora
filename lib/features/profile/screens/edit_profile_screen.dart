import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../widgets/safe_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _dobController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isPrivate = false;
  bool _showAge = true;
  bool _showCountry = true;
  bool _showInterests = true;
  String _gender = "prefer_not_to_say";
  List<String> _selectedInterests = [];
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;

  final List<String> _availableInterests = [
    "Technology", "Travel", "Photography", "Gaming",
    "Fitness", "Music", "Fashion", "Education",
    "Business", "Sports", "Food", "Adventure", "Art", "Crypto"
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.profile['full_name'] ?? widget.profile['display_name'] ?? '';
    _usernameController.text = widget.profile['username'] ?? widget.profile['anonymous_username'] ?? '';
    _bioController.text = widget.profile['bio'] ?? '';
    _websiteController.text = widget.profile['website'] ?? '';
    _dobController.text = widget.profile['date_of_birth'] ?? '2000-01-01';
    _countryController.text = widget.profile['country'] ?? 'Global';
    _cityController.text = widget.profile['city'] ?? '';
    _gender = widget.profile['gender'] ?? 'prefer_not_to_say';
    _isPrivate = widget.profile['is_private'] == true;

    final vis = widget.profile['visibility_settings'] as Map? ?? {};
    _showAge = vis['show_age'] ?? true;
    _showCountry = vis['show_country'] ?? true;
    _showInterests = vis['show_interests'] ?? true;

    final ints = widget.profile['interests'] as List? ?? [];
    _selectedInterests = ints.map((e) => e.toString()).toList();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _dobController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String val) async {
    final clean = val.trim().replaceAll('@', '').toLowerCase();
    if (clean.isEmpty || clean == widget.profile['username']) {
      setState(() => _isUsernameAvailable = null);
      return;
    }

    setState(() => _isCheckingUsername = true);
    try {
      final res = await _apiService.get('/users/check-username/$clean');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _isUsernameAvailable = true;
          _isCheckingUsername = false;
        });
      } else if (res.statusCode == 409 && mounted) {
        setState(() {
          _isUsernameAvailable = false;
          _isCheckingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final res = await _apiService.uploadFile('/users/upload-profile-photo', image.path);
        if (res.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo updated!")));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.patch('/users/me/profile', {
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim().replaceAll('@', ''),
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        'gender': _gender,
        'country': _countryController.text.trim(),
        'city': _cityController.text.trim(),
        'interests': _selectedInterests,
        'is_private': _isPrivate,
        'visibility_settings': {
          'show_age': _showAge,
          'show_country': _showCountry,
          'show_interests': _showInterests,
        }
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['user'] != null) {
          const storage = FlutterSecureStorage();
          await storage.write(key: 'user', value: jsonEncode(data['user']));
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully!")));
        Navigator.pop(context, true);
      } else {
        final err = jsonDecode(res.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['detail'] ?? "Failed to update profile")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF6C63FF), size: 28),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar Upload Section
                Center(
                  child: Column(
                    children: [
                      SafeAvatar(
                        avatarUrl: widget.profile['profile_photo_url'] ?? widget.profile['avatar_url'],
                        username: _usernameController.text,
                        radius: 50,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _uploadAvatar,
                        child: const Text("Change Profile Photo", style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 32),

                // 1. Profile Information
                const Text("PROFILE INFORMATION", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: _fullNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Full Name (Display Name)"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _checkUsername,
                  decoration: InputDecoration(
                    labelText: "Username",
                    suffixIcon: _isCheckingUsername
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : (_isUsernameAvailable == true
                            ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                            : (_isUsernameAvailable == false ? const Icon(Icons.cancel, color: Colors.redAccent) : null)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Bio"),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _websiteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Website"),
                ),

                const SizedBox(height: 28),
                // 2. Personal Information
                const Text("PERSONAL INFORMATION", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: _dobController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Date of Birth (YYYY-MM-DD)"),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: ["male", "female", "other", "prefer_not_to_say"].contains(_gender) ? _gender : "prefer_not_to_say",
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Gender"),
                  items: const [
                    DropdownMenuItem(value: "female", child: Text("Female")),
                    DropdownMenuItem(value: "male", child: Text("Male")),
                    DropdownMenuItem(value: "other", child: Text("Other")),
                    DropdownMenuItem(value: "prefer_not_to_say", child: Text("Prefer not to say")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _gender = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _countryController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Country"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "City"),
                ),

                const SizedBox(height: 28),
                // 3. Interests
                const Text("INTERESTS", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableInterests.map((interest) {
                    final isSelected = _selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6C63FF),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedInterests.add(interest);
                          } else {
                            _selectedInterests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),
                // 4. Privacy & Visibility
                const Text("PRIVACY & VISIBILITY", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("Private Account", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _isPrivate,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) => setState(() => _isPrivate = val),
                ),
                SwitchListTile(
                  title: const Text("Show Age on Profile", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _showAge,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) => setState(() => _showAge = val),
                ),
                SwitchListTile(
                  title: const Text("Show Country on Profile", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _showCountry,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) => setState(() => _showCountry = val),
                ),
                SwitchListTile(
                  title: const Text("Show Interests on Profile", style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: _showInterests,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) => setState(() => _showInterests = val),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

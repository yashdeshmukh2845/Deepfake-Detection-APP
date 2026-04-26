import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'main.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _stats = {'total_scans': 0, 'fake_detections': 0};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _nameController.text = user.userMetadata?['name'] ?? '';
      _emailController.text = user.email ?? '';
    }
    
    setState(() => _isLoading = true);
    final userId = user!.id;

    try {
      final profile = await _dbService.getProfile(userId);
      final settings = await _dbService.getUserSettings(userId);
      final stats = await _dbService.getStats(userId);
      
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('dark_mode') ?? true;

      setState(() {
        _profile = profile;
        _settings = settings;
        _stats = stats;
        if (profile?['name'] != null) _nameController.text = profile!['name'];
        if (profile?['email'] != null) _emailController.text = profile!['email'];
        _isLoading = false;
      });
      
      DeepfakeApp.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading profile: $e")),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser!.id;
      final publicUrl = await _dbService.uploadProfileImage(userId, File(image.path));

      if (publicUrl != null) {
        await _dbService.updateProfile(userId: userId, imageUrl: publicUrl);
        await _loadData();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image")),
        );
      }
    }
  }

  Future<void> _updateName() async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Update DB
    await _dbService.updateProfile(userId: userId, name: _nameController.text);
    
    // Update Auth Metadata
    await _supabase.auth.updateUser(
      UserAttributes(data: {'name': _nameController.text}),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated")),
    );
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final userId = _supabase.auth.currentUser!.id;
    setState(() => _settings[key] = value);
    
    if (key == 'dark_mode') {
      DeepfakeApp.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
    }
    
    await _dbService.updateSettings(userId, {key: value});
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("This will permanently delete your account and all scan data. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser!.id;
      await _dbService.deleteAccount(userId);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Info Section
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: _profile?['profile_image_url'] != null
                        ? NetworkImage(_profile!['profile_image_url'])
                        : null,
                    child: _profile?['profile_image_url'] == null
                        ? Icon(Icons.person, size: 60, color: colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Name",
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _updateName(),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email (Read-only)",
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 30),

            // Stats Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(context, "Total Scans", _stats['total_scans'].toString(), Icons.analytics),
                  _buildStat(context, "Fakes Found", _stats['fake_detections'].toString(), Icons.warning, color: Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Settings Section
            _buildSectionHeader("App Settings"),
            _buildSettingTile(
              "Dark Mode",
              "Use high-contrast dark theme",
              Icons.dark_mode,
              _settings['dark_mode'] ?? true,
              (val) => _toggleSetting('dark_mode', val),
            ),
            _buildSettingTile(
              "Auto-save History",
              "Store scan results in cloud automatically",
              Icons.cloud_upload,
              _settings['auto_save_history'] ?? true,
              (val) => _toggleSetting('auto_save_history', val),
            ),
            _buildSettingTile(
              "Notifications",
              "Get alerts for new features",
              Icons.notifications,
              _settings['notifications_enabled'] ?? true,
              (val) => _toggleSetting('notifications_enabled', val),
            ),
            const SizedBox(height: 30),

            // Account Actions
            _buildSectionHeader("Account"),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text("Logout"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await _authService.signOut();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: _deleteAccount,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, IconData icon, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color ?? colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00F5FF),
      ),
    );
  }
}

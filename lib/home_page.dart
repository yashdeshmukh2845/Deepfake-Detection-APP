import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'result_page.dart';
import 'model_service.dart';
import 'login_page.dart';
import 'history_page.dart';
import 'services/auth_service.dart';
import 'profile_settings_page.dart';
import 'services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String fileName = "No Media Selected";
  XFile? selectedMedia;
  bool isVideo = false;
  bool _isLoading = false;
  
  final ModelService _modelService = ModelService();
  final AuthService _authService = AuthService();

  Future<void> _pickMedia(ImageSource source, {bool pickVideo = false}) async {
    final XFile? media = pickVideo
        ? await _modelService.pickVideo(source)
        : await _modelService.pickImage(source);
    if (media != null) {
      setState(() {
        fileName = media.name;
        selectedMedia = media;
        isVideo = pickVideo;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (selectedMedia == null) return;
    
    setState(() => _isLoading = true);
    try {
      final results = await _modelService.runInference(selectedMedia!);
      final String engineName = results['source'] ?? "Deep Guard AI";

      if (results['result'] == 'Error') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(results['message'] ?? "Detection failed. Please check backend."),
            backgroundColor: Colors.red[700],
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(
            result: results['result'] ?? "Error",
            confidence: results['confidence'] ?? "0.00",
            message: results['message'],
            source: engineName,
            mediaUrl: selectedMedia!.path, // Note: This will be local path for now, upload handled in ResultPage
            isVideo: isVideo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection error. Is the backend running?"),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await _authService.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeroBanner(context),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),

                  _sectionLabel("UPLOAD CONTENT"),
                  SizedBox(height: 12),
                  _buildSelectionCard(),

                  SizedBox(height: 28),

                  if (selectedMedia != null) ...[
                    _sectionLabel("MEDIA PREVIEW"),
                    SizedBox(height: 12),
                    _buildPreviewCard(),
                    SizedBox(height: 28),
                  ],

                  _buildAnalyzeButton(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 16, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1040),
            Color(0xFF0D1B3E),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1A1040).withOpacity(0.5),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFF818CF8), size: 26),
                  SizedBox(width: 10),
                  Text(
                    "Deep Guard AI",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _headerIconButton(
                    icon: Icons.history_rounded,
                    tooltip: "Detection History",
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const HistoryPage())),
                  ),
                  SizedBox(width: 4),
                  _headerIconButton(
                    icon: Icons.person_rounded,
                    tooltip: "User Profile",
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const ProfileSettingsPage())),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 24),

          Text(
            "HIGH FIDELITY ANALYSIS",
            style: TextStyle(
              color: Color(0xFF818CF8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Verify the Truth",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Upload any image or video and let our AI detect deepfake manipulation.",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isDestructive ? Colors.redAccent[100] : Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey[400],
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _pickButton(Icons.photo_library_rounded, "Photo\nGallery", ImageSource.gallery, false, Color(0xFF6C63FF))),
              _verticalDivider(),
              Expanded(child: _pickButton(Icons.camera_alt_rounded, "Take\nPhoto", ImageSource.camera, false, Color(0xFF3B82F6))),
            ],
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Row(
            children: [
              Expanded(child: _pickButton(Icons.video_library_rounded, "Video\nGallery", ImageSource.gallery, true, Color(0xFF0EA5E9))),
              _verticalDivider(),
              Expanded(child: _pickButton(Icons.videocam_rounded, "Record\nVideo", ImageSource.camera, true, Color(0xFF8B5CF6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 70, color: Colors.grey[100]);

  Widget _pickButton(IconData icon, String label, ImageSource source, bool pickVideo, Color color) {
    return InkWell(
      onTap: () => _pickMedia(source, pickVideo: pickVideo),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[700],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            isVideo
                ? Container(
                    height: 240,
                    width: double.infinity,
                    color: Color(0xFF1E1B4B),
                    child: Icon(Icons.movie_creation_rounded, size: 72, color: Color(0xFF818CF8)),
                  )
                : (kIsWeb
                    ? Image.network(selectedMedia!.path, height: 240, width: double.infinity, fit: BoxFit.cover)
                    : Image.file(File(selectedMedia!.path), height: 240, width: double.infinity, fit: BoxFit.cover)),

            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() {
                  selectedMedia = null;
                  fileName = "No Media Selected";
                  isVideo = false;
                }),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    bool isReady = selectedMedia != null;

    return Column(
      children: [
        GestureDetector(
          onTap: (isReady && !_isLoading) ? _analyzeImage : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isReady
                  ? LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)])
                  : LinearGradient(colors: [Colors.grey[300]!, Colors.grey[300]!]),
              boxShadow: isReady
                  ? [BoxShadow(color: Color(0xFF6C63FF).withOpacity(0.45), blurRadius: 20, offset: Offset(0, 8))]
                  : [],
            ),
            child: Center(
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                        SizedBox(width: 14),
                        Text("Analyzing...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_rounded, color: isReady ? Colors.white : Colors.grey[500], size: 22),
                        SizedBox(width: 12),
                        Text(
                          "START AI DETECTION",
                          style: TextStyle(
                            color: isReady ? Colors.white : Colors.grey[500],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (!isReady)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              "Select an image or video above to begin",
              style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
            ),
          ),
      ],
    );
  }
}

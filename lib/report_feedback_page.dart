import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ReportFeedbackPage extends StatefulWidget {
  final String mediaUrl;
  final String result;
  final double confidence;
  final String? scanId;
  final bool isVideo;

  const ReportFeedbackPage({
    super.key,
    required this.mediaUrl,
    required this.result,
    required this.confidence,
    this.scanId,
    this.isVideo = false,
  });

  @override
  State<ReportFeedbackPage> createState() => _ReportFeedbackPageState();
}

class _ReportFeedbackPageState extends State<ReportFeedbackPage> {
  final _dbService = DatabaseService();
  final _supabase = Supabase.instance.client;
  final _feedbackController = TextEditingController();
  bool _isIncorrect = false;
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.isEmpty && !_isIncorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide some feedback or mark as incorrect")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // If scanId is null (e.g. auto-save was OFF), we still report with the local media path or we could upload it now.
      // But according to requirements, we pass the mediaUrl. 
      // If auto-save was OFF, mediaUrl is still the local path.
      
      String finalMediaUrl = widget.mediaUrl;
      
      // If it's a local path, we should upload it so the admin can see it.
      if (!widget.mediaUrl.startsWith('http')) {
        if (kIsWeb) {
          final response = await http.get(Uri.parse(widget.mediaUrl));
          final Uint8List bytes = response.bodyBytes;
          final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final path = 'reports/$userId/$fileName';
          
          await _supabase.storage.from('reports').uploadBinary(path, bytes);
          finalMediaUrl = _supabase.storage.from('reports').getPublicUrl(path);
        } else {
          final file = File(widget.mediaUrl);
          final fileExt = file.path.split('.').last;
          final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final path = 'reports/$userId/$fileName';
          
          await _supabase.storage.from('reports').upload(path, file);
          finalMediaUrl = _supabase.storage.from('reports').getPublicUrl(path);
        }
      }

      await _dbService.submitReport(
        userId: userId,
        scanId: widget.scanId,
        mediaUrl: finalMediaUrl,
        predictedResult: widget.result.toLowerCase(),
        confidence: widget.confidence,
        isIncorrect: _isIncorrect,
        feedbackText: _feedbackController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback submitted successfully. Thank you!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting feedback: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = widget.isVideo;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report & Feedback"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview Section (Read Only)
            const Text("ANALYZED CONTENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.black12,
                child: isVideo 
                  ? const Center(child: Icon(Icons.videocam, size: 50, color: Colors.grey))
                  : (widget.mediaUrl.startsWith('http') || kIsWeb
                      ? Image.network(
                          widget.mediaUrl, 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Preview not available", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      : Image.file(File(widget.mediaUrl), fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 20),
            
            // Result Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip("Result", widget.result.toUpperCase(), 
                  widget.result.toLowerCase() == 'real' ? Colors.green : Colors.red),
                _buildInfoChip("Confidence", "${widget.confidence.toStringAsFixed(1)}%", Colors.blue),
              ],
            ),
            const Divider(height: 40),

            // Feedback Section
            const Text("GIVE YOUR FEEDBACK", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            
            CheckboxListTile(
              title: const Text("This result is incorrect"),
              subtitle: const Text("Check this if the AI failed to detect correctly"),
              value: _isIncorrect,
              onChanged: (val) => setState(() => _isIncorrect = val ?? false),
              activeColor: Colors.orange,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Tell us more about this content or why the result might be wrong...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              child: _isSubmitting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("SUBMIT REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'report_feedback_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _dbService = DatabaseService();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final userId = user.id;
      final history = await _dbService.getScanHistory(userId);
      if (mounted) {
        setState(() {
          _historyItems = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading history: $e")),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detection History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
              ? _buildEmptyState(colorScheme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    final result = item['result'] ?? "Unknown";
                    final confidence = item['confidence']?.toString() ?? "0.0";
                    final createdAtStr = item['created_at'];
                    final createdAt = createdAtStr != null 
                        ? DateTime.parse(createdAtStr).toLocal() 
                        : DateTime.now();
                    final mediaUrl = item['media_url'] ?? '';

                    final bool isReal = result.toLowerCase() == "real";
                    final Color accentColor = isReal ? Colors.green[700]! : Colors.red[700]!;
                    final Color cardColor = isReal
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.08);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: accentColor.withValues(alpha: 0.1),
                                child: mediaUrl.isNotEmpty
                                    ? Image.network(mediaUrl, fit: BoxFit.cover, 
                                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: accentColor))
                                    : Icon(Icons.image, color: accentColor),
                              ),
                            ),
                            title: Text(
                              result.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: accentColor),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Confidence: $confidence%"),
                                Text(
                                  "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "#${_historyItems.length - index}",
                                style: TextStyle(fontWeight: FontWeight.bold, color: accentColor),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReportFeedbackPage(
                                          mediaUrl: mediaUrl,
                                          result: result,
                                          confidence: double.tryParse(confidence) ?? 0.0,
                                          scanId: item['id'],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.report_problem_outlined, size: 18, color: Colors.orange),
                                  label: const Text("Report", style: TextStyle(color: Colors.orange)),
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
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 80, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            "No Cloud History",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
          ),
          const Text("Your synced results will appear here."),
        ],
      ),
    );
  }
}

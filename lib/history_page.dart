import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// HISTORY PAGE
// Shows all past detection results saved on this device.
// Results are loaded from SharedPreferences (local storage).
// ============================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // This list will hold all saved history items
  List<String> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory(); // Load saved results when page opens
  }

  // Read the saved history from local storage
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // We saved history as a list of strings
    final List<String> saved = prefs.getStringList('detection_history') ?? [];
    setState(() {
      // Show newest first by reversing the list
      _historyItems = saved.reversed.toList();
    });
  }

  // Clear all history from local storage
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('detection_history');
    setState(() {
      _historyItems = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("History cleared!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Detection History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Trash icon button to clear all history
          if (_historyItems.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              icon: Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: "Clear All History",
            ),
        ],
      ),
      body: _historyItems.isEmpty
          // Show this if there are no results saved yet
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 80, color: colorScheme.outline),
                  SizedBox(height: 16),
                  Text(
                    "No history yet",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    "Your detection results will appear here.",
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            )
          // Show the list of saved results
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _historyItems.length,
              itemBuilder: (context, index) {
                // Each item is stored as "Result|Confidence|RiskLevel|DateTime"
                final parts = _historyItems[index].split('|');
                final result = parts.length > 0 ? parts[0] : "Unknown";
                final confidence = parts.length > 1 ? parts[1] : "0.00";
                final riskLevel = parts.length > 2 ? parts[2] : "N/A";
                final dateTime = parts.length > 3 ? parts[3] : "";

                // Pick card color depending on the result
                final bool isReal = result.toLowerCase() == "real";
                final bool isError = result.toLowerCase() == "error";
                final Color cardColor = isReal
                    ? Colors.green.withOpacity(0.12)
                    : isError
                        ? Colors.amber.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12);
                final Color accentColor = isReal
                    ? Colors.green[700]!
                    : isError
                        ? Colors.amber[800]!
                        : Colors.red[700]!;

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: accentColor.withOpacity(0.4)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon on the left
                        CircleAvatar(
                          backgroundColor: accentColor.withOpacity(0.15),
                          child: Icon(
                            isReal ? Icons.verified_rounded : isError ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
                            color: accentColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        // Text info on the right
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor),
                              ),
                              Text(
                                "Confidence: $confidence%  •  $riskLevel",
                                style: TextStyle(fontSize: 13, color: accentColor.withOpacity(0.8)),
                              ),
                              if (dateTime.isNotEmpty)
                                Text(
                                  dateTime,
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        // Index number badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "#${index + 1}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

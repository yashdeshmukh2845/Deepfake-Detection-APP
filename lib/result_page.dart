import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// RESULT PAGE — Deep Guard AI
// Shows the deepfake detection verdict with:
//   - Color-coded result card (Green = Real, Red = Fake)
//   - Risk Level indicator
//   - Share Result button
//   - Try Again / Back to Home button
//   - Gradient background
// ============================================================
class ResultPage extends StatefulWidget {
  // These variables are passed from the HomePage
  final String result;      // "Real", "Fake", or "Error"
  final String confidence;  // Percentage string e.g. "92.50"
  final String? message;    // Optional message (engine used, error info)
  final String? source;     // Which engine ran the detection ("Sightengine AI" etc.)

  const ResultPage({super.key, required this.result, required this.confidence, this.message, this.source});

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {

  @override
  void initState() {
    super.initState();
    // As soon as we arrive on this page, save the result to history
    _saveToHistory();
  }

  // ─── FEATURE 1: SAVE TO HISTORY ──────────────────────────────────────
  // Saves this result to the SharedPreferences history list.
  Future<void> _saveToHistory() async {
    // Don't save if it was an error
    if (widget.result.toLowerCase() == "error") return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList('detection_history') ?? [];

    // Get current date and time string for the record
    final now = DateTime.now();
    final dateString = "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";

    // Store as a pipe-separated string for easy parsing later
    final riskLevel = getRiskLevel(double.tryParse(widget.confidence) ?? 0);
    existing.add("${widget.result}|${widget.confidence}|$riskLevel|$dateString");

    // Keep at most last 50 results
    if (existing.length > 50) existing.removeAt(0);

    await prefs.setStringList('detection_history', existing);
  }

  // ─── FEATURE 2: RISK LEVEL FUNCTION ──────────────────────────────────
  // Takes the confidence value and returns a simple risk description.
  String getRiskLevel(double confidence) {
    if (widget.result.toLowerCase() == "real") {
      // For REAL media, confidence means how sure it's genuine
      if (confidence > 80) return "Low Risk";
      if (confidence > 50) return "Medium Risk";
      return "High Risk";
    } else {
      // For FAKE media, high confidence means strongly manipulated
      if (confidence > 80) return "High Risk";
      if (confidence > 50) return "Medium Risk";
      return "Low Risk";
    }
  }

  // Returns the right color emoji for the risk badge display
  String getRiskEmoji(double confidence) {
    final level = getRiskLevel(confidence);
    if (level == "Low Risk") return "🟢 Low Risk";
    if (level == "Medium Risk") return "🟡 Medium Risk";
    return "🔴 High Risk";
  }

  // Returns a Color for the risk badge widget
  Color getRiskColor(double confidence) {
    final level = getRiskLevel(confidence);
    if (level == "Low Risk") return Colors.green[600]!;
    if (level == "Medium Risk") return Colors.amber[700]!;
    return Colors.red[600]!;
  }

  // ─── SHARE RESULT ─────────────────────────────────────────────────────
  void _shareResult() {
    final double conf = double.tryParse(widget.confidence) ?? 0;
    final String risk = getRiskEmoji(conf);
    // Show engine name in the share text if available
    final String engine = widget.source ?? "Deep Guard AI";

    final String shareText =
        "Deep Guard AI - Detection Report\n\n"
        "Verdict: ${widget.result.toUpperCase()}\n"
        "Confidence: ${widget.confidence}%\n"
        "Risk Level: $risk\n"
        "Detection Engine: $engine\n\n"
        "Detected using Deep Guard AI deepfake detection app.";

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final double conf = double.tryParse(widget.confidence) ?? 0;

    // Determine display properties based on result
    final bool isReal = widget.result.toLowerCase() == "real";
    final bool isError = widget.result.toLowerCase() == "error";

    // ─── FEATURE 3: DYNAMIC CARD COLORS ─────────────────────────────────
    final Color statusColor = isReal
        ? Colors.green[600]!
        : isError
            ? Colors.amber[700]!
            : Colors.red[600]!;

    final Color gradientStart = isReal
        ? Colors.green[50]!
        : isError
            ? Colors.amber[50]!
            : Colors.red[50]!;

    final IconData statusIcon = isReal
        ? Icons.verified_rounded
        : isError
            ? Icons.info_outline_rounded
            : Icons.warning_amber_rounded;

    final String verdictText = isReal
        ? "CONTENT IS REAL"
        : isError
            ? "ANALYSIS FAILED"
            : "CONTENT IS FAKE";

    final String subText = isReal
        ? "AI did not detect any manipulation."
        : isError
            ? "Something went wrong during analysis."
            : "Potential deepfake manipulation detected.";

    // Which engine powered this detection
    final String engineLabel = widget.source ?? "Deep Guard AI";
    final bool isSightengine = engineLabel.toLowerCase().contains("sightengine");

    return Scaffold(
      // AppBar with transparent background to let gradient show through
      appBar: AppBar(
        title: Text("Analysis Report", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // ─── FEATURE 3: GRADIENT BACKGROUND ────────────────────────────────
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradientStart,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: [0.0, 0.4],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [

              // ─── STATUS ICON CIRCLE ────────────────────────────────────
              Container(
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                ),
                child: Icon(statusIcon, size: 90, color: statusColor),
              ),
              SizedBox(height: 24),

              // ─── FEATURE 3: VERDICT TEXT (bold, large) ─────────────────
              Text(
                verdictText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900, // extra bold
                  color: statusColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                subText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),

              // ─── FEATURE 2: RISK LEVEL BADGE ────────────────────────────
              if (!isError) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: getRiskColor(conf).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: getRiskColor(conf).withOpacity(0.4)),
                  ),
                  child: Text(
                    getRiskEmoji(conf),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: getRiskColor(conf),
                    ),
                  ),
                ),
                SizedBox(height: 28),
              ],

              // ─── CONFIDENCE SCORE CARD ────────────────────────────────
              if (!isError) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          "CONFIDENCE SCORE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.outline,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 12),
                        // Big confidence number
                        Text(
                          "${widget.confidence}%",
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: -2,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Progress bar showing the confidence visually
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: conf / 100,
                            minHeight: 12,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            color: statusColor,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Higher score = higher certainty",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Show detection engine source
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.1)),
                  ),
                  child: Text(
                    "ANALYSIS BY: ${engineLabel.toUpperCase()}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor.withOpacity(0.8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],

              // ─── FEATURE 9: ERROR MESSAGE BOX ───────────────────────────
              if (widget.message != null && widget.message!.isNotEmpty && isError) ...[
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.amber[800]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message!,
                          style: TextStyle(fontSize: 14, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 40),

              // ─── FEATURE 5: SHARE RESULT BUTTON ─────────────────────────
              if (!isError) ...[
                ElevatedButton.icon(
                  onPressed: _shareResult,
                  icon: Icon(Icons.share_rounded),
                  label: Text("SHARE RESULT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                SizedBox(height: 12),
              ],

              // ─── FEATURE 6: TRY AGAIN / BACK BUTTON ─────────────────────
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded),
                label: Text("TRY AGAIN / GO BACK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
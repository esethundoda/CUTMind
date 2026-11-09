import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'counselling_screen.dart';
import '../services/forest_model.dart';
import '../theme/app_theme.dart';
import '../config/dev_flags.dart';

class MLResultScreen extends StatefulWidget {
  const MLResultScreen({super.key});

  @override
  State<MLResultScreen> createState() => _MLResultScreenState();
}

class _MLResultScreenState extends State<MLResultScreen> {
  Map<String, double>? _latestSurvey;
  bool _loading = true;
  ForestModel? _model;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _fetchLatestSurvey();
  }

  /// Loads the Random Forest trained offline in Python (assets/model/cutmind_forest.json).
  Future<void> _loadModel() async {
    try {
      final m = await ForestModel.load();
      if (mounted) setState(() => _model = m);
    } catch (e) {
      if (mounted) setState(() => _modelError = e.toString());
    }
  }

  Future<void> _fetchLatestSurvey() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('surveys')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;

    if (snap.docs.isNotEmpty) {
      final d = snap.docs.first.data();
      setState(() {
        _latestSurvey = {
          'stress': (d['stress'] as num?)?.toDouble() ?? 3,
          'anxiety': (d['anxiety'] as num?)?.toDouble() ?? 3,
          'sleep': (d['sleep'] as num?)?.toDouble() ?? 3,
          'motivation': (d['motivation'] as num?)?.toDouble() ?? 3,
          'social': (d['social'] as num?)?.toDouble() ?? 3,
        };
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  // Order MUST match the training data: stress, anxiety, sleep, motivation, social.
  Prediction _predict(Map<String, double> s) => _model!.predict([
        s['stress']!, s['anxiety']!, s['sleep']!, s['motivation']!, s['social']!,
      ]);

  /// UI has three states. The two-class CUT model's 'at_risk' class is shown as 'high',
  /// which shows the "Elevated anxiety risk" card and the student-controlled support card.
  String _riskKey(String label) => label == 'at_risk' ? 'high' : label;

  static const _featureNames = {
    'stress': 'Stress Level',
    'anxiety': 'Anxiety',
    'sleep': 'Sleep Quality',
    'motivation': 'Motivation',
    'social': 'Social Connection',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(title: const Text('Wellness report')),
      body: (_loading || (_model == null && _modelError == null))
        ? const Center(child: CircularProgressIndicator())
        : _modelError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text('Could not load the prediction model.\n$_modelError',
                textAlign: TextAlign.center)))
          : _latestSurvey == null
            ? _noDataView()
            : _resultView(_latestSurvey!),
    );
  }

  Widget _noDataView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 200, height: 200,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.sand, shape: BoxShape.circle),
          child: Image.asset(AppAssets.onboardCheckin, fit: BoxFit.contain),
        ),
        const SizedBox(height: 22),
        Text('No check-ins yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Complete a daily check-in first and your wellness report will appear here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, height: 1.6, color: AppColors.muted)),
      ]),
    ),
  );

  Widget _resultView(Map<String, double> survey) {
    final pred = _predict(survey);
    final risk = _riskKey(pred.label);
    // Technical outputs (probabilities, SHAP-style contributions) are used only
    // internally to decide WHICH factors to talk about. They are never shown as numbers.
    final influences = _rankInfluences(pred, survey);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _riskCard(risk),
          const SizedBox(height: 14),
          _weeklyTrendCard(),
          const SizedBox(height: 18),
          _whatShapedCard(influences, risk),
          const SizedBox(height: 18),
          _surveyBreakdownCard(survey),
          const SizedBox(height: 18),
          if (risk == 'high') _escalationCard(context),
          if (risk == 'high') const SizedBox(height: 18),
          _guidanceCard(risk, influences),
          const SizedBox(height: 18),
          _screeningNote(),
          if (kShowModelDiagnostics) ...[
            const SizedBox(height: 18),
            _developerDiagnostics(pred),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Student-facing explanation (plain language, no model metrics)
  // ---------------------------------------------------------------------------

  /// Turns the model's per-factor contributions into a ranked list of plain-language
  /// influences. Only the direction and rough strength are kept, never the numbers.
  List<_Influence> _rankInfluences(Prediction pred, Map<String, double> survey) {
    final list = pred.contributions.entries.map((e) {
      return _Influence(key: e.key, value: e.value, score: survey[e.key] ?? 3);
    }).toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    if (list.isEmpty) return list;
    final maxAbs = list.first.value.abs();
    for (final i in list) {
      final r = maxAbs == 0 ? 0 : i.value.abs() / maxAbs;
      i.strength = r >= .66 ? 'big' : (r >= .33 ? 'some' : 'small');
    }
    return list;
  }

  String _plainSentence(_Influence i) {
    final label = _featureNames[i.key] ?? i.key;
    final raising = i.value > 0;
    const how = {'big': 'a big part', 'some': 'some part', 'small': 'a small part'};
    final part = how[i.strength]!;
    final detail = _describeScore(i.key, i.score);
    return raising
        ? '$label ($detail) played $part in your result.'
        : '$label ($detail) is working in your favour.';
  }

  String _describeScore(String key, double v) {
    final high = v >= 4, low = v <= 2;
    switch (key) {
      case 'stress':
        return high ? 'feeling very stressed' : low ? 'feeling fairly calm' : 'moderate stress';
      case 'anxiety':
        return high ? 'feeling quite anxious' : low ? 'little anxiety' : 'some anxiety';
      case 'sleep':
        return high ? 'sleeping well' : low ? 'sleeping poorly' : 'average sleep';
      case 'motivation':
        return high ? 'feeling motivated' : low ? 'low motivation' : 'average motivation';
      case 'social':
        return high ? 'feeling well connected' : low ? 'feeling disconnected' : 'some connection';
    }
    return '';
  }

  Widget _whatShapedCard(List<_Influence> influences, String risk) {
    final raising = influences.where((i) => i.value > 0).take(3).toList();
    final helping = influences.where((i) => i.value <= 0).take(2).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What shaped your result',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('These are the parts of your check-in that mattered most today.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 14),
        if (raising.isNotEmpty) ...[
          _sectionLabel('Areas that need care', const Color(0xFFB6814D)),
          ...raising.map((i) => _influenceRow(i, const Color(0xFFCB8C84), Icons.arrow_upward_rounded)),
        ],
        if (helping.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionLabel('Things going well', const Color(0xFF5E8C79)),
          ...helping.map((i) => _influenceRow(i, const Color(0xFF739C8A), Icons.favorite_rounded)),
        ],
      ]),
    );
  }

  Widget _sectionLabel(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _influenceRow(_Influence i, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color.withOpacity(.18), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_plainSentence(i),
                  style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: Colors.grey[800]))),
        ]),
      );

  Widget _screeningNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E8E4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF739C8A), size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
            'This is a wellness check, not a medical diagnosis. It compares your answers with '
            'patterns seen in other CUT students and is meant to help you notice how you are '
            'doing. If you are worried about how you feel, please speak to someone you trust '
            'or CUT Counselling Services.',
            style: GoogleFonts.poppins(fontSize: 11.5, height: 1.5, color: Colors.grey[700]),
          )),
        ]),
      );

  /// Hidden by default (kShowModelDiagnostics = false). For the researcher only.
  Widget _developerDiagnostics(Prediction pred) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          'DEV ONLY: Random Forest (${_model!.treeCount} trees), n=${_model!.trainingSamples}, '
          'label=${_model!.labelSource.toUpperCase()}\n'
          'P(${pred.focusClass}) = ${(pred.probabilities[pred.focusClass] ?? 0).toStringAsFixed(2)}, '
          'baseline = ${pred.baseline.toStringAsFixed(2)}\n'
          '${pred.contributions.entries.map((e) => '${e.key}: ${(e.value * 100).toStringAsFixed(1)}').join(', ')}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      );

  Widget _weeklyTrendCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).collection('surveys')
          .orderBy('timestamp', descending: true).limit(7).get(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs.reversed.toList() ?? [];
        if (snapshot.connectionState == ConnectionState.waiting || docs.length < 2) return const SizedBox.shrink();
        final bars = docs.asMap().entries.map((entry) {
          final d = entry.value.data();
          final stress = (d['stress'] as num?)?.toDouble() ?? 3;
          final anxiety = (d['anxiety'] as num?)?.toDouble() ?? 3;
          final sleep = (d['sleep'] as num?)?.toDouble() ?? 3;
          final motivation = (d['motivation'] as num?)?.toDouble() ?? 3;
          final social = (d['social'] as num?)?.toDouble() ?? 3;
          final wellbeing = ((6 - stress) + (6 - anxiety) + sleep + motivation + social) / 5;
          return BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: wellbeing, width: 15, color: const Color(0xFF739C8A), borderRadius: BorderRadius.circular(6))]);
        }).toList();
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0xFF243342).withOpacity(.04), blurRadius: 18, offset: const Offset(0, 5))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your recent check-ins', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF243342))),
            const SizedBox(height: 4),
            Text('A simple view of your overall wellbeing ratings (out of 5).', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 18),
            SizedBox(height: 150, child: BarChart(BarChartData(
              minY: 0, maxY: 5, barGroups: bars,
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFE9EEEA), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt() + 1}',
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
            ))),
          ]),
        );
      },
    );
  }

  Widget _riskCard(String risk) {
    Color bg;
    Color tint;
    String asset, title, subtitle;
    if (risk == 'high') {
      bg = const Color(0xFF9B5C59);
      tint = const Color(0xFFF8E5E1);
      asset = AppAssets.supportHeart;
      title = 'Elevated anxiety risk';
      subtitle = 'Your answers look similar to students who screened positive for anxiety. This is a screening result, not a diagnosis.';
    } else if (risk == 'moderate') {
      bg = const Color(0xFFB6814D);
      tint = AppColors.sand;
      asset = AppAssets.stress;
      title = 'Some areas need care';
      subtitle = 'A few areas need attention. Try the tips below and keep checking in.';
    } else {
      bg = const Color(0xFF5E8C79);
      tint = AppColors.mint;
      asset = AppAssets.calmHeart;
      title = 'Low risk';
      subtitle = 'Your answers look similar to students who screened low for anxiety. Keep up the good habits!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: bg.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR RESULT', style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(.75), fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 20, height: 1.25, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.55)),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          width: 92, height: 92,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(26)),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ]),
    );
  }

  Widget _surveyBreakdownCard(Map<String, double> s) {
    final labels = {
      'stress': 'Stress',
      'anxiety': 'Anxiety',
      'sleep': 'Sleep',
      'motivation': 'Motivation',
      'social': 'Social',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Survey Scores', style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          ...s.entries.map((e) {
            final label = labels[e.key] ?? e.key;
            final val = e.value;
            // stress & anxiety: high = bad; sleep/motivation/social: high = good
            final goodHigh = ['sleep', 'motivation', 'social'].contains(e.key);
            final scoreGood = goodHigh ? val >= 3.5 : val <= 2.5;
            final color = scoreGood ? const Color(0xFF739C8A) : (val == 3 ? Colors.orange : Colors.red);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 118, child: Row(children: [
                  _surveyIcon(e.key),
                  const SizedBox(width: 8),
                  Text(label, style: GoogleFonts.poppins(fontSize: 13)),
                ])),
                Expanded(child: LinearProgressIndicator(
                  value: val / 5, minHeight: 10,
                  backgroundColor: Colors.grey[200],
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                )),
                const SizedBox(width: 8),
                Text('${val.round()}/5', style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _surveyIcon(String key) {
    const assets = {
      'stress': AppAssets.stress,
      'anxiety': AppAssets.anxiety,
      'sleep': AppAssets.sleep,
      'social': AppAssets.social,
    };
    final a = assets[key];
    if (a == null) {
      return const Icon(Icons.flag_rounded, size: 22, color: AppColors.primary);
    }
    return Image.asset(a, width: 22, height: 22);
  }

  Widget _escalationCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFCB8C84)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Image.asset(AppAssets.supportHeart, width: 30, height: 30),
          const SizedBox(width: 10),
          Text('Support is available',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold,
              color: const Color(0xFF9B5C59), fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Text('You can contact CUT Counselling Services if you would like to talk to someone. Nothing is sent automatically. It is your choice.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800])),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CounsellingScreen())),
            icon: const Icon(Icons.phone),
            label: const Text('Contact CUT Counselling'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5C59),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    ),
  );

  /// Wellness guidance tailored to the factors that most affected the result.
  Widget _guidanceCard(String risk, List<_Influence> influences) {
    const advice = {
      'stress': 'Break big tasks into small steps and take a 10-minute breathing break (see Pause & reset).',
      'anxiety': 'Try slow breathing: in for 4, out for 6, for a few minutes. Write down what is worrying you in your journal.',
      'sleep': 'Keep a regular bedtime, put your phone away 30 minutes before sleep and avoid caffeine late in the day.',
      'motivation': 'Pick one small task and do just 10 minutes of it. Starting is often the hardest part.',
      'social': 'Message a friend or classmate today, or join a study group or campus activity.',
    };
    final tips = <String>[];
    for (final i in influences.where((i) => i.value > 0).take(3)) {
      final t = advice[i.key];
      if (t != null) tips.add(t);
    }
    if (tips.isEmpty) {
      tips.addAll([
        'Keep up your healthy routines. They are clearly helping.',
        'Continue journaling to notice how you feel over time.',
        'Check in with a friend who may be having a harder week.',
      ]);
    } else if (risk == 'high') {
      tips.add('Talking to someone can really help. CUT Counselling is there whenever you are ready.');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggestions for you', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF739C8A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: GoogleFonts.poppins(fontSize: 13, height: 1.45, color: Colors.grey[800]))),
                ]),
              )),
        ],
      ),
    );
  }
}

class _Influence {
  final String key;
  final double value; // internal only, never displayed
  final double score; // the student's own 1-5 answer
  String strength = 'small';
  _Influence({required this.key, required this.value, required this.score});
}

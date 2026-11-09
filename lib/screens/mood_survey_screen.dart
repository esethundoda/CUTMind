import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import 'ml_result_screen.dart';

class _Question {
  final String key;
  final String title;
  final String prompt;
  final String low;
  final String high;
  final String? image;
  final String? lottie;
  final Color color;
  final Color tint;
  final List<String> captions;

  const _Question({
    required this.key,
    required this.title,
    required this.prompt,
    required this.low,
    required this.high,
    this.image,
    this.lottie,
    required this.color,
    required this.tint,
    required this.captions,
  });
}

class MoodSurveyScreen extends StatefulWidget {
  const MoodSurveyScreen({super.key});

  @override
  State<MoodSurveyScreen> createState() => _MoodSurveyScreenState();
}

class _MoodSurveyScreenState extends State<MoodSurveyScreen> {
  // Keys MUST stay: stress, anxiety, sleep, motivation, social (model order).
  final Map<String, double> _scores = {
    'stress': 3,
    'anxiety': 3,
    'sleep': 3,
    'motivation': 3,
    'social': 3,
  };

  static const _questions = <_Question>[
    _Question(
      key: 'stress',
      title: 'Stress level',
      prompt: 'How stressed have you felt today?',
      low: 'Not stressed',
      high: 'Extremely stressed',
      image: AppAssets.stress,
      color: Color(0xFFC9694F),
      tint: AppColors.sand,
      captions: ['Very calm', 'Fairly calm', 'Somewhat stressed', 'Quite stressed', 'Overwhelmed'],
    ),
    _Question(
      key: 'anxiety',
      title: 'Anxiety',
      prompt: 'How anxious or worried have you felt?',
      low: 'Calm',
      high: 'Very anxious',
      image: AppAssets.anxiety,
      color: Color(0xFF7B6BB0),
      tint: AppColors.lavender,
      captions: ['Very calm', 'Mostly calm', 'A bit anxious', 'Quite anxious', 'Very anxious'],
    ),
    _Question(
      key: 'sleep',
      title: 'Sleep quality',
      prompt: 'How well did you sleep last night?',
      low: 'Very poor',
      high: 'Excellent',
      image: AppAssets.sleep,
      color: Color(0xFF4A6FA5),
      tint: AppColors.sky,
      captions: ['Very poorly', 'Poorly', 'Okay', 'Well', 'Very well'],
    ),
    _Question(
      key: 'motivation',
      title: 'Motivation',
      prompt: 'How motivated do you feel for your studies?',
      low: 'No motivation',
      high: 'Highly motivated',
      lottie: AppAssets.target,
      color: AppColors.primary,
      tint: AppColors.sky,
      captions: ['None at all', 'Low', 'Moderate', 'Good', 'Highly motivated'],
    ),
    _Question(
      key: 'social',
      title: 'Social wellbeing',
      prompt: 'How connected do you feel to people around you?',
      low: 'Very isolated',
      high: 'Very connected',
      image: AppAssets.social,
      color: AppColors.sage,
      tint: AppColors.mint,
      captions: ['Very isolated', 'Disconnected', 'Somewhat connected', 'Connected', 'Very connected'],
    ),
  ];

  /// -1 = intro page, 0..4 = questions.
  int _step = -1;
  bool _submitted = false;
  bool _loading = false;
  int _earned = 0;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final now = DateTime.now();
      final data = {
        ..._scores,
        'timestamp': FieldValue.serverTimestamp(),
        'date':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('surveys')
          .add(data);

      // Award 10 points (once a day) + update streak
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final earned =
          await FirebaseFirestore.instance.runTransaction<int>((tx) async {
        final snap = await tx.get(userRef);
        final map = snap.data() ?? <String, dynamic>{};
        final oldPoints = (map['points'] as num?)?.toInt() ?? 0;
        final streak = (map['streak'] as num?)?.toInt() ?? 0;
        final raw = map['lastCheckIn'];
        final lastCheckIn = raw is Timestamp ? raw.toDate() : null;

        final sameDay = lastCheckIn != null &&
            lastCheckIn.year == now.year &&
            lastCheckIn.month == now.month &&
            lastCheckIn.day == now.day;

        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final consecutive = lastCheckIn != null &&
            lastCheckIn.year == yesterday.year &&
            lastCheckIn.month == yesterday.month &&
            lastCheckIn.day == yesterday.day;

        final gained = sameDay ? 0 : 10;
        tx.set(
          userRef,
          {
            'points': oldPoints + gained,
            'streak': sameDay ? streak : (consecutive ? streak + 1 : 1),
            'lastCheckIn': now,
          },
          SetOptions(merge: true),
        );
        return gained;
      });

      if (!mounted) return;
      setState(() {
        _earned = earned;
        _submitted = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void _restart() => setState(() {
        _submitted = false;
        _step = -1;
        _earned = 0;
        for (final k in _scores.keys) {
          _scores[k] = 3;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Daily check-in'),
        leading: (!_submitted && _step >= 0)
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Start over',
                onPressed: _restart,
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _submitted
            ? _successView()
            : (_step < 0 ? _introView() : _questionView(_step)),
      ),
    );
  }

  // ── Intro ────────────────────────────────────────────────────────────────
  Widget _introView() {
    return SingleChildScrollView(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 260,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Image.asset(AppAssets.onboardCheckin, fit: BoxFit.contain),
          ),
          const SizedBox(height: 26),
          Text('How are you, really?',
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              'Five quick questions about today. There are no right or wrong answers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, height: 1.6, color: AppColors.muted)),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip(Icons.timer_outlined, '2 minutes'),
            const SizedBox(width: 10),
            _chip(Icons.lock_outline_rounded, 'Private'),
          ]),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () => setState(() => _step = 0),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text('Begin',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.ink)),
        ]),
      );

  // ── One question at a time ───────────────────────────────────────────────
  Widget _questionView(int index) {
    final q = _questions[index];
    final value = _scores[q.key]!;
    final isLast = index == _questions.length - 1;

    return Padding(
      key: ValueKey('q$index'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        children: [
          Row(children: [
            Text('Question ${index + 1} of ${_questions.length}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (index + 1) / _questions.length,
              minHeight: 8,
              backgroundColor: AppColors.primary.withOpacity(.12),
              color: q.color,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 190,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: q.tint,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: q.lottie != null
                        ? Lottie.asset(q.lottie!,
                            errorBuilder: (c, e, s) => const SizedBox.shrink())
                        : Image.asset(q.image!, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 22),
                  Text(q.title,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: q.color)),
                  const SizedBox(height: 4),
                  Text(q.prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      final val = (i + 1).toDouble();
                      final selected = value == val;
                      return GestureDetector(
                        onTap: () => setState(() => _scores[q.key] = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: selected ? 58 : 50,
                          height: selected ? 58 : 50,
                          decoration: BoxDecoration(
                            color: selected ? q.color : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected
                                    ? q.color
                                    : q.color.withOpacity(.25),
                                width: 2),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: q.color.withOpacity(.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      selected ? Colors.white : q.color)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(q.low,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.muted)),
                      Text(q.high,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: q.color.withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(q.captions[value.round() - 1],
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: q.color)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (index > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 54,
                  width: 54,
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _step = index - 1),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: AppColors.primary.withOpacity(.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.primary),
                  ),
                ),
              ),
            Expanded(
              child: SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : (isLast
                          ? _submit
                          : () => setState(() => _step = index + 1)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isLast ? 'Finish check-in' : 'Next',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Done ─────────────────────────────────────────────────────────────────
  Widget _successView() {
    return Center(
      key: const ValueKey('done'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              padding: const EdgeInsets.all(26),
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: Image.asset(AppAssets.peace, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            Text('Check-in complete',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Thank you for taking a moment for yourself.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFD9A93E), size: 18),
                const SizedBox(width: 6),
                Text(
                    _earned > 0
                        ? '+$_earned points'
                        : 'Today\u2019s points already collected',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MLResultScreen())),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text('See my wellness report',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _restart,
              child: Text('Do another check-in',
                  style: GoogleFonts.poppins(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

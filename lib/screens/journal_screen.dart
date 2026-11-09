import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../services/journal_analysis_service.dart';
import '../theme/app_theme.dart';
import 'counselling_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _journalCtrl = TextEditingController();
  bool _analyzing = false;
  JournalAnalysis? _sentimentResult;
  String? _error;
  String? _saveNote; // set if the entry could not be saved to Firestore

  @override
  void dispose() {
    _journalCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeAndSave() async {
    final text = _journalCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please write something before saving.');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _analyzing = true;
      _sentimentResult = null;
      _error = null;
      _saveNote = null;
    });

    try {
      // 1. Validate + analyse (AI first, automatic on-device fallback).
      //    Throws InvalidEntryException for gibberish / too-short entries,
      //    so those are never given a risk level, saved, or awarded points.
      final result = await JournalAnalysisService.analyze(text);

      // 2. Save. A save problem must not hide the analysis.
      String? saveNote;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        saveNote = 'You are not signed in, so this entry was not saved.';
      } else {
        try {
          final userRef =
              FirebaseFirestore.instance.collection('users').doc(uid);
          await userRef.collection('journals').add({
            'text': text,
            ...result.toFirestore(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          // set+merge so it also works if the profile doc is new
          await userRef.set(
              {'points': FieldValue.increment(5)}, SetOptions(merge: true));
        } catch (e) {
          saveNote = 'Analysis done, but saving failed: $e';
        }
      }

      if (!mounted) return;
      setState(() {
        _sentimentResult = result;
        _saveNote = saveNote;
      });
      if (saveNote == null) _journalCtrl.clear(); // keep the text if save failed
    } on InvalidEntryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Reflective journal'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showHistory(context),
              icon: const Icon(Icons.history_rounded, size: 19),
              label: Text('History',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            _promptCard(),
            const SizedBox(height: 16),
            _journalInput(),
            const SizedBox(height: 12),
            Row(children: [
              Image.asset(AppAssets.privacy, width: 18, height: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Private to you. Entries are saved to your account only.',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.muted)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _analyzing ? null : _analyzeAndSave,
                icon: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                    _analyzing ? 'Reflecting…' : 'Save & reflect  (+5 pts)',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_error!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, height: 1.45, color: AppColors.clay)),
              ),
            ],
            if (_saveNote != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_saveNote!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, height: 1.45, color: AppColors.clay)),
              ),
            ],
            if (_sentimentResult != null) ...[
              const SizedBox(height: 20),
              _sentimentCard(_sentimentResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _promptCard() {
    final prompts = [
      'How did today make you feel emotionally?',
      'What challenged you the most today?',
      'What are you grateful for today?',
      'Describe a moment that made you anxious recently.',
      'What would help you feel better right now?',
    ];
    final prompt = prompts[DateTime.now().day % prompts.length];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TODAY'S PROMPT",
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sage)),
                const SizedBox(height: 6),
                Text(prompt,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            height: 84,
            child: Lottie.asset(AppAssets.writing,
                errorBuilder: (c, e, s) => const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  Widget _journalInput() => SoftCard(
        padding: EdgeInsets.zero,
        child: TextField(
          controller: _journalCtrl,
          maxLines: 9,
          minLines: 7,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Write freely about how you are feeling…',
            hintStyle:
                GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
            contentPadding: const EdgeInsets.all(18),
            border: InputBorder.none,
          ),
        ),
      );

  Widget _sentimentCard(JournalAnalysis result) {
    final sentiment = result.sentiment;
    final double score = result.score;
    final emotions = result.emotions;
    final tip = result.wellnessTip;
    final risk = result.riskLevel;

    Color sentColor;
    IconData sentIcon;
    if (sentiment == 'positive') {
      sentColor = AppColors.sage;
      sentIcon = Icons.sentiment_satisfied_alt_rounded;
    } else if (sentiment == 'negative') {
      sentColor = const Color(0xFFD58A3E);
      sentIcon = Icons.sentiment_dissatisfied_rounded;
    } else {
      sentColor = AppColors.primary;
      sentIcon = Icons.sentiment_neutral_rounded;
    }

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sentColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(sentIcon, color: sentColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How your entry reads',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                      '${sentiment[0].toUpperCase()}${sentiment.substring(1)} tone in this entry',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 9,
              backgroundColor: const Color(0xFFEDF0EE),
              color: sentColor,
            ),
          ),
          if (emotions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emotions
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sentColor.withOpacity(.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(e,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: sentColor)),
                      ))
                  .toList(),
            ),
          ],
          if (tip.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 17)),
                  Expanded(
                    child: Text(tip,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ],
          if (risk == 'high') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blush,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Image.asset(AppAssets.supportHeart, width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'This sounds heavy. Talking to someone can really help.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, height: 1.45, color: AppColors.ink)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CounsellingScreen())),
                  child: Text('Get support',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.clay)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _JournalHistoryScreen(uid: uid)));
  }
}

// ─── Journal History ──────────────────────────────────────────────────────────
class _JournalHistoryScreen extends StatelessWidget {
  final String uid;
  const _JournalHistoryScreen({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Journal history')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('journals')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 130,
                      child: Lottie.asset(AppAssets.book,
                          errorBuilder: (c, e, s) => const Icon(
                              Icons.menu_book_rounded,
                              size: 70,
                              color: AppColors.sage)),
                    ),
                    const SizedBox(height: 12),
                    Text('No entries yet',
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Your saved journal entries will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            );
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final raw = d['timestamp'];
              final ts = raw is Timestamp ? raw.toDate() : null;
              final sent = (d['sentiment'] ?? 'neutral').toString();
              final Color c = sent == 'positive'
                  ? AppColors.sage
                  : sent == 'negative'
                      ? const Color(0xFFD58A3E)
                      : AppColors.primary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ts != null
                                    ? '${ts.day}/${ts.month}/${ts.year} · ${sent.toUpperCase()}'
                                    : sent.toUpperCase(),
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    letterSpacing: .6,
                                    fontWeight: FontWeight.w700,
                                    color: c)),
                            const SizedBox(height: 4),
                            Text((d['text'] ?? '').toString(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

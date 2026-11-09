import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class CounsellingScreen extends StatelessWidget {
  const CounsellingScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F4),
      appBar: AppBar(title: const Text('Find support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          children: [
            // Warm welcome
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.blush,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("You're not alone",
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Text(
                          'Talking to someone is a strong first step. Free, confidential help is available to you.',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.55,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(AppAssets.counsellor,
                      fit: BoxFit.contain),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Emergency banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8E5553),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emergency, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text('Are you in crisis?', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('If you are in immediate danger, call emergency services.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _launch('tel:10111'),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text('Call 10111 (SAPS Emergency)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // CUT counselling
            _contactCard(
              icon: Icons.school,
              color: const Color(0xFF2C5282),
              title: 'CUT Student Counselling',
              desc: 'Free, confidential counselling for all registered CUT students. '
                    'Sessions by appointment. Monday–Friday 08:00–16:30.',
              actions: [
                _actionBtn('Call: 051 507 3017', Icons.phone, () => _launch('tel:0515073017'), const Color(0xFF2C5282)),
                _actionBtn('Email Counselling', Icons.email, () => _launch('mailto:counselling@cut.ac.za'), const Color(0xFF739C8A)),
                _actionBtn('CUT Website', Icons.language, () => _launch('https://www.cut.ac.za'), Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 14),

            // SADAG
            _contactCard(
              icon: Icons.support_agent,
              color: Colors.orange.shade700,
              title: 'SADAG – SA Depression & Anxiety Group',
              desc: '24-hour helpline for depression, anxiety, stress, and suicidal crisis. '
                    'Free, confidential, available 24/7.',
              actions: [
                _actionBtn('Call: 0800 456 789 (24/7)', Icons.phone, () => _launch('tel:0800456789'), Colors.orange.shade700),
                _actionBtn('SMS Helpline: 31393', Icons.sms, () => _launch('sms:31393'), Colors.deepOrange),
              ],
            ),
            const SizedBox(height: 14),

            // Lifeline
            _contactCard(
              icon: Icons.favorite,
              color: Colors.pink.shade600,
              title: 'Lifeline South Africa',
              desc: 'Crisis counselling, suicide prevention, and trauma support. '
                    'Available 24 hours.',
              actions: [
                _actionBtn('Call: 0861 322 322', Icons.phone, () => _launch('tel:0861322322'), Colors.pink.shade600),
              ],
            ),
            const SizedBox(height: 14),

            // Self-care tips
            _selfCareCard(),
          ],
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          const SizedBox(height: 10),
          Text(desc, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _selfCareCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF739C8A).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('While You Wait for Support', style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2E7D32))),
        const SizedBox(height: 10),
        ...[
          '🧘 Try 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s.',
          '🚶 Step outside for a short walk in fresh air.',
          '📱 Reach out to a friend or family member you trust.',
          '📓 Write down how you are feeling in your CUTMind journal.',
          '🎵 Listen to calming music or nature sounds.',
        ].map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800])),
        )),
      ],
    ),
  );
}

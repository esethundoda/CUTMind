import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import 'mood_survey_screen.dart';
import 'journal_screen.dart';
import 'ml_result_screen.dart';
import 'gamification_screen.dart';
import 'counselling_screen.dart';
import 'pause_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _Dashboard(onTab: _goTo),
      const MoodSurveyScreen(),
      const JournalScreen(),
      const GamificationScreen(),
    ];
  }

  void _goTo(int i) => setState(() => _currentIndex = i);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.canvas,
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withOpacity(.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            height: 70,
            selectedIndex: _currentIndex,
            onDestinationSelected: _goTo,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            indicatorColor: AppColors.sky,
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.muted,
                )),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: 'Check-in'),
              NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note_rounded),
                  label: 'Journal'),
              NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'Progress'),
            ],
          ),
        ),
      );
}

class _Dashboard extends StatelessWidget {
  final ValueChanged<int> onTab;
  const _Dashboard({required this.onTab});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null
              ? null
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
          builder: (context, snap) {
            final profile = snap.data?.data() ?? <String, dynamic>{};
            final rawName = (profile['name'] ?? 'Student').toString().trim();
            final firstName =
                rawName.isEmpty ? 'Student' : rawName.split(RegExp(r'\s+')).first;
            final points = (profile['points'] as num?)?.toInt() ?? 0;
            final streak = (profile['streak'] as num?)?.toInt() ?? 0;
            final level = levelFromPoints(points);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                _header(context, firstName),
                const SizedBox(height: 20),
                _HeroCard(onTap: () => onTab(1)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFE08A4B),
                          value: '$streak',
                          label: 'Day streak')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatTile(
                          icon: Icons.star_rounded,
                          color: const Color(0xFFD9A93E),
                          value: '$points',
                          label: 'Points')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatTile(
                          icon: Icons.emoji_events_rounded,
                          color: AppColors.sage,
                          value: '${level['level']}',
                          label: '${level['name']}')),
                ]),
                const SizedBox(height: 26),
                const SectionTitle('Your wellbeing toolkit'),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: [
                    _ToolCard(
                      visual: Image.asset(AppAssets.calmHeart),
                      tint: AppColors.sky,
                      title: 'Wellness insights',
                      subtitle: 'See what your check-ins say',
                      onTap: () => _open(context, const MLResultScreen()),
                    ),
                    _ToolCard(
                      visual: Lottie.asset(AppAssets.writing,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.edit_note_rounded)),
                      tint: AppColors.mint,
                      title: 'Private journal',
                      subtitle: 'Let your thoughts out',
                      onTap: () => onTab(2),
                    ),
                    _ToolCard(
                      visual: Lottie.asset(AppAssets.yoga,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.spa_rounded)),
                      tint: AppColors.lavender,
                      title: 'Pause & reset',
                      subtitle: 'A guided breathing minute',
                      onTap: () => _open(context, const PauseScreen()),
                    ),
                    _ToolCard(
                      visual: Image.asset(AppAssets.counsellor),
                      tint: AppColors.blush,
                      title: 'Find support',
                      subtitle: 'People who can help',
                      onTap: () => _open(context, const CounsellingScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SleepTip(),
                const SizedBox(height: 14),
                _SupportBanner(
                    onTap: () => _open(context, const CounsellingScreen())),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String firstName) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.muted)),
              Text('Hi, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 27,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            if (v == 'signout') FirebaseAuth.instance.signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'signout',
              child: Row(children: [
                const Icon(Icons.logout_rounded,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Text('Sign out', style: GoogleFonts.poppins(fontSize: 13)),
              ]),
            ),
          ],
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              firstName.isEmpty ? 'S' : firstName[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF315D83), Color(0xFF477B85)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315D83).withOpacity(.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('2 MINUTES',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                Text('How are you, really?',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('A quick check-in helps you notice what you need today.',
                    style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.85),
                        fontSize: 12,
                        height: 1.5)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF7F5EE),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Start check-in',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 17),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 104,
            height: 132,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF6E8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Image.asset(AppAssets.onboardCheckin, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      radius: 20,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final Widget visual;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolCard({
    required this.visual,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: double.infinity,
            height: 74,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: visual,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 10, height: 1.4, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        IllustrationBadge(
          asset: AppAssets.sleep,
          size: 58,
          background: Colors.white,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wind down tonight',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text('Try 20 screen-free minutes before bed. Better sleep makes everything feel lighter.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, height: 1.5, color: AppColors.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SupportBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      color: AppColors.blush,
      radius: 24,
      child: Row(children: [
        IllustrationBadge(
          asset: AppAssets.supportHeart,
          size: 58,
          background: Colors.white,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You don\u2019t have to do it alone',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              Text('Campus counselling and 24/7 helplines',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.clay),
      ]),
    );
  }
}

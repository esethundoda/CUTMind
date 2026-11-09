import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

/// Level information for a points total. Shared with the home dashboard.
Map<String, dynamic> levelFromPoints(int pts) {
  final levels = [
    {'level': 1, 'name': 'Beginner', 'emoji': '🌱', 'min': 0, 'max': 50, 'nextName': 'Explorer'},
    {'level': 2, 'name': 'Explorer', 'emoji': '🌿', 'min': 50, 'max': 150, 'nextName': 'Achiever'},
    {'level': 3, 'name': 'Achiever', 'emoji': '🌟', 'min': 150, 'max': 300, 'nextName': 'Warrior'},
    {'level': 4, 'name': 'Warrior', 'emoji': '💪', 'min': 300, 'max': 500, 'nextName': 'Champion'},
    {'level': 5, 'name': 'Champion', 'emoji': '🏆', 'min': 500, 'max': 1000, 'nextName': 'Legend'},
    {'level': 6, 'name': 'Legend', 'emoji': '👑', 'min': 1000, 'max': 99999, 'nextName': 'Legend'},
  ];
  final l = levels.lastWhere((e) => pts >= (e['min'] as int),
      orElse: () => levels.first);
  final gap = (l['max'] as int) - (l['min'] as int);
  final progress =
      gap == 0 ? 1.0 : ((pts - (l['min'] as int)) / gap).clamp(0.0, 1.0);
  return {...l, 'minPoints': l['min'], 'gap': gap, 'progress': progress};
}

class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('My progress')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
        builder: (context, snap) {
          if (uid.isNotEmpty && !snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data?.data() ?? <String, dynamic>{};
          final points = (d['points'] as num?)?.toInt() ?? 0;
          final streak = (d['streak'] as num?)?.toInt() ?? 0;
          final name = (d['name'] ?? 'Student').toString();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _profileCard(name, points, streak),
              const SizedBox(height: 22),
              const SectionTitle('Your milestones'),
              const SizedBox(height: 12),
              _milestones(points),
              const SizedBox(height: 22),
              const SectionTitle('Mood trend'),
              const SizedBox(height: 12),
              _moodTrendChart(uid),
              const SizedBox(height: 22),
              _howToEarnCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(String name, int points, int streak) {
    final level = levelFromPoints(points);
    final minPoints = level['minPoints'] as int;
    final gap = level['gap'] as int;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF315D83), Color(0xFF477B85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF315D83).withOpacity(.18),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(level['emoji'] as String,
                  style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  Text('Level ${level['level']} · ${level['name']}',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(.8), fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            _statPill('$points', 'Points', Icons.star_rounded),
            const SizedBox(width: 10),
            _statPill('$streak', 'Day streak', Icons.local_fire_department_rounded),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${level['name']} → ${level['nextName']}',
                style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(.8), fontSize: 11)),
            Text('${points - minPoints}/$gap XP',
                style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(.8), fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: level['progress'] as double,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(.2),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFFFFE2A8), size: 24),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      height: 1.1)),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(.75), fontSize: 10)),
            ]),
          ]),
        ),
      );

  Widget _milestones(int points) {
    final milestones = [
      {'pts': 10, 'label': 'First check-in', 'icon': '🎉'},
      {'pts': 50, 'label': 'Finding your rhythm', 'icon': '🔥'},
      {'pts': 100, 'label': 'Journal habit', 'icon': '📖'},
      {'pts': 200, 'label': 'Wellness warrior', 'icon': '💪'},
      {'pts': 500, 'label': 'Mental health champion', 'icon': '🏆'},
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: milestones.map((m) {
          final unlocked = points >= (m['pts'] as int);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked ? AppColors.sand : const Color(0xFFF0F2F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(unlocked ? (m['icon'] as String) : '🔒',
                    style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['label'] as String,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: unlocked
                                ? AppColors.ink
                                : AppColors.muted)),
                    Text('${m['pts']} points',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              if (unlocked)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.sage, size: 22),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _moodTrendChart(String uid) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stress over your last 7 check-ins',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text('Lower is calmer.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 16),
          if (uid.isEmpty)
            _emptyTrend()
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('surveys')
                  .orderBy('timestamp', descending: true)
                  .limit(7)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyTrend();
                }
                final docs = snap.data!.docs.reversed.toList();
                final spots = docs.asMap().entries.map((e) {
                  final stress = (e.value.data()['stress'] as num?)?.toDouble() ?? 3;
                  return FlSpot(e.key.toDouble(), stress);
                }).toList();

                return SizedBox(
                  height: 160,
                  child: LineChart(LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFE9EEEA), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 1,
                          getTitlesWidget: (v, meta) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, meta) => Text(
                            '${v.round() + 1}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 1,
                    maxY: 5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                  )),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _emptyTrend() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Image.asset(AppAssets.stress, width: 46, height: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Complete a few check-ins to see your trend here.',
                style: GoogleFonts.poppins(
                    color: AppColors.muted, fontSize: 12, height: 1.5)),
          ),
        ]),
      );

  Widget _howToEarnCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.lavender,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Lottie.asset(AppAssets.target,
                    errorBuilder: (c, e, s) => const SizedBox.shrink()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('How to earn points',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink)),
              ),
            ]),
            const SizedBox(height: 8),
            ...[
              ['Daily mood check-in', '+10'],
              ['Journal entry with analysis', '+5'],
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item[0],
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.ink)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(item[1],
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
}

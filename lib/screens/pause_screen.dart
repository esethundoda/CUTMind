import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

/// Guided breathing: in for 4 counts, out for 6, five rounds.
class PauseScreen extends StatefulWidget {
  const PauseScreen({super.key});

  @override
  State<PauseScreen> createState() => _PauseScreenState();
}

class _PauseScreenState extends State<PauseScreen>
    with SingleTickerProviderStateMixin {
  static const _totalRounds = 5;
  static const _inhaleShare = 0.4; // 4s of a 10s cycle

  late final AnimationController _ctrl;
  bool _running = false;
  bool _finished = false;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !_running) return;
        if (_round + 1 >= _totalRounds) {
          setState(() {
            _running = false;
            _finished = true;
            _round = _totalRounds;
          });
        } else {
          setState(() => _round++);
          _ctrl.forward(from: 0);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _finished = false;
      _round = 0;
    });
    _ctrl.forward(from: 0);
  }

  void _stop() {
    _ctrl.stop();
    _ctrl.value = 0;
    setState(() {
      _running = false;
      _round = 0;
    });
  }

  // 0 → 1 while breathing in, 1 → 0 while breathing out.
  double _size(double t) {
    final raw = t < _inhaleShare
        ? t / _inhaleShare
        : 1 - (t - _inhaleShare) / (1 - _inhaleShare);
    return Curves.easeInOut.transform(raw.clamp(0.0, 1.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Pause & reset')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _running || _finished ? _breathingStage() : _intro(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _running ? _stop : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _running ? AppColors.muted : AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _running
                        ? 'Stop'
                        : (_finished ? 'Go again' : 'Begin breathing'),
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 240,
          child: Lottie.asset(AppAssets.yoga,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.spa_rounded, size: 90, color: AppColors.sage)),
        ),
        const SizedBox(height: 8),
        Text('A small pause',
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'Relax your shoulders. Breathe in for four counts and out for six. '
          'We will guide you through five slow rounds.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 13, height: 1.65, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _breathingStage() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final s = _finished ? 0.0 : _size(t);
        final inhaling = t < _inhaleShare;
        final circle = 150 + 90 * s;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: circle + 26,
                      height: circle + 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage.withOpacity(.14),
                      ),
                    ),
                    Container(
                      width: circle,
                      height: circle,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF477B85), Color(0xFF315D83)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _finished
                            ? 'Well done'
                            : (inhaling ? 'Breathe in' : 'Breathe out'),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _finished
                  ? 'Notice how your body feels now.'
                  : 'Round ${_round + 1} of $_totalRounds',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalRounds, (i) {
                final done = _finished || i < _round;
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.sage
                        : AppColors.sage.withOpacity(.25),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

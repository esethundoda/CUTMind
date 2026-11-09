import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      asset: AppAssets.onboardCheckin,
      tint: AppColors.sand,
      title: 'Check in with yourself',
      body:
          'A two-minute daily check-in helps you notice stress, anxiety, sleep, motivation and connection.',
    ),
    _OnboardPage(
      asset: AppAssets.onboardInsight,
      tint: AppColors.sky,
      title: 'Understand your patterns',
      body:
          'Your answers are turned into gentle, easy-to-read insights, so you can see what is helping and what is not.',
    ),
    _OnboardPage(
      asset: AppAssets.onboardSupport,
      tint: AppColors.mint,
      title: 'Support is always close',
      body:
          'Find CUT counselling and 24-hour helplines in one tap. You never have to work through things alone.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      widget.onFinished();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: last ? 0 : 1,
                  child: TextButton(
                    onPressed: last ? null : widget.onFinished,
                    child: Text('Skip',
                        style: GoogleFonts.poppins(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _pages[i].build(context),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(last ? 'Get started' : 'Continue',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String asset;
  final Color tint;
  final String title;
  final String body;

  const _OnboardPage({
    required this.asset,
    required this.tint,
    required this.title,
    required this.body,
  });

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 34),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, height: 1.65, color: AppColors.muted)),
        ],
      ),
    );
  }
}

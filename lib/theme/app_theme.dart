import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central colour palette so every screen feels like one product.
class AppColors {
  static const ink = Color(0xFF243342);
  static const muted = Color(0xFF718096);
  static const primary = Color(0xFF2C5282);
  static const sage = Color(0xFF739C8A);
  static const canvas = Color(0xFFF6F7F4);
  static const clay = Color(0xFF9B5C59);

  // Soft tints used behind illustrations
  static const sky = Color(0xFFE4EEF7);
  static const mint = Color(0xFFE3F0E9);
  static const sand = Color(0xFFF8EFDC);
  static const blush = Color(0xFFF8E5E1);
  static const lavender = Color(0xFFEBE7F6);
}

/// Every illustration / animation that ships with the app.
class AppAssets {
  static const _i = 'assets/images/';
  static const _a = 'assets/animations/';

  // Illustrations
  static const stress = '${_i}stress.png';
  static const anxiety = '${_i}anxiety.png';
  static const sleep = '${_i}sleep.png';
  static const social = '${_i}social.png';
  static const calmHeart = '${_i}calm_heart.png';
  static const supportHeart = '${_i}support_heart.png';
  static const privacy = '${_i}privacy.png';
  static const onboardCheckin = '${_i}onboard_checkin.png';
  static const onboardInsight = '${_i}onboard_insight.png';
  static const onboardSupport = '${_i}onboard_support.png';
  static const counsellor = '${_i}counsellor.png';
  static const peace = '${_i}peace.png';

  // Lottie animations
  static const yoga = '${_a}yoga.json';
  static const writing = '${_a}writing.json';
  static const target = '${_a}target.json';
  static const book = '${_a}book.json';
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.sage,
    surface: AppColors.canvas,
  );
  final text = GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme)
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// White rounded card with a soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// An illustration sitting on a soft tinted rounded square.
class IllustrationBadge extends StatelessWidget {
  final String asset;
  final double size;
  final Color background;
  final double padding;

  const IllustrationBadge({
    super.key,
    required this.asset,
    this.size = 56,
    this.background = AppColors.sky,
    this.padding = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

/// Small section heading used across screens.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        if (trailing != null)
          Text(trailing!,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }
}

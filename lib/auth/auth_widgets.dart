import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Rounded illustrated header shared by sign-in and sign-up.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double height;
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.height = 210,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.sky, AppColors.mint],
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(AppAssets.onboardSupport,
                    fit: BoxFit.contain),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.psychology_alt,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('CUTMind',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 13, height: 1.5, color: AppColors.muted)),
      ],
    );
  }
}

InputDecoration authInputDecoration(String hint, IconData icon,
    {Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
    border: border(const Color(0xFFE2E8F0)),
    enabledBorder: border(const Color(0xFFE2E8F0)),
    focusedBorder: border(AppColors.primary, 1.6),
  );
}

class AuthError extends StatelessWidget {
  final String message;
  const AuthError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.clay, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: GoogleFonts.poppins(
                  fontSize: 12, height: 1.45, color: AppColors.clay)),
        ),
      ]),
    );
  }
}

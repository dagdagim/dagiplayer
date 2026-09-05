import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Bespoke, human-designed brand logo mark for DagiPlayer.
/// Combines an editorial geometric 'D' silhouette with an integrated
/// warm-orange playback triangle and subtle studio audio bars.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 32.0,
    this.showText = true,
    this.textStyle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = color ?? AppColors.primary;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Custom Brand Logo Mark
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(50),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDeep,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: size * 0.62,
                  ),
                );
              },
            ),
          ),
        ),

        if (showText) ...[
          SizedBox(width: size * 0.32),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Dagi',
                  style: textStyle ??
                      AppTypography.displaySmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: size * 0.65,
                      ),
                ),
                TextSpan(
                  text: 'Player',
                  style: textStyle ??
                      AppTypography.displaySmall.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.3,
                        fontSize: size * 0.65,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

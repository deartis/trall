import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Exibe um SnackBar altamente customizado e estilizado com base no design system.
void showStyledSnackBar({
  required BuildContext context,
  required String message,
  IconData? icon,
  Color? iconColor,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.bgPanel,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError
              ? AppColors.dangerBorderStrong
              : AppColors.blueBorder,
          width: 1.5,
        ),
      ),
      content: Row(
        children: [
          Icon(
            icon ?? (isError ? Icons.error_outline_rounded : Icons.info_outline_rounded),
            color: iconColor ?? (isError ? AppColors.danger : AppColors.blueMid),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

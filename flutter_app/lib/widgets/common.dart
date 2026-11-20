import 'package:flutter/material.dart';
import '../config.dart';

/// Shared UI: big buttons, status chips, info/error boxes.
/// Design: dark green + gold, big tap targets for low-end phones.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppConfig.darkGreen,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: 22, color: Colors.white)
            : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  const StatusChip({super.key, required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: ok ? AppConfig.success : AppConfig.danger),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: ok ? AppConfig.success : AppConfig.danger)),
    );
  }
}

class InfoBox extends StatelessWidget {
  final String text;
  final bool isError;
  final bool isSuccess;
  const InfoBox(this.text,
      {super.key, this.isError = false, this.isSuccess = false});

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? const Color(0xFFFFEBEE)
        : isSuccess
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFE3F2FD);
    final fg = isError
        ? AppConfig.danger
        : isSuccess
            ? AppConfig.success
            : const Color(0xFF0D47A1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: TextStyle(fontSize: 14, color: fg, height: 1.45)),
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? bottomNav;
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.bottomNav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F4),
      appBar: AppBar(
        backgroundColor: AppConfig.darkGreen,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

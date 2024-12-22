import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewDialog {
  static Future<void> showReviewDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('last_review_shown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 24時間以内に表示済みの場合は表示しない
    if (now - lastShown < const Duration(hours: 24).inMilliseconds) {
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReviewDialogContent(
        onClose: () async {
          await prefs.setInt('last_review_shown', now);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

class _ReviewDialogContent extends StatelessWidget {
  final VoidCallback onClose;

  const _ReviewDialogContent({
    Key? key,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/app_icon.png',
                width: 60,
                height: 60,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '"Seichi" はいかがですか?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '星をタップして App Store で評価してください。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: const Icon(Icons.star_border),
                  color: Colors.blue,
                  iconSize: 36,
                  onPressed: () {
                    // TODO: ここでApp Storeのレビューページを開く
                    onClose();
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClose,
              child: const Text(
                '今はしない',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

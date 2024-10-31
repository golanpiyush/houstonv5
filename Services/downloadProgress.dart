import 'package:flutter/material.dart';

class DownloadProgressBar extends StatelessWidget {
  final double progress;
  final bool isDownloading;

  const DownloadProgressBar({
    super.key,
    required this.progress,
    required this.isDownloading,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDownloading) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.red[200], // Light red background
          valueColor: const AlwaysStoppedAnimation<Color>(
            Colors.red, // Red color for the progress bar
          ),
          minHeight: 24,
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.red), // Red text color
        ),
      ],
    );
  }
}

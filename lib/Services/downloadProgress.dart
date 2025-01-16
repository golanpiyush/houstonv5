import 'package:flutter/material.dart';
import 'dart:async';

class DownloadProgressWidget extends StatefulWidget {
  final Stream<double> progressStream;
  final bool isDownloading;

  const DownloadProgressWidget({
    super.key,
    required this.progressStream,
    required this.isDownloading,
  });

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double _progress = 0.0;
  StreamSubscription<double>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _setupProgressListener();
    _handleVisibility(); // Handle initial visibility state
  }

  @override
  void didUpdateWidget(covariant DownloadProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressStream != widget.progressStream) {
      _setupProgressListener();
    }

    if (oldWidget.isDownloading != widget.isDownloading) {
      _handleVisibility();
    }
  }

  void _setupProgressListener() {
    _progressSubscription?.cancel();
    _progressSubscription = widget.progressStream.listen(
      (progress) {
        setState(() {
          _progress = progress;
          debugPrint('Progress updated: $_progress');
        });
      },
      onError: (error) {
        debugPrint('Progress stream error: $error');
      },
    );
  }

  void _handleVisibility() {
    if (widget.isDownloading) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 32.0,
      left: 16.0,
      right: 16.0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 8.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[300],
          ),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}

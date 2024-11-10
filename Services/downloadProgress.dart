import 'package:flutter/material.dart';
import 'dart:async';

class DownloadProgressWidget extends StatefulWidget {
  final Stream<double> progressStream;

  const DownloadProgressWidget({super.key, required this.progressStream});

  @override
  _DownloadProgressWidgetState createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _visible = false;
  double _progress = 0.0;
  late StreamSubscription<double> _progressSubscription;

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

    _progressSubscription = widget.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });

        if (progress > 0.0) {
          if (!_visible) {
            _visible = true; // Show if progress starts
            _animationController.forward();
          }
        } else if (progress >= 1.0) {
          _animationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _visible = false; // Hide when complete
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Visibility(
        visible: _visible,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color.fromARGB(83, 93, 14, 241),
            ),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(226, 45, 7, 212)),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

class CountDown extends StatefulWidget {
  final int seconds;
  final VoidCallback? onFinished;
  final TextStyle? textStyle;

  const CountDown({
    Key? key,
    required this.seconds,
    this.onFinished,
    this.textStyle,
  }) : super(key: key);

  @override
  State<CountDown> createState() => _CountDownState();
}

class _CountDownState extends State<CountDown> {
  late int _remaining;
  Timer? _timer;
  bool _showGo = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining > 1) {
        setState(() {
          _remaining--;
        });
      } else if (_remaining == 1) {
        setState(() {
          _remaining = 0;
          _showGo = true;
        });
        timer.cancel();
        // Show "Go" for 1 second, then call onFinished
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _showGo = false;
            });
            if (widget.onFinished != null) {
              widget.onFinished!();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.7),
          ),
        ),
        Center(
          child: Text(
            _showGo ? 'Go' : (_remaining > 0 ? '$_remaining' : ''),
            style: widget.textStyle ?? Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class WaveformIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const WaveformIndicator({
    super.key,
    required this.isPlaying,
    this.color = AppColors.primary,
    this.size = 14.0,
  });

  @override
  State<WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant WaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = widget.isPlaying ? _controller.value : 0.2;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar((0.4 + (val * 0.6)).clamp(0.2, 1.0)),
              _buildBar((0.8 - (val * 0.5)).clamp(0.2, 1.0)),
              _buildBar((0.3 + (val * 0.7)).clamp(0.2, 1.0)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double heightFactor) {
    return Container(
      width: 2.5,
      height: widget.size * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

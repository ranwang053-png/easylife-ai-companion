import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import 'companion_pet.dart';

class CompanionAvatar extends StatefulWidget {
  const CompanionAvatar({
    super.key,
    this.profile,
    this.imageUrl,
    this.size = 116,
    this.breathing = true,
    this.imageKey,
  });

  final PetProfile? profile;
  final String? imageUrl;
  final double size;
  final bool breathing;
  final Key? imageKey;

  @override
  State<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  String? _imageSource;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _syncImageProvider();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _scale = Tween<double>(begin: .99, end: 1.012).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.breathing && !_isWidgetTestEnvironment) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncImageProvider();
    if (widget.breathing && !_isWidgetTestEnvironment) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncImageProvider() {
    final source = widget.imageUrl ?? widget.profile?.generatedAvatarUrl;
    if (source == _imageSource) return;
    _imageSource = source;
    if (source != null && source.startsWith('data:image/')) {
      _imageProvider = MemoryImage(base64Decode(source.split(',').last));
    } else if (source != null && source.startsWith('https://')) {
      _imageProvider = NetworkImage(source);
    } else {
      _imageProvider = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _AvatarImage(
      imageProvider: _imageProvider,
      size: widget.size,
      imageKey: widget.imageKey,
    );

    if (!widget.breathing || _isWidgetTestEnvironment) return child;
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final sway = math.sin(phase) * widget.size * .012;
        final lift = math.sin(phase + math.pi / 3) * widget.size * .01;
        final tilt = math.sin(phase - math.pi / 5) * .018;
        return Transform.translate(
          offset: Offset(sway, lift),
          child: Transform.rotate(
            angle: tilt,
            child: ScaleTransition(
              scale: _scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({
    required this.imageProvider,
    required this.size,
    required this.imageKey,
  });

  final ImageProvider? imageProvider;
  final double size;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final image = imageProvider;
    if (image != null) {
      return SizedBox.square(
        dimension: size,
        child: Image(
          image: image,
          key: imageKey,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }
    return CompanionPet(size: size);
  }
}

bool get _isWidgetTestEnvironment {
  var isTest = false;
  assert(() {
    isTest = WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
    return true;
  }());
  return isTest;
}

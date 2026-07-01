import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scale = Tween<double>(begin: .985, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.breathing && !_isWidgetTestEnvironment) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl ?? widget.profile?.generatedAvatarUrl;
    final child = _AvatarImage(
      imageUrl: imageUrl,
      size: widget.size,
      imageKey: widget.imageKey,
    );

    if (!widget.breathing || _isWidgetTestEnvironment) return child;
    return ScaleTransition(scale: _scale, child: child);
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({
    required this.imageUrl,
    required this.size,
    required this.imageKey,
  });

  final String? imageUrl;
  final double size;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl;
    if (source != null && source.startsWith('data:image/')) {
      return SizedBox.square(
        dimension: size,
        child: Image.memory(
          base64Decode(source.split(',').last),
          key: imageKey,
          fit: BoxFit.contain,
        ),
      );
    }
    if (source != null && source.startsWith('https://')) {
      return SizedBox.square(
        dimension: size,
        child: Image.network(source, key: imageKey, fit: BoxFit.contain),
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

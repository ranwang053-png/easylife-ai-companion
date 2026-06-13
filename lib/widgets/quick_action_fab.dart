import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import '../theme/app_colors.dart';

class QuickActionFab extends StatelessWidget {
  const QuickActionFab({
    required this.isOpen,
    required this.actions,
    required this.onToggle,
    required this.onAction,
    super.key,
  });

  final bool isOpen;
  final List<QuickAction> actions;
  final VoidCallback onToggle;
  final ValueChanged<QuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: isOpen ? 190 : 64,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (isOpen)
            Positioned.fill(
              bottom: 28,
              child: _ActionArc(actions: actions, onAction: onAction),
            ),
          Positioned(
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'dashboard_add',
              onPressed: onToggle,
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: const CircleBorder(),
              child: AnimatedRotation(
                turns: isOpen ? .125 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionArc extends StatelessWidget {
  const _ActionArc({required this.actions, required this.onAction});

  final List<QuickAction> actions;
  final ValueChanged<QuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    final positions = <Alignment>[
      const Alignment(-.72, .45),
      const Alignment(0, -.8),
      const Alignment(.72, .45),
    ];

    return Stack(
      children: [
        for (var index = 0; index < actions.length; index++)
          Align(
            alignment: positions[index],
            child: _ActionBubble(
              action: actions[index],
              onTap: () => onAction(actions[index]),
            ),
          ),
      ],
    );
  }
}

class _ActionBubble extends StatelessWidget {
  const _ActionBubble({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: action.color,
          elevation: 4,
          shadowColor: Colors.black12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(action.icon, color: AppColors.ink, size: 23),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          action.label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.ink, fontSize: 10),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    required this.child,
    super.key,
    this.maxWidth = 1120,
    this.mobilePadding = const EdgeInsets.symmetric(horizontal: 20),
    this.desktopPadding = const EdgeInsets.symmetric(horizontal: 32),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry desktopPadding;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static bool isMedium(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 680;

  @override
  Widget build(BuildContext context) {
    final wide = isMedium(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: wide ? desktopPadding : mobilePadding,
          child: child,
        ),
      ),
    );
  }
}

class ResponsivePageList extends StatelessWidget {
  const ResponsivePageList({
    required this.children,
    super.key,
    this.maxWidth = 860,
    this.top = 12,
    this.bottom = 132,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final horizontal = ResponsivePage.isMedium(context) ? 32.0 : 20.0;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

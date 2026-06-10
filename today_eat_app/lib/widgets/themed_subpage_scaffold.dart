import 'package:flutter/material.dart';

import 'themed_page_background.dart';

class ThemedSubpageScaffold extends StatelessWidget {
  const ThemedSubpageScaffold({
    super.key,
    this.appBar,
    required this.child,
    this.topSpacing = 0,
    this.includeBottomSafeArea = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final double topSpacing;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final topInset =
        mediaPadding.top + (appBar?.preferredSize.height ?? 0) + topSpacing;
    final bottomInset = includeBottomSafeArea ? mediaPadding.bottom : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: ThemedPageBackground(
        child: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          child: child,
        ),
      ),
    );
  }
}

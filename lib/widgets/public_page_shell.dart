import 'package:flutter/material.dart';

import 'public_top_menu.dart';

abstract final class PublicPageTheme {
  static const background = Color(0xFFF7F9FC);
  static const text = Color(0xFF111111);
  static const bodyText = Color(0xFF4B5563);
  static const mobileBreakpoint = 700;
  static const contentMaxWidth = 1100.0;
}

class PublicPageShell extends StatelessWidget {
  final PublicPage current;
  final String? pageTitle;
  final Widget child;
  final bool scrollable;
  final bool includeBottomSafeArea;

  const PublicPageShell({
    super.key,
    required this.current,
    this.pageTitle,
    required this.child,
    this.scrollable = true,
    this.includeBottomSafeArea = false,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < PublicPageTheme.mobileBreakpoint;

  static TextStyle pageTitleStyle() => const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: PublicPageTheme.text,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle bodyStyle() => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: PublicPageTheme.bodyText,
        height: 1.5,
      );

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final paddingH = 24.0;
    final paddingV = mobile ? 24.0 : 40.0;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PublicPageTheme.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(paddingH, paddingV, paddingH, paddingV),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageTitle != null) ...[
                  Text(
                    pageTitle!,
                    style: pageTitleStyle(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                DefaultTextStyle(
                  style: bodyStyle(),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final fullHeightBody = !scrollable && pageTitle == null;
    final Widget pageBody;
    if (fullHeightBody) {
      pageBody = child;
    } else {
      pageBody = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: PublicPageTheme.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: includeBottomSafeArea,
        child: Column(
          children: [
            PublicTopBar(current: current),
            Expanded(child: pageBody),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/dimensions.dart';

abstract final class PageShellTheme {
  static const Color appBarBackground = Color(0xFFECEFF1);
  static const Color scaffoldBackground = Colors.white;
  static const Color drawerBackground = Color(0xFFECEFF1);
  static const double sidebarWidth = 260;
}

/// Header secondario con freccia e titolo neri (non usa AppBar Material 3).
class SecondaryPageScaffold extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;

  const SecondaryPageScaffold({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = padded
        ? Padding(
            padding: Dimensions.pagePaddingInsetsFor(context),
            child: body,
          )
        : body;

    return Scaffold(
      backgroundColor: PageShellTheme.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: PageShellTheme.appBarBackground,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Indietro',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                    Expanded(
                      child: Text(
                        pageTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: content),
          if (bottomBar != null)
            Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black26,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: Dimensions.resolvedBottomInset(context),
                ),
                child: bottomBar!,
              ),
            ),
        ],
      ),
    );
  }
}

class PageShellBody extends StatelessWidget {
  final String? pageTitle;
  final Widget child;
  final bool showPageTitle;

  const PageShellBody({
    super.key,
    required this.child,
    this.pageTitle,
    this.showPageTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final padding = Dimensions.pagePaddingInsetsFor(context);
    final titleSize = Dimensions.pageTitleSizeFor(context);
    final spacing = Dimensions.sectionSpacingFor(context);
    final isPhone = Dimensions.isPhone(context);

    return SafeArea(
      left: false,
      right: false,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPageTitle && pageTitle != null && pageTitle!.isNotEmpty) ...[
              Text(
                pageTitle!,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final area = SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight,
                    child: child,
                  );

                  if (isPhone) return area;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Dimensions.shellContentMaxWidthFor(context),
                        maxHeight: constraints.maxHeight,
                      ),
                      child: area,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

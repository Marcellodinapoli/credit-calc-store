import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import '../../core/theme/project_colors.dart';

enum BrandedPageProject { calc, form, job, area }

/// Nome progetto + titolo pagina (stile CreditCalcDefaultLayout).
class BrandedPageTitleRow extends StatelessWidget {
  final BrandedPageProject project;
  final String pageTitle;
  final double pageTitleFontSize;
  final FontWeight pageTitleWeight;
  final Color pageTitleColor;

  const BrandedPageTitleRow({
    super.key,
    required this.project,
    required this.pageTitle,
    this.pageTitleFontSize = 20,
    this.pageTitleWeight = FontWeight.w600,
    this.pageTitleColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _projectLabel(),
        if (pageTitle.isNotEmpty) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '· $pageTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: pageTitleFontSize,
                fontWeight: pageTitleWeight,
                color: pageTitleColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _projectLabel() {
    switch (project) {
      case BrandedPageProject.calc:
        return Text.rich(
          TextSpan(
            children: const [
              TextSpan(
                text: 'Credit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: 'Calc',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ProjectColors.calc,
                ),
              ),
            ],
          ),
        );
      case BrandedPageProject.form:
        return const Text(
          'CreditForm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ProjectColors.form,
          ),
        );
      case BrandedPageProject.job:
        return const Text(
          'CreditJob',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ProjectColors.job,
          ),
        );
      case BrandedPageProject.area:
        return const Text(
          'CreditCore',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ProjectColors.area,
          ),
        );
    }
  }
}

abstract final class PageShellTheme {
  static const Color appBarBackground = Color(0xFFECEFF1);
  static const Color scaffoldBackground = Colors.white;
  static const Color drawerBackground = Color(0xFFECEFF1);
  static const double sidebarWidth = 260;
}

/// Header secondario con freccia e titolo neri (non usa AppBar Material 3).
class SecondaryPageScaffold extends StatelessWidget {
  final String pageTitle;
  final BrandedPageProject? project;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;

  const SecondaryPageScaffold({
    super.key,
    required this.pageTitle,
    this.project,
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
                      child: project == null
                          ? Text(
                              pageTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : BrandedPageTitleRow(
                              project: project!,
                              pageTitle: pageTitle,
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
  final BrandedPageProject? project;
  final Widget child;
  final bool showPageTitle;

  const PageShellBody({
    super.key,
    required this.child,
    this.pageTitle,
    this.project,
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
              project == null
                  ? Text(
                      pageTitle!,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : BrandedPageTitleRow(
                      project: project!,
                      pageTitle: pageTitle!,
                      pageTitleFontSize: titleSize,
                      pageTitleWeight: FontWeight.bold,
                      pageTitleColor: Colors.black,
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

import 'package:flutter/material.dart';

import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import 'dm_app_background.dart';

typedef DmResponsiveBodyBuilder = Widget Function(
  BuildContext context,
  DMBreakpoint breakpoint,
);

class DmResponsiveScaffold extends StatelessWidget {
  const DmResponsiveScaffold({
    super.key,
    this.body,
    this.bodyBuilder,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundGradient = DMGradients.appBackground,
    this.backgroundColor = DMColors.deepNavy,
    this.backgroundForeground,
    this.padding,
    this.applyPagePadding = true,
    this.centerContent = true,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset,
    this.extendBody = true,
    this.extendBodyBehindAppBar = false,
  }) : assert(
          body != null || bodyBuilder != null,
          'Provide either body or bodyBuilder.',
        );

  final Widget? body;
  final DmResponsiveBodyBuilder? bodyBuilder;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Gradient? backgroundGradient;
  final Color backgroundColor;
  final Widget? backgroundForeground;
  final EdgeInsetsGeometry? padding;
  final bool applyPagePadding;
  final bool centerContent;
  final bool useSafeArea;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final breakpoint = DMBreakpoints.fromWidth(width);
        final maxWidth = DMBreakpoints.maxContentWidth(breakpoint);

        Widget content = bodyBuilder?.call(context, breakpoint) ?? body!;

        if (applyPagePadding) {
          content = Padding(
            padding: padding ?? DMSpacing.pagePaddingForWidth(width),
            child: content,
          );
        } else if (padding != null) {
          content = Padding(padding: padding!, child: content);
        }

        if (centerContent) {
          final centeredContent = content;
          content = LayoutBuilder(
            builder: (context, contentConstraints) {
              final minHeight = contentConstraints.maxHeight.isFinite
                  ? contentConstraints.maxHeight
                  : 0.0;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minHeight: minHeight,
                  ),
                  child: centeredContent,
                ),
              );
            },
          );
        }

        if (useSafeArea) {
          content = SafeArea(
            top: appBar == null,
            bottom: bottomNavigationBar == null,
            child: content,
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          drawer: drawer,
          endDrawer: endDrawer,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          extendBody: extendBody,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          body: DmAppBackground(
            gradient: backgroundGradient,
            color: backgroundColor,
            foreground: backgroundForeground,
            child: content,
          ),
        );
      },
    );
  }
}

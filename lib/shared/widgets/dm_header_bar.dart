import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import 'dm_buttons.dart';

class DmHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const DmHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onBackPressed,
    this.backSemanticLabel = 'Go back',
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBackPressed;
  final String backSemanticLabel;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 80);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      foregroundColor: DMColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      toolbarHeight: preferredSize.height,
      leadingWidth: leading != null || onBackPressed != null ? 64 : 0,
      leading: leading ??
          (onBackPressed == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: DMSpacing.sm),
                  child: DmIconButton(
                    icon: const Icon(Icons.arrow_back),
                    semanticLabel: backSemanticLabel,
                    onPressed: onBackPressed,
                  ),
                )),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.headingSmall,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DMSpacing.xxs),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(right: DMSpacing.xs),
            child: action,
          ),
      ],
    );
  }
}

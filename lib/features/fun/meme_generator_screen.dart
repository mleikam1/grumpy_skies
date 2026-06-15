import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../shared/widgets/daymaker_components.dart';
import 'widgets/meme_canvas.dart';
import 'widgets/meme_style.dart';
import 'widgets/meme_style_tabs.dart';
import 'widgets/meme_text_field.dart';
import 'widgets/meme_tool_card.dart';

class MemeGeneratorScreen extends StatefulWidget {
  const MemeGeneratorScreen({super.key});

  @override
  State<MemeGeneratorScreen> createState() => _MemeGeneratorScreenState();
}

class _MemeGeneratorScreenState extends State<MemeGeneratorScreen> {
  static const _maxMemeTextLength = 72;
  static const _randomLines = <_MemeLine>[
    _MemeLine(
      top: 'WHEN THE FORECAST SAYS CLEAR',
      bottom: 'BUT THE CLOUDS CHOOSE DRAMA',
    ),
    _MemeLine(
      top: 'ME CHECKING THE RADAR',
      bottom: 'LIKE IT OWES ME AN APOLOGY',
    ),
    _MemeLine(
      top: 'SUNNY WITH A CHANCE',
      bottom: 'OF SIDE-EYE FROM THE SKY',
    ),
    _MemeLine(
      top: 'THE WIND SAID RELAX',
      bottom: 'THEN STOLE MY HAT',
    ),
    _MemeLine(
      top: 'HUMIDITY WALKED IN',
      bottom: 'AND MADE IT EVERYONE\'S PROBLEM',
    ),
  ];

  final _random = Random();
  final _canvasKey = GlobalKey();
  late final TextEditingController _topTextController;
  late final TextEditingController _bottomTextController;

  MemeVisualStyle _selectedStyle = MemeVisualStyle.epic;
  var _backgroundIndex = 0;

  @override
  void initState() {
    super.initState();
    _topTextController = TextEditingController(
      text: 'WHEN THE WEATHER APP',
    )..addListener(_handleMemeTextChanged);
    _bottomTextController = TextEditingController(
      text: 'HAS MAIN CHARACTER ENERGY',
    )..addListener(_handleMemeTextChanged);
  }

  @override
  void dispose() {
    _topTextController
      ..removeListener(_handleMemeTextChanged)
      ..dispose();
    _bottomTextController
      ..removeListener(_handleMemeTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleMemeTextChanged() {
    setState(() {});
  }

  void _setMemeText(_MemeLine line) {
    _topTextController.value = TextEditingValue(
      text: line.top,
      selection: TextSelection.collapsed(offset: line.top.length),
    );
    _bottomTextController.value = TextEditingValue(
      text: line.bottom,
      selection: TextSelection.collapsed(offset: line.bottom.length),
    );
  }

  void _changeBackground() {
    setState(() {
      _backgroundIndex = (_backgroundIndex + 1) % memeBackgroundPresets.length;
    });
  }

  void _useCurrentRoast() {
    _setMemeText(
      const _MemeLine(
        top: 'TODAY\'S FORECAST',
        bottom: 'A LITTLE RUDE, VERY SHAREABLE',
      ),
    );
    _showSnackBar('Current roast dropped into the meme.');
  }

  void _randomizeText() {
    final nextLine = _randomLines[_random.nextInt(_randomLines.length)];
    _setMemeText(nextLine);
  }

  void _exportAndShare() {
    _showSnackBar('Export & Share will capture this canvas soon.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DmResponsiveScaffold(
      appBar: DmHeaderBar(
        title: 'DayMaker',
        subtitle: 'Meme Generator',
        onBackPressed: () => context.go(AppRoutes.fun),
        actions: const [_ProPill()],
      ),
      backgroundGradient: _memeGradient,
      bodyBuilder: (context, breakpoint) {
        final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;
        final content = breakpoint.isExpanded
            ? _ExpandedMemeLayout(
                gap: gap,
                canvas: _buildCanvas(),
                styleTabs: _buildStyleTabs(breakpoint),
                textControls: _buildTextControls(),
                tools: _buildTools(breakpoint),
              )
            : _StackedMemeLayout(
                gap: gap,
                canvas: _buildCanvas(),
                styleTabs: _buildStyleTabs(breakpoint),
                textControls: _buildTextControls(),
                tools: _buildTools(breakpoint),
              );

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [content],
        );
      },
    );
  }

  Widget _buildCanvas() {
    return MemeCanvas(
      boundaryKey: _canvasKey,
      topText: _topTextController.text,
      bottomText: _bottomTextController.text,
      style: _selectedStyle,
      background: memeBackgroundPresets[_backgroundIndex],
    );
  }

  Widget _buildStyleTabs(DMBreakpoint breakpoint) {
    return _SectionCard(
      child: MemeStyleTabs(
        selectedStyle: _selectedStyle,
        compact: breakpoint.isCompact,
        onChanged: (style) {
          setState(() {
            _selectedStyle = style;
          });
        },
      ),
    );
  }

  Widget _buildTextControls() {
    return _SectionCard(
      child: Column(
        children: [
          MemeTextField(
            label: 'Top Text',
            controller: _topTextController,
            maxLength: _maxMemeTextLength,
            hintText: 'Add a dramatic opening line',
          ),
          const SizedBox(height: DMSpacing.md),
          MemeTextField(
            label: 'Bottom Text',
            controller: _bottomTextController,
            maxLength: _maxMemeTextLength,
            hintText: 'Add the punchline',
          ),
        ],
      ),
    );
  }

  Widget _buildTools(DMBreakpoint breakpoint) {
    final crossAxisCount = breakpoint.isCompact ? 2 : 4;
    final mainAxisExtent = breakpoint.isCompact ? 156.0 : 152.0;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: DMSpacing.md,
        mainAxisSpacing: DMSpacing.md,
        mainAxisExtent: mainAxisExtent,
      ),
      children: [
        MemeToolCard(
          icon: Icons.add_photo_alternate_outlined,
          label: 'Change Background',
          color: DMColors.skyBlue,
          onTap: _changeBackground,
        ),
        MemeToolCard(
          icon: Icons.local_fire_department_outlined,
          label: 'Use Current Roast',
          color: DMColors.coral,
          onTap: _useCurrentRoast,
        ),
        MemeToolCard(
          icon: Icons.shuffle_rounded,
          label: 'Randomize Text',
          color: DMColors.sunriseYellow,
          onTap: _randomizeText,
        ),
        MemeToolCard(
          icon: Icons.ios_share_rounded,
          label: 'Export & Share',
          color: DMColors.mintGreen,
          onTap: _exportAndShare,
        ),
      ],
    );
  }
}

class _ExpandedMemeLayout extends StatelessWidget {
  const _ExpandedMemeLayout({
    required this.gap,
    required this.canvas,
    required this.styleTabs,
    required this.textControls,
    required this.tools,
  });

  final double gap;
  final Widget canvas;
  final Widget styleTabs;
  final Widget textControls;
  final Widget tools;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              canvas,
              SizedBox(height: gap),
              styleTabs,
            ],
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textControls,
              SizedBox(height: gap),
              tools,
            ],
          ),
        ),
      ],
    );
  }
}

class _StackedMemeLayout extends StatelessWidget {
  const _StackedMemeLayout({
    required this.gap,
    required this.canvas,
    required this.styleTabs,
    required this.textControls,
    required this.tools,
  });

  final double gap;
  final Widget canvas;
  final Widget styleTabs;
  final Widget textControls;
  final Widget tools;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        canvas,
        SizedBox(height: gap),
        styleTabs,
        SizedBox(height: gap),
        textControls,
        SizedBox(height: gap),
        tools,
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      borderColor: DMColors.glassBorderStrong,
      child: child,
    );
  }
}

class _ProPill extends StatelessWidget {
  const _ProPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: DMGradients.primaryAction,
        borderRadius: DMRadius.full,
        boxShadow: DMShadows.sunGlow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.md,
          vertical: DMSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: DMColors.deepNavy,
              size: DMSpacing.iconSm,
            ),
            const SizedBox(width: DMSpacing.xxs),
            Text(
              'Pro',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.label.copyWith(
                color: DMColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemeLine {
  const _MemeLine({
    required this.top,
    required this.bottom,
  });

  final String top;
  final String bottom;
}

const _memeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    DMColors.deepNavy,
    DMColors.twilightNavy,
    DMColors.lavenderDeep,
    DMColors.playfulPink,
  ],
  stops: [0, 0.42, 0.76, 1],
);

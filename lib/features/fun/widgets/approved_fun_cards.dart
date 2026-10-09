import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';

class ApprovedFunPromo extends StatelessWidget {
  const ApprovedFunPromo({super.key, required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final c = context.dmColors;
    return Container(
      decoration: BoxDecoration(
          color: c.promoSurface, borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
        final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      border:
                          Border.all(color: c.promoText.withValues(alpha: .3)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('MEME STUDIO',
                      style: TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: c.promoText))),
              const SizedBox(height: 10),
              Text('Same skies.\nNew material.',
                  style: TextStyle(
                      fontSize: 25,
                      height: 1.05,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w800,
                      color: c.promoText)),
              const SizedBox(height: 8),
              Text(
                  "Use today's weather,\nadd a little attitude,\nand make it a meme.",
                  style:
                      TextStyle(fontSize: 13, height: 1.3, color: c.promoText)),
              const SizedBox(height: 10),
              FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                      backgroundColor: c.promoAction,
                      foregroundColor: c.onPromoAction,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontFamily: 'DaymakerSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  child: const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text('Create a meme'),
                        Icon(Icons.arrow_forward, size: 18)
                      ])),
            ]);
        final art = Stack(children: [
          Positioned.fill(
              child: Image.asset(
                  'assets/approved_v1/weather/sunglasses_cloud.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true)),
          Positioned(
              right: 8,
              bottom: 8,
              child: Transform.rotate(
                  angle: -.12,
                  child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(3),
                      child: const Text('GOOD\nWEATHER\nBAD DECISIONS',
                          style: TextStyle(
                              fontFamily: 'MemeSans',
                              fontWeight: FontWeight.w900,
                              color: Color(0xff0b1c40),
                              fontSize: 12,
                              height: .95))))),
        ]);
        if (largeText) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, SizedBox(height: 170, child: art)]);
        }
        return Stack(children: [
          Positioned(
              right: -6,
              top: 14,
              bottom: -5,
              width: constraints.maxWidth * .55,
              child: art),
          SizedBox(width: constraints.maxWidth * .57, child: copy)
        ]);
      }),
    );
  }
}

class ApprovedTemplateTile extends StatelessWidget {
  const ApprovedTemplateTile(
      {super.key,
      required this.title,
      required this.caption,
      required this.asset,
      required this.color,
      required this.onTap});
  final String title, caption, asset;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: 82,
                        child: Center(
                            child: Image.asset(asset,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true))),
                    const SizedBox(height: 5),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    const SizedBox(height: 7),
                    Text('“$caption”',
                        style: TextStyle(
                            fontSize: 10,
                            height: 1.25,
                            color: context.dmColors.textSecondary)),
                  ]))));
}

class ApprovedFeaturedMeme extends StatelessWidget {
  const ApprovedFeaturedMeme({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: 'Edit featured meme: Forecast, 100 percent chance of no chill',
      child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: AspectRatio(
                  aspectRatio: 2.75,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(
                        'assets/approved_v1/memes/beach_sun_background.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true),
                    Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                            widthFactor: .49,
                            child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Transform.rotate(
                                    angle: -.07,
                                    child: Stack(children: [
                                      Text(
                                          'FORECAST:\n100% CHANCE\nOF NO CHILL.',
                                          textScaler: TextScaler.noScaling,
                                          style: TextStyle(
                                              fontFamily: 'MemeSans',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              height: .98,
                                              foreground: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = 5
                                                ..color =
                                                    const Color(0xff0b1c40))),
                                      const Text(
                                          'FORECAST:\n100% CHANCE\nOF NO CHILL.',
                                          textScaler: TextScaler.noScaling,
                                          style: TextStyle(
                                              fontFamily: 'MemeSans',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              height: .98,
                                              color: Colors.white)),
                                    ]))))),
                  ])))));
}

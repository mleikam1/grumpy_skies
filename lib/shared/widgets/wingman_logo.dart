import 'package:flutter/material.dart';

import '../../config/wingman_brand.dart';

/// The approved, uncolored tile; only its exterior presentation margin is masked.
class WingmanLogo extends StatelessWidget {
  const WingmanLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        WingmanBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: WingmanBrand.name,
        filterQuality: FilterQuality.high,
      );
}

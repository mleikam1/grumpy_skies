import 'package:flutter/material.dart';

import 'dm_colors.dart';

abstract final class DMShadows {
  const DMShadows._();

  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: DMColors.shadowSoft,
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: DMColors.shadow,
      blurRadius: 28,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: DMColors.shadowSoft,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: DMColors.shadow,
      blurRadius: 44,
      offset: Offset(0, 24),
    ),
  ];

  static const List<BoxShadow> skyGlow = <BoxShadow>[
    BoxShadow(
      color: DMColors.skyGlow,
      blurRadius: 28,
      spreadRadius: 1,
    ),
  ];

  static const List<BoxShadow> sunGlow = <BoxShadow>[
    BoxShadow(
      color: DMColors.sunGlow,
      blurRadius: 30,
      spreadRadius: 2,
    ),
  ];

  static const List<BoxShadow> playfulGlow = <BoxShadow>[
    BoxShadow(
      color: DMColors.pinkGlow,
      blurRadius: 30,
      spreadRadius: 1,
    ),
  ];

  static const List<BoxShadow> mintGlow = <BoxShadow>[
    BoxShadow(
      color: DMColors.mintGlow,
      blurRadius: 30,
      spreadRadius: 1,
    ),
  ];
}

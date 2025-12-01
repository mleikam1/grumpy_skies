enum PersonaType { karen, fratBro, grandpa, politician, toddler }

extension PersonaTypeExt on PersonaType {
  String get displayName {
    switch (this) {
      case PersonaType.karen:
        return 'Karen';
      case PersonaType.fratBro:
        return 'Frat Bro';
      case PersonaType.grandpa:
        return 'Grandpa';
      case PersonaType.politician:
        return 'Politician';
      case PersonaType.toddler:
        return '2-Year-Old';
    }
  }
}

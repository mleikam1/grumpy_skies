enum PersonaType { karen, fratBro, twoYearOld, politician, grandpa }

extension PersonaTypeExt on PersonaType {
  String get displayName {
    switch (this) {
      case PersonaType.karen:
        return 'Karen';
      case PersonaType.fratBro:
        return 'Frat Bro';
      case PersonaType.twoYearOld:
        return '2-Year-Old';
      case PersonaType.politician:
        return 'Politician';
      case PersonaType.grandpa:
        return 'Grandpa';
    }
  }
}

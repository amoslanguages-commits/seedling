class Language {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isAvailable;

  Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.isAvailable = true,
  });
}

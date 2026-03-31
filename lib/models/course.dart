import 'dart:convert';

/// Supported languages with their flag emoji and display name.
class Language {
  final String code;
  final String name;
  final String flag;

  const Language({required this.code, required this.name, required this.flag});

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'flag': flag};

  factory Language.fromJson(Map<String, dynamic> j) =>
      Language(code: j['code'], name: j['name'], flag: j['flag']);

  static const List<Language> all = [
    Language(code: 'om', name: 'Afaan Oromo', flag: '🇪🇹'),
    Language(code: 'af', name: 'Afrikaans', flag: '🇿🇦'),
    Language(code: 'ak', name: 'Akan / Twi', flag: '🇬🇭'),
    Language(code: 'sq', name: 'Albanian', flag: '🇦🇱'),
    Language(code: 'am', name: 'Amharic', flag: '🇪🇹'),
    Language(code: 'ar', name: 'Arabic (Modern Standard)', flag: '🇸🇦'),
    Language(code: 'hy', name: 'Armenian', flag: '🇦🇲'),
    Language(code: 'as', name: 'Assamese', flag: '🇮🇳'),
    Language(code: 'az', name: 'Azerbaijani', flag: '🇦🇿'),
    Language(code: 'eu', name: 'Basque', flag: '🇪🇸'),
    Language(code: 'be', name: 'Belarusian', flag: '🇧🇾'),
    Language(code: 'bn', name: 'Bengali', flag: '🇧🇩'),
    Language(code: 'bho', name: 'Bhojpuri', flag: '🇮🇳'),
    Language(code: 'bs', name: 'Bosnian', flag: '🇧🇦'),
    Language(code: 'bg', name: 'Bulgarian', flag: '🇧🇬'),
    Language(code: 'my', name: 'Burmese (Myanmar)', flag: '🇲🇲'),
    Language(code: 'yue', name: 'Cantonese', flag: '🇭🇰'),
    Language(code: 'ca', name: 'Catalan', flag: '🇪🇸'),
    Language(code: 'ceb', name: 'Cebuano', flag: '🇵🇭'),
    Language(code: 'ny', name: 'Chichewa / Chewa', flag: '🇲🇼'),
    Language(code: 'zh-CN', name: 'Chinese (Simplified)', flag: '🇨🇳'),
    Language(code: 'zh-TW', name: 'Chinese (Traditional)', flag: '🇹🇼'),
    Language(code: 'hr', name: 'Croatian', flag: '🇭🇷'),
    Language(code: 'cs', name: 'Czech', flag: '🇨🇿'),
    Language(code: 'da', name: 'Danish', flag: '🇩🇰'),
    Language(code: 'nl', name: 'Dutch', flag: '🇳🇱'),
    Language(code: 'en-GB', name: 'English (UK)', flag: '🇬🇧'),
    Language(code: 'en-US', name: 'English (US)', flag: '🇺🇸'),
    Language(code: 'et', name: 'Estonian', flag: '🇪🇪'),
    Language(code: 'fil', name: 'Filipino / Tagalog', flag: '🇵🇭'),
    Language(code: 'fi', name: 'Finnish', flag: '🇫🇮'),
    Language(code: 'fr', name: 'French', flag: '🇫🇷'),
    Language(code: 'fr-CA', name: 'French (Canada)', flag: '🇨🇦'),
    Language(code: 'ff', name: 'Fulani / Fula', flag: '🇸🇳'),
    Language(code: 'gl', name: 'Galician', flag: '🇪🇸'),
    Language(code: 'ka', name: 'Georgian', flag: '🇬🇪'),
    Language(code: 'de', name: 'German', flag: '🇩🇪'),
    Language(code: 'el', name: 'Greek', flag: '🇬🇷'),
    Language(code: 'gn', name: 'Guarani', flag: '🇵🇾'),
    Language(code: 'gu', name: 'Gujarati', flag: '🇮🇳'),
    Language(code: 'ht', name: 'Haitian Creole', flag: '🇭🇹'),
    Language(code: 'ha', name: 'Hausa', flag: '🇳🇬'),
    Language(code: 'he', name: 'Hebrew', flag: '🇮🇱'),
    Language(code: 'hi', name: 'Hindi', flag: '🇮🇳'),
    Language(code: 'hmn', name: 'Hmong', flag: '🇱🇦'),
    Language(code: 'hu', name: 'Hungarian', flag: '🇭🇺'),
    Language(code: 'is', name: 'Icelandic', flag: '🇮🇸'),
    Language(code: 'ig', name: 'Igbo', flag: '🇳🇬'),
    Language(code: 'id', name: 'Indonesian', flag: '🇮🇩'),
    Language(code: 'ga', name: 'Irish (Gaeilge)', flag: '🇮🇪'),
    Language(code: 'xh', name: 'isiXhosa', flag: '🇿🇦'),
    Language(code: 'it', name: 'Italian', flag: '🇮🇹'),
    Language(code: 'ja', name: 'Japanese', flag: '🇯🇵'),
    Language(code: 'jv', name: 'Javanese', flag: '🇮🇩'),
    Language(code: 'kn', name: 'Kannada', flag: '🇮🇳'),
    Language(code: 'ks', name: 'Kashmiri', flag: '🇮🇳'),
    Language(code: 'kk', name: 'Kazakh', flag: '🇰🇿'),
    Language(code: 'km', name: 'Khmer', flag: '🇰🇭'),
    Language(code: 'rw', name: 'Kinyarwanda', flag: '🇷🇼'),
    Language(code: 'ko', name: 'Korean', flag: '🇰🇷'),
    Language(code: 'ku', name: 'Kurdish', flag: '🌍'),
    Language(code: 'ky', name: 'Kyrgyz', flag: '🇰🇬'),
    Language(code: 'lo', name: 'Lao', flag: '🇱🇦'),
    Language(code: 'lv', name: 'Latvian', flag: '🇱🇻'),
    Language(code: 'ln', name: 'Lingala', flag: '🇨🇩'),
    Language(code: 'lt', name: 'Lithuanian', flag: '🇱🇹'),
    Language(code: 'lg', name: 'Luganda (Ganda)', flag: '🇺🇬'),
    Language(code: 'lb', name: 'Luxembourgish', flag: '🇱🇺'),
    Language(code: 'mk', name: 'Macedonian', flag: '🇲🇰'),
    Language(code: 'mad', name: 'Madurese', flag: '🇮🇩'),
    Language(code: 'mg', name: 'Malagasy', flag: '🇲🇬'),
    Language(code: 'ms', name: 'Malay', flag: '🇲🇾'),
    Language(code: 'ml', name: 'Malayalam', flag: '🇮🇳'),
    Language(code: 'mt', name: 'Maltese', flag: '🇲🇹'),
    Language(code: 'mr', name: 'Marathi', flag: '🇮🇳'),
    Language(code: 'mi', name: 'Māori', flag: '🇳🇿'),
    Language(code: 'mn', name: 'Mongolian', flag: '🇲🇳'),
    Language(code: 'ne', name: 'Nepali', flag: '🇳🇵'),
    Language(code: 'pcm', name: 'Nigerian Pidgin', flag: '🇳🇬'),
    Language(code: 'nb-NO', name: 'Norwegian Bokmål', flag: '🇳🇴'),
    Language(code: 'or', name: 'Odia (Oriya)', flag: '🇮🇳'),
    Language(code: 'ps', name: 'Pashto', flag: '🇦🇫'),
    Language(code: 'fa', name: 'Persian / Farsi', flag: '🇮🇷'),
    Language(code: 'pl', name: 'Polish', flag: '🇵🇱'),
    Language(code: 'pt-BR', name: 'Portuguese (Brazil)', flag: '🇧🇷'),
    Language(code: 'pt-PT', name: 'Portuguese (Portugal)', flag: '🇵🇹'),
    Language(code: 'pa', name: 'Punjabi', flag: '🇮🇳'),
    Language(code: 'qu', name: 'Quechua (Standard)', flag: '🇵🇪'),
    Language(code: 'ro', name: 'Romanian', flag: '🇷🇴'),
    Language(code: 'ru', name: 'Russian', flag: '🇷🇺'),
    Language(code: 'skr', name: 'Saraiki', flag: '🇵🇰'),
    Language(code: 'sr', name: 'Serbian', flag: '🇷🇸'),
    Language(code: 'st', name: 'Sesotho', flag: '🇱🇸'),
    Language(code: 'sn', name: 'Shona', flag: '🇿🇼'),
    Language(code: 'sd', name: 'Sindhi', flag: '🇵🇰'),
    Language(code: 'si', name: 'Sinhala', flag: '🇱🇰'),
    Language(code: 'sk', name: 'Slovak', flag: '🇸🇰'),
    Language(code: 'sl', name: 'Slovenian', flag: '🇸🇮'),
    Language(code: 'so', name: 'Somali', flag: '🇸🇴'),
    Language(code: 'es-MX', name: 'Spanish (LatAm)', flag: '🇲🇽'),
    Language(code: 'es-ES', name: 'Spanish (Spain)', flag: '🇪🇸'),
    Language(code: 'su', name: 'Sundanese', flag: '🇮🇩'),
    Language(code: 'sw', name: 'Swahili', flag: '🇹🇿'),
    Language(code: 'sv', name: 'Swedish', flag: '🇸🇪'),
    Language(code: 'tg', name: 'Tajik', flag: '🇹🇯'),
    Language(code: 'ta', name: 'Tamil', flag: '🇮🇳'),
    Language(code: 'tt', name: 'Tatar', flag: '🇷🇺'),
    Language(code: 'te', name: 'Telugu', flag: '🇮🇳'),
    Language(code: 'th', name: 'Thai', flag: '🇹🇭'),
    Language(code: 'ti', name: 'Tigrinya', flag: '🇪🇷'),
    Language(code: 'tr', name: 'Turkish', flag: '🇹🇷'),
    Language(code: 'tk', name: 'Turkmen', flag: '🇹🇲'),
    Language(code: 'uk', name: 'Ukrainian', flag: '🇺🇦'),
    Language(code: 'ur', name: 'Urdu', flag: '🇵🇰'),
    Language(code: 'ug', name: 'Uyghur', flag: '🇨🇳'),
    Language(code: 'uz', name: 'Uzbek', flag: '🇺🇿'),
    Language(code: 'vi', name: 'Vietnamese', flag: '🇻🇳'),
    Language(code: 'cy', name: 'Welsh', flag: '🏴'),
    Language(code: 'wo', name: 'Wolof', flag: '🇸🇳'),
    Language(code: 'yo', name: 'Yoruba', flag: '🇳🇬'),
    Language(code: 'zu', name: 'Zulu', flag: '🇿🇦'),
  ];

  static Language? byCode(String code) {
    try {
      return all.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a learning direction: native → target language.
class Course {
  final String id;
  final Language nativeLanguage;
  final Language targetLanguage;

  Course({
    required this.id,
    required this.nativeLanguage,
    required this.targetLanguage,
  });

  String get displayTitle => targetLanguage.name;
  String get displaySubtitle => 'from ${nativeLanguage.name}';
  String get emoji => targetLanguage.flag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'native': nativeLanguage.toJson(),
        'target': targetLanguage.toJson(),
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        nativeLanguage: Language.fromJson(j['native'] as Map<String, dynamic>),
        targetLanguage: Language.fromJson(j['target'] as Map<String, dynamic>),
      );

  static List<Course> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Course> courses) =>
      jsonEncode(courses.map((c) => c.toJson()).toList());
}

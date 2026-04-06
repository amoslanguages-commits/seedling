import re

with open('taxonomy_raw.txt', 'r', encoding='utf-8') as f:
    lines = f.read().strip().split('\n')

themes = []
current_theme = None
current_subthemes = []

# Colors and icons map for themes
theme_styles = {
    'PEOPLE': {'icon': '👥', 'color': '0xFF64B5F6'},
    'DAILY LIFE': {'icon': '🌅', 'color': '0xFFF06292'},
    'FOOD & DRINK': {'icon': '🍽️', 'color': '0xFFFFB74D'},
    'HOME & ENVIRONMENT': {'icon': '🏠', 'color': '0xFF81C784'},
    'EDUCATION': {'icon': '📚', 'color': '0xFF4FC3F7'},
    'WORK & BUSINESS': {'icon': '💼', 'color': '0xFF9575CD'},
    'TRAVEL & TRANSPORT': {'icon': '✈️', 'color': '0xFF4DD0E1'},
    'SOCIETY & GOVERNMENT': {'icon': '🏛️', 'color': '0xFF7986CB'},
    'TECHNOLOGY': {'icon': '💻', 'color': '0xFF90A4AE'},
    'TIME & SPACE': {'icon': '🕰️', 'color': '0xFFFF8A65'},
    'NUMBERS & MEASUREMENT': {'icon': '🔢', 'color': '0xFF4DB6AC'},
    'UNIVERSAL VERBS': {'icon': '⚡', 'color': '0xFFE57373', 'pos': "['verb']"},
    'DESCRIPTIONS': {'icon': '🎨', 'color': '0xFFCE93D8', 'pos': "['adjective', 'adverb']"},
    'ABSTRACT CONCEPTS': {'icon': '💭', 'color': '0xFFBA68C8', 'pos': "['noun']"},
    'GRAMMAR FUNCTIONS': {'icon': '🔧', 'color': '0xFFB0BEC5', 'pos': "['pronoun', 'preposition', 'conjunction']"}
}

for line in lines:
    line = line.strip()
    if not line:
        continue
    m = re.match(r'^\d+\.\s+(.*)', line)
    if m:
        if current_theme:
            themes.append((current_theme, current_subthemes))
        current_theme = m.group(1).strip()
        current_subthemes = []
    elif '→' in line:
        sub = line.split('→')[0].strip()
        current_subthemes.append(sub)
        
if current_theme:
    themes.append((current_theme, current_subthemes))

dart_code = """class CategoryTaxonomy {
  static final Map<String, SemanticCategory> _categories = {
"""

# Roots
dart_code += "    // ================== ROOT THEMES ==================\n"
for t, subs in themes:
    tid = t.lower().replace(' & ', '_').replace(' ', '_')
    name = t.title().replace(' & ', ' & ')
    style = theme_styles.get(t, {'icon': '📌', 'color': '0xFF999999'})
    icon = style['icon']
    color = style['color']
    pos_line = f"\n      commonPOS: {style['pos']}," if 'pos' in style else ""
    
    sub_ids = []
    for s in subs:
        sid = s.lower().replace(' & ', '_').replace(' ', '_')
        sub_ids.append(f"'{sid}'")
    child_ids_str = ", ".join(sub_ids)
    
    dart_code += f"""    '{tid}': SemanticCategory(
      id: '{tid}',
      name: '{name}',
      icon: '{icon}',
      color: const Color({color}),
      childIds: [{child_ids_str}],{pos_line}
    ),
"""

# Subs
dart_code += "\n    // ================== SUB THEMES ==================\n"
all_subs = set()
for t, subs in themes:
    tid = t.lower().replace(' & ', '_').replace(' ', '_')
    style = theme_styles.get(t, {'icon': '📌', 'color': '0xFF999999'})
    color = style['color']
    
    for s in subs:
        sid = s.lower().replace(' & ', '_').replace(' ', '_')
        # Avoid duplicate ids across different themes just in case, though they look unique here
        if sid in all_subs:
            continue
        all_subs.add(sid)
        name = s.title().replace(' & ', ' & ')
        
        dart_code += f"""    '{sid}': SemanticCategory(
      id: '{sid}',
      name: '{name}',
      icon: '🌱', // Sub-themes can just use a leaf 
      color: const Color({color}),
      parentIds: ['{tid}'],
    ),
"""

dart_code += """  };

  static SemanticCategory? getCategory(String id) => _categories[id];
  
  static SemanticCategory? getTheme(String domainName) {
    return _categories.values.firstWhere(
      (c) => c.isRoot && c.name.toLowerCase() == domainName.toLowerCase(),
      orElse: () => _categories.values.first,
    );
  }

  static List<SemanticCategory> getRootCategories() {
    return _categories.values.where((c) => c.isRoot).toList();
  }

  static List<SemanticCategory> getSubCategories(String parentId) {
    return _categories.values
        .where((c) => c.parentIds.contains(parentId))
        .toList();
  }

  static List<SemanticCategory> getAllCategories() {
    return _categories.values.toList();
  }

  static List<SemanticCategory> getPathwayCategories() => getRootCategories();
}
"""

with open('taxonomy_new.dart', 'w', encoding='utf-8') as f:
    f.write(dart_code)

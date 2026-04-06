with open('../lib/models/taxonomy.dart', 'r', encoding='utf-8') as f:
    orig = f.read()

with open('taxonomy_new.dart', 'r', encoding='utf-8') as f:
    new_code = f.read()

import re
# We find everything from 'class CategoryTaxonomy {' to the end of the file
pattern = re.compile(r'class CategoryTaxonomy \{.*', re.DOTALL)
new_content = pattern.sub(new_code, orig)

with open('../lib/models/taxonomy.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

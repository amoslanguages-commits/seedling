import os, re
# More comprehensive list based on build failures
files_to_fix = []
for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            files_to_fix.append(os.path.join(root, f))

for f in files_to_fix:
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as fr:
            content = fr.read()
        
        # Only remove 'const ' if it's followed by a Widget or common container
        # This is a bit safer than removing ALL const
        new_content = re.sub(r'const\s+([A-Z][a-zA-Z0-9_\.]*)\(', r'\1(', content)
        
        if new_content != content:
            print(f"Fixed const in {f}")
            with open(f, 'w', encoding='utf-8') as fw:
                fw.write(new_content)
print("Global const cleanup done!")

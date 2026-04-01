import os

def fix_language_all():
    path = r'c:\app\seedling\lib\models\course.dart'
    if not os.path.exists(path):
        return
    
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    in_all_list = False
    for line in lines:
        if "static const List<Language> all = [" in line or "static List<Language> all = [" in line:
            in_all_list = True
            new_lines.append(line)
            continue
        
        if in_all_list:
            if "];" in line:
                in_all_list = False
                new_lines.append(line)
                continue
            
            # Add const to Language(...) if it's not already there
            if "Language(" in line and "const Language(" not in line:
                line = line.replace("Language(", "const Language(")
        
        new_lines.append(line)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

def fix_profile_screen():
    path = r'c:\app\seedling\lib\screens\profile_screen.dart'
    if not os.path.exists(path):
        return
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove const from ActivityTab children list on line 744 approximately
    # children: const [
    #   Text('Recent Activity', style: SeedlingTypography.heading3),
    content = content.replace("children: const [", "children: [")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_global_const():
    root = r'c:\app\seedling\lib'
    for dirpath, dirnames, filenames in os.walk(root):
        for filename in filenames:
            if filename.endswith('.dart'):
                path = os.path.join(dirpath, filename)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # If a line contains const and SeedlingColors or SeedlingTypography, it's likely invalid
                lines = content.split('\n')
                new_lines = []
                changed = False
                for line in lines:
                    if 'const' in line and ('SeedlingColors' in line or 'SeedlingTypography' in line):
                        line = line.replace('const ', '')
                        changed = True
                    new_lines.append(line)
                
                if changed:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write('\n'.join(new_lines))

if __name__ == "__main__":
    fix_language_all()
    fix_profile_screen()
    fix_global_const()

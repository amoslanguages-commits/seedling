import os, re
files = [
    'lib/screens/onboarding.dart', 
    'lib/screens/home/enhanced_home.dart', 
    'lib/screens/courses/course_management_screen.dart', 
    'lib/screens/courses/add_course_screen.dart', 
    'lib/screens/profile_screen.dart', 
    'lib/screens/settings.dart', 
    'lib/screens/social/competitions_screen.dart', 
    'lib/screens/social/friends_screen.dart', 
    'lib/screens/social/competition_detail_screen.dart', 
    'lib/screens/learning.dart', 
    'lib/widgets/quizzes.dart', 
    'lib/widgets/quizzes_v2.dart',
    'lib/main.dart'
]
for f in files:
    if os.path.exists(f):
        print(f"Fixing {f}...")
        with open(f, 'r', encoding='utf-8') as fr:
            c = fr.read()
        # Aggressively remove 'const ' keyword when it's followed by a capital letter (Widget or constructor)
        # This fixes nested const errors.
        c = re.sub(r'const\s+([A-Z])', r'\1', c)
        with open(f, 'w', encoding='utf-8') as fw:
            fw.write(c)
print("Done!")

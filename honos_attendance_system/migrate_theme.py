import os
import re

lib_dir = r"c:\Users\hp\Downloads\Honos Attendance System\honos_attendance_system\lib"

# Exclude these files from AppTheme replacement
exclude_files = ["app_theme.dart", "main.dart"]

def process_file(filepath):
    if any(ex in filepath for ex in exclude_files):
        return

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # If AppTheme is not used, skip
    if "AppTheme." not in content:
        return

    # Add import to app_theme.dart if context.colors is going to be used
    # Wait, we might need import 'package:honos_attendance_system/app_theme.dart';
    # Or a relative import. Usually, they already import app_theme if they used AppTheme.
    # So we don't necessarily need to add an import if they already imported it to use AppTheme.

    # 1. Replace AppTheme.someColor with context.colors.someColor
    # Exception: AppTheme.darkHeaderGradient -> context.colors.darkHeaderGradient
    # AppTheme.primary -> context.colors.primary

    new_content = re.sub(r'AppTheme\.([a-zA-Z0-9_]+)', r'context.colors.\1', content)

    # 2. Heuristically remove "const " before widgets that now use context.colors
    # This is tricky using pure regex because "const Text('...', style: TextStyle(color: context.colors...))" 
    # means the 'const' is at the Text widget.
    # A simple but aggressive approach is to remove "const " on the exact same line as context.colors
    # Let's do line-by-line removal of 'const ' if the line contains context.colors
    lines = new_content.split('\n')
    for i, line in enumerate(lines):
        if "context.colors." in line:
            # remove const 
            lines[i] = re.sub(r'\bconst\s+', '', line)

    new_content = '\n'.join(lines)

    if content != new_content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            process_file(os.path.join(root, file))

print("Done with initial AppTheme replacement.")

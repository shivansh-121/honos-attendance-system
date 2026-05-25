import os

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace hardcoded Colors.white in the Dashboard selected tile
    content = content.replace("color: Colors.white", "color: context.colors.primary")
    # Also replace selectedTileColor if it exists
    content = content.replace("selectedTileColor: Colors.white.withValues(alpha: 0.1)", "selectedTileColor: context.colors.primary.withValues(alpha: 0.1)")

    # Replace Color(0xFFCAD4E0) with context.colors.txtSec
    content = content.replace("Color(0xFFCAD4E0)", "context.colors.txtSec")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Processed {filepath}")

if __name__ == '__main__':
    files = [
        r'lib\screens\admin\admin_dashboard_screen.dart',
        r'lib\screens\executive\executive_dashboard_screen.dart',
        r'lib\screens\supervisor\sup_dashboard_screen.dart'
    ]
    for f in files:
        if os.path.exists(f):
            process_file(f)

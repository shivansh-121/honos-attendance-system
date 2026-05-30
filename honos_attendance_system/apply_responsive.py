"""
apply_responsive.py
Applies responsive wrappers to every screen and the Windows check-in popup
to Supervisor and Executive take_attendance screens.
Run from the project root: python apply_responsive.py
"""
import os, re

BASE = os.path.dirname(os.path.abspath(__file__))
SCREENS = os.path.join(BASE, "lib", "screens")

# ─── 1. Replace SliverPadding with ResponsiveSliverPadding in all dart files ────
SLIVER_PAD_RE = re.compile(
    r'SliverPadding\(\s*\n\s*padding:\s*const\s+EdgeInsets\.fromLTRB\((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)',
    re.MULTILINE
)

def replace_sliver_padding(content):
    """Replace SliverPadding(padding: const EdgeInsets.fromLTRB(h, t, h, b))
       with ResponsiveSliverPadding(extraPadding: EdgeInsets.fromLTRB(0,t,0,b))"""
    def replacer(m):
        left, top, right, bottom = m.group(1), m.group(2), m.group(3), m.group(4)
        return f'ResponsiveSliverPadding(\n        extraPadding: const EdgeInsets.fromLTRB(0, {top}, 0, {bottom})'
    return SLIVER_PAD_RE.sub(replacer, content)

# Also handle symmetric horizontal pattern
SLIVER_SYM_RE = re.compile(
    r'SliverPadding\(\s*\n\s*padding:\s*const\s+EdgeInsets\.symmetric\(horizontal:\s*(\d+)(?:,\s*vertical:\s*(\d+))?\)',
    re.MULTILINE
)

def replace_sliver_symmetric(content):
    def replacer(m):
        v = m.group(2) or '0'
        return f'ResponsiveSliverPadding(\n        extraPadding: const EdgeInsets.symmetric(vertical: {v})'
    return SLIVER_SYM_RE.sub(replacer, content)

# ─── 2. Wrap Scaffold body with responsiveBody() if not already wrapped ─────────
def wrap_scaffold_body(content, filename):
    """For non-dashboard non-sliver screens, wrap the body: content with responsiveBody()"""
    # Only target screens that use SingleChildScrollView or Column directly in body:
    # body: SingleChildScrollView( -> body: responsiveBody(SingleChildScrollView(
    patterns = [
        (r'(body:\s*)(SingleChildScrollView\()', r'\1responsiveBody(\2'),
    ]
    for pat, repl in patterns:
        # Avoid double-wrapping
        if 'responsiveBody(' not in content:
            content = re.sub(pat, repl, content, count=1)
    return content

# ─── 3. Windows popup for Supervisor take_attendance_screen ──────────────────────
SUP_CHECKIN_FILE = os.path.join(SCREENS, "supervisor", "take_attendance_screen.dart")
EXEC_CHECKIN_FILE = os.path.join(SCREENS, "executive", "executive_take_attendance_screen.dart")

WINDOWS_POPUP_INJECT = '''\
    // ── Windows: camera/facial recognition not supported ──
    if (!kIsWeb && Platform.isWindows) {
      if (mounted) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.colors.bgSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(Icons.smartphone, size: 52, color: context.colors.primary),
              title: Text(
                'Use Your Phone to Check In / Out',
                style: TextStyle(color: context.colors.txtPrimary, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: Text(
                'Attendance with facial recognition is only available on the mobile app.\\n\\nPlease open the Honos app on your phone to mark attendance.',
                style: TextStyle(color: context.colors.txtSec),
                textAlign: TextAlign.center,
              ),
              actions: [
                Center(child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got It'))),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
      }
      return;
    }
'''

def inject_windows_popup_supervisor(content):
    """Inject Windows popup at the start of _checkGps in supervisor take_attendance."""
    # Find _checkGps and inject after the kIsWeb check
    target = '    if (kIsWeb) {\n      if (mounted) setState(() { _gpsOk = true; _checkingGps = false; });\n      return;\n    }\n'
    if 'Platform.isWindows' not in content and target in content:
        content = content.replace(target, target + WINDOWS_POPUP_INJECT)
    return content

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        original = f.read()

    content = original

    # Apply SliverPadding → ResponsiveSliverPadding substitutions
    content = replace_sliver_padding(content)
    content = replace_sliver_symmetric(content)

    # Wrap body for forms/list screens (but not camera/attendance screens)
    filename = os.path.basename(path)
    skip_body_wrap = [
        'take_attendance', 'dashboard', 'login', 'map_picker',
        'liveness', 'tracker'
    ]
    if not any(s in filename for s in skip_body_wrap):
        content = wrap_scaffold_body(content, filename)

    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  [UPDATED] {os.path.relpath(path, BASE)}")
    else:
        print(f"  [SKIP]    {os.path.relpath(path, BASE)}")

def main():
    print("=== Applying Responsive Wrappers ===\n")
    dart_files = []
    for root, dirs, files in os.walk(SCREENS):
        for fn in files:
            if fn.endswith('.dart'):
                dart_files.append(os.path.join(root, fn))

    # Also include user_profile_screen.dart
    extra = os.path.join(BASE, 'lib', 'screens', 'user_profile_screen.dart')
    if os.path.exists(extra) and extra not in dart_files:
        dart_files.append(extra)

    for path in sorted(dart_files):
        process_file(path)

    # ── Special: inject Windows popup into supervisor take_attendance ──
    print("\n=== Injecting Windows popup into Supervisor check-in ===")
    if os.path.exists(SUP_CHECKIN_FILE):
        with open(SUP_CHECKIN_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
        updated = inject_windows_popup_supervisor(content)
        if updated != content:
            with open(SUP_CHECKIN_FILE, 'w', encoding='utf-8') as f:
                f.write(updated)
            print(f"  [UPDATED] supervisor/take_attendance_screen.dart")
        else:
            print(f"  [SKIP] supervisor/take_attendance_screen.dart (already patched or pattern not found)")

    print("\nDone!")

if __name__ == '__main__':
    main()

import subprocess
import re

def run_analyze():
    print("Running dart analyze...")
    result = subprocess.run(["dart", "analyze"], capture_output=True, text=True, shell=True)
    return result.stdout

def fix_errors(output):
    # Regex to match dart analyze output lines like:
    #   error - Invalid constant value - lib\screens\admin\admin_dashboard_screen.dart:123:5 - invalid_constant
    # or
    #   error • Invalid constant value • lib\screens\admin\admin_dashboard_screen.dart:123:5 • invalid_constant
    # or
    #   lib/screens/admin/map_picker_screen.dart:187:54: Error: Not a constant expression.
    
    fixes_made = 0
    lines = output.split('\n')
    
    files_to_fix = {}
    
    # Try to catch multiple formats
    for line in lines:
        if "error " in line.lower() or "Error:" in line:
            # try to extract filepath and line number
            # Format 1: file.dart:line:col
            m1 = re.search(r'([a-zA-Z0-9_/\\]+\.dart):(\d+):(\d+)', line)
            if m1:
                filepath = m1.group(1).strip()
                line_num = int(m1.group(2))
                
                # Check if it's a const-related error
                if any(x in line.lower() for x in ['const', 'constant']):
                    if filepath not in files_to_fix:
                        files_to_fix[filepath] = set()
                    files_to_fix[filepath].add(line_num)
                    
    for filepath, line_nums in files_to_fix.items():
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                file_lines = f.readlines()
            
            made_change = False
            for ln in line_nums:
                idx = ln - 1
                # we search upwards up to 10 lines for the closest 'const ' 
                for offset in range(10):
                    search_idx = idx - offset
                    if 0 <= search_idx < len(file_lines):
                        original_line = file_lines[search_idx]
                        if 'const ' in original_line:
                            new_line = re.sub(r'\bconst\s+', '', original_line)
                            file_lines[search_idx] = new_line
                            made_change = True
                            fixes_made += 1
                            break

            if made_change:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.writelines(file_lines)
                print(f"Fixed {filepath}")
        except Exception as e:
            print(f"Error reading {filepath}: {e}")
            
    return fixes_made

def main():
    max_iterations = 10
    for i in range(max_iterations):
        print(f"Iteration {i+1}")
        output = run_analyze()
        fixes = fix_errors(output)
        if fixes == 0:
            print("No more const errors to fix automatically.")
            break
        print(f"Made {fixes} fixes.")

if __name__ == "__main__":
    main()

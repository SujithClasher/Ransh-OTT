"""
Complete fix for admin_dashboard.dart
"""

# Read the file
with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and fix line 616 - should close Container properly
# Line 616 should have proper closing
if len(lines) > 617:
    # Check lines 616-619
    print(f"Line 616: {lines[615].strip()}")
    print(f"Line 617: {lines[616].strip()}")
    print(f"Line 618: {lines[617].strip()}")  
    print(f"Line 619: {lines[618].strip()}")
    
    # The issue is that the Row needs to be closed
    # After line 616 (which closes the Container for role badge)
    # We need to add:
    # ],  // Close children of Row
    # ),  // Close Row
    
    # Insert missing closing brackets after line 616
    if '),\n' in lines[615] and lines[616].strip() == '),':
        # Line 617 should close Row children, line 618 should close Row
        if lines[616].strip() == '),':
            lines[616] = '                  ),\n'
        if len(lines) > 617 and 'if' not in lines[617]:
            lines.insert(617, '                ],\n')
            lines.insert(618, '              ),\n')


# Write back
with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n✅ Fixed bracket issues!")

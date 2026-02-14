"""
Script to fix admin_dashboard.dart syntax errors
Run this with: python fix_admin_dashboard.py
"""

import re

# Read the file
with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Change ..[  to ...[
content = content.replace('if (subscriptionExpiry != null) ..[', 'if (subscriptionExpiry != null) ...[')

# Fix 2: Add _getPlanColor method before the closing brace of _UsersTab
# Find the position to insert (before the last closing brace of _UsersTab class)
helper_method = '''
  Color _getPlanColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'basic':
        return const Color(0xFF2196F3);
      case 'standard':
        return const Color(0xFF9C27B0);
      case 'premium':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
'''

# Insert before the last '}' of the _UsersTab class
# Find the _formatDate method and add after it
if '_formatDate' in content and not '_getPlanColor' in content:
    # Find the position after _formatDate method closing brace
    pattern = r'(  String _formatDate\(DateTime date\) \{\s+return[^}]+\}\s+)(\})'
    replacement = r'\1' + helper_method + r'\2'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# Write back
with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Fixed admin_dashboard.dart!")
print("1. Changed ..[ to ...[")  
print("2. Added _getPlanColor method")

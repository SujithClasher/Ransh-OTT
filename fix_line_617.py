# Simple fix - just add the missing closing brackets
with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Lines 616-619 currently are:
# 616: ),
# 617: ),  
# 618: ),
# 619: );

# Should be:
# 616: ),       // Close role badge Container
# 617: ],       // Close Row children
# 618: ),       // Close Row  
# 619: ),       // Close ListTile trailing
# 620: ),       // Close ListTile
# 621: );       // Close Card

# Fix line 617 - change second ), to ],
if len(lines) > 616:
    lines[616] = '                  ],\n'  # Change ), to ],

with open(r'c:\Client Projects\Ransh-OTT\lib\screens\admin\admin_dashboard.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Done! Changed line 617 from ), to ],")

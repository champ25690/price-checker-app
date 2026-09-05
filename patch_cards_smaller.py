import re

file_path = '/root/price_checker_new_zip/lib/screens/product_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace padding
content = content.replace("padding: const EdgeInsets.all(16),", "padding: const EdgeInsets.all(12),")
content = content.replace("padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),", "padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),")

# Replace title font sizes
content = content.replace("fontSize: 16)", "fontSize: 13)")

# Replace main price font sizes
content = content.replace("fontSize: 26,", "fontSize: 22,")

# Replace promo title font size
content = content.replace("fontSize: 20,", "fontSize: 16,")

# Replace savings/details font sizes
content = content.replace("fontSize: 14)", "fontSize: 12)")

# Replace unit font size
content = content.replace("fontSize: 15,", "fontSize: 13,")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched product_detail_screen.dart successfully.")

import os
import zipfile
import tempfile
import shutil
import time

def process_zip(file_path):
    temp_fd, temp_path = tempfile.mkstemp(suffix='.zip')
    os.close(temp_fd)
    
    modified = False
    try:
        with zipfile.ZipFile(file_path, 'r') as zin:
            with zipfile.ZipFile(temp_path, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    if item.date_time[0] < 1980:
                        item.date_time = (2026, 1, 1, 0, 0, 0)
                        modified = True
                    # Keep original data
                    zout.writestr(item, zin.read(item.filename))
        
        if modified:
            print(f"Fixed timestamps in {file_path}")
            shutil.move(temp_path, file_path)
        else:
            os.remove(temp_path)
            
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        try:
            os.remove(temp_path)
        except: pass

gradle_cache = os.path.join(os.environ.get('USERPROFILE'), ".gradle", "caches")

for root, dirs, files in os.walk(gradle_cache):
    for f in files:
        if f.endswith('.jar') or f.endswith('.aar'):
            process_zip(os.path.join(root, f))

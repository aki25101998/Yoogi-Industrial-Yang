import io
import re
import json

def extract_comments():
    old_file = "d:/Project/yoogi yin yang/Include/Input.mqh"
    comments = {}
    
    # Let's try reading as utf-8, if fails, fallback to utf-16
    try:
        with io.open(old_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except UnicodeDecodeError:
        with io.open(old_file, 'r', encoding='utf-16') as f:
            lines = f.readlines()
            
    for line in lines:
        match = re.search(r'(input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;\s*//\s*(.*)', line)
        if match:
            var_name = match.group(2)
            comment = match.group(3).strip()
            comments[var_name] = comment

    with io.open("d:/Project/yoogi yin yang/old_comments_map.json", "w", encoding="utf-8") as f:
        json.dump(comments, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    extract_comments()

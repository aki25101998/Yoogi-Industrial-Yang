import io
import re
import json

def apply_comments():
    new_file = "d:/Project/yoogi yin yang/Include/Input.mqh"
    with io.open("d:/Project/yoogi yin yang/old_comments_map.json", "r", encoding="utf-8") as f:
        comments = json.load(f)
        
    try:
        with io.open(new_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except UnicodeDecodeError:
        with io.open(new_file, 'r', encoding='utf-16') as f:
            lines = f.readlines()
            
    updated_lines = []
    for line in lines:
        match = re.search(r'^(\s*(?:input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;)(.*)$', line)
        if match:
            prefix = match.group(1)
            var_name = match.group(2)
            if var_name in comments:
                padded_prefix = prefix.ljust(55)
                # handle translation for pending mode additions
                if var_name == "inp_enable_pending_mode":
                    updated_lines.append(f"{padded_prefix} // Bật Chế Độ Pending Order (Chống Trượt Giá)\n")
                else:
                    updated_lines.append(f"{padded_prefix} // {comments[var_name]}\n")
            else:
                updated_lines.append(line)
        else:
            updated_lines.append(line)
            
    with io.open(new_file, 'w', encoding='utf-8') as f:
        f.writelines(updated_lines)

if __name__ == "__main__":
    apply_comments()

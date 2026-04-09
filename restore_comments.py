import io
import re

def restore_comments():
    old_file = "d:/Project/yoogi yin yang/Input_old.mqh"
    new_file = "d:/Project/yoogi yin yang/Include/Input.mqh"
    
    with io.open(old_file, 'r', encoding='utf-16') as f:
        old_lines = f.readlines()
        
    with io.open(new_file, 'r', encoding='utf-8') as f:
        new_lines = f.readlines()
        
    # extract var -> comment mapping from old file
    comments = {}
    for line in old_lines:
        match = re.search(r'(input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;\s*//\s*(.*)', line)
        if match:
            var_name = match.group(2)
            comment = match.group(3).strip()
            comments[var_name] = comment
            
    # apply to new file
    updated_lines = []
    for line in new_lines:
        match = re.search(r'((input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;)(.*)', line)
        if match:
            prefix = match.group(1)
            var_name = match.group(3)
            if var_name in comments:
                # restore old comment! Reformat it beautifully.
                # pad so that // aligns nicely
                padded_prefix = prefix.ljust(55)
                updated_lines.append(f"{padded_prefix} // {comments[var_name]}\n")
            else:
                updated_lines.append(line)
        else:
            updated_lines.append(line)
            
    with io.open(new_file, 'w', encoding='utf-8') as f:
        f.writelines(updated_lines)
        
if __name__ == "__main__":
    restore_comments()

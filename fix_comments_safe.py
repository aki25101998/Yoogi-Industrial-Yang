import subprocess
import re
import io

def fix_comments():
    # 1. Get original file directly from git via python byte pipe
    result = subprocess.run(["git", "show", "a1352f8:Include/Input.mqh"], capture_output=True)
    raw_bytes = result.stdout
    
    # Try decoding
    try:
        old_content = raw_bytes.decode('utf-16le')
    except:
        old_content = raw_bytes.decode('utf-8')
        
    old_lines = old_content.split('\n')
    
    comments = {}
    for line in old_lines:
        match = re.search(r'^(?:input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;\s*//\s*(.*)$', line.strip())
        if match:
            comments[match.group(1)] = match.group(2).strip()

    # Add missing ones manually if necessary
    comments['inp_enable_pending_mode'] = "[ON/OFF] Bật Chế Độ Pending Orders (Chống Trượt MẠNH)"
    comments['inp_pending_order_count'] = "Số lượng lệnh Stop/Limit đặt trước mỗi biên"
    comments['inp_pending_refill_threshold'] = "Số lệnh tối thiểu trước khi tự động nhồi thêm"
    comments['inp_pending_auto_refill'] = "Tự động kích hoạt nhồi lệnh mồi khi lưới sắp hết"
    
    # 2. Get HEAD file (the one with the new massive group structure)
    result = subprocess.run(["git", "show", "HEAD:Include/Input.mqh"], capture_output=True)
    head_bytes = result.stdout
    
    try:
        head_content = head_bytes.decode('utf-8')
    except:
        head_content = head_bytes.decode('utf-16le')
        
    head_lines = [line.replace('\r', '') for line in head_content.split('\n')]
    
    updated_lines = []
    for line in head_lines:
        match = re.search(r'^(\s*(?:input|sinput)\s+[\w]+\s+([\w_]+)\s*=\s*[^;]+;)(.*)$', line)
        if match:
            prefix = match.group(1)
            var = match.group(2)
            if var in comments:
                # pad length to 60 for alignment
                pad_prefix = prefix.ljust(60)
                updated_lines.append(f"{pad_prefix}// {comments[var]}")
            else:
                updated_lines.append(line)
        else:
            updated_lines.append(line)
            
    # Write directly to Input.mqh in original format
    with open("d:/Project/yoogi yin yang/Include/Input.mqh", "w", encoding="utf-16le") as f:
        f.write("\n".join(updated_lines))

if __name__ == '__main__':
    fix_comments()

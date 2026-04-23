import re

with open('Include/Trimming.mqh', 'r', encoding='utf-8') as f:
    content = f.read()

helper = '''//+------------------------------------------------------------------+
//| Helper to trim partial and replace gap with Limit order          |
//+------------------------------------------------------------------+
bool MyPositionClosePartial(ulong ticket, double volume)
{
    // Partial close logic wrapper
    return trade.PositionClosePartial(ticket, volume);
}
'''

if 'MyPositionClosePartial' not in content:
    content = re.sub(r'(bool MyPositionClose\(ulong ticket\))', helper + '\n' + r'\1', content)

content = re.sub(r'trade\.PositionClosePartial\(([a-zA-Z0-9_\[\]\.\>]+),\s*([a-zA-Z0-9_]+)\)', r'MyPositionClosePartial(\1, \2)', content)

with open('Include/Trimming.mqh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated Trimming.mqh with MyPositionClosePartial successfully.")

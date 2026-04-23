import re

with open('Include/Trimming.mqh', 'r', encoding='utf-8') as f:
    content = f.read()

helper = '''//+------------------------------------------------------------------+
//| Wrapper for PositionClose to support Limit Replacements          |
//+------------------------------------------------------------------+
bool MyPositionClose(ulong ticket)
{
    double open_price = 0;
    ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
    bool valid = false;
    
    if(PositionSelectByTicket(ticket))
    {
        open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        valid = true;
    }
    
    if(trade.PositionClose(ticket))
    {
        if(valid && inp_enable_pending_mode)
        {
            PlaceReplacementLimitOrder(type, open_price);
        }
        return true;
    }
    return false;
}

bool MyPositionClosePartial(ulong ticket, double volume)
{
    return trade.PositionClosePartial(ticket, volume);
}
'''

# Inject helper right after #include "PendingOrders.mqh" (which is in Yoogi Yin Yang.mq5, not Trimming.mqh)
# So we inject at the top of Trimming.mqh!
if 'MyPositionClose' not in content:
    content = helper + "\n" + content

# Replace references
# We must be careful not to match MyPositionClose with the regex!
content = re.sub(r'(?<!My)trade\.PositionClose\(([a-zA-Z0-9_\[\]\.\>]+)\)', r'MyPositionClose(\1)', content)
content = re.sub(r'(?<!My)trade\.PositionClosePartial\(([a-zA-Z0-9_\[\]\.\>]+),\s*([a-zA-Z0-9_]+)\)', r'MyPositionClosePartial(\1, \2)', content)

with open('Include/Trimming.mqh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated Trimming.mqh carefully.")

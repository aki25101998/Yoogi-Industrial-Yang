import re

with open('Include/Trimming.mqh', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern specifically matching 	rade.PositionClose(TICKET)
# We want to replace it with a block that captures the position info first.
# Wait, replacing it with a helper function is easier:
# MyPositionClose(TICKET)

helper = '''//+------------------------------------------------------------------+
//| Helper to trim and replace gap with Limit order                  |
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
'''

if 'MyPositionClose' not in content:
    # insert helper at the top after includes
    content = re.sub(r'(#include "PendingOrders\.mqh"\s*)', r'\1\n' + helper + '\n', content)

# Now replace trade.PositionClose(ticket) with MyPositionClose(ticket)
content = re.sub(r'trade\.PositionClose\((?!Partial)([a-zA-Z0-9_\[\]\.\>]+)\)', r'MyPositionClose(\1)', content)

with open('Include/Trimming.mqh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated Trimming.mqh successfully.")

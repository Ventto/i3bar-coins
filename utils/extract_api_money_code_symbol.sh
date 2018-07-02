#!/bin/sh
req=$(curl https://free.currencyconverterapi.com/api/v5/currencies | \
      python -m json.tool)

echo "$req" | grep '"id":' | sed -n 's|.*id": "\(.*\)"|\1|p' > money_codes

symbols=$(echo "$req" | grep '"id":' -B1 | grep '"currency[SN]' | \
    sed -e 's/.*Name.*//;s/.*Symbol": "\(.*\)".*/\1/')

printf "$symbols" >  money_symbols

paste money_codes money_symbols > money_data
rm -rf money_codes money_symbols

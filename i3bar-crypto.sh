#!/bin/sh

request_money_exchange()
{
    [ "$#" -ne 1 ] && return 2

    req=$(curl -s "http://free.currencyconverterapi.com/api/v5/convert?q=USD_${1}&compact=y")

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        return 1
    fi

    val=$(echo "$req" | sed -n 's%.*val":\([0-9]\+\.[0-9]\+\)}}%\1%p')

    if ! echo "$val" | grep -E '^[0-9]+\.[0-9]+$' >/dev/null 2>&1; then
        return 1
    fi

    echo "$val"
}

get_money_exchange()
{
    [ "$#" -ne 1 ] && return 2

    money="$1"

    if [ -r "/tmp/USD_${money}" ]; then
        cat "/tmp/USD_${money}"
    else
        exchange=$(request_money_exchange "$money")

        # shellcheck disable=SC2181
        if [ "$?" -eq 0 ]; then
            echo "$exchange" > "/tmp/USD_${money}"
            echo "$exchange"
            return
        fi

        echo "undefine"
    fi
}

moneycode2symbol() {
    money_code="$1"

    symbols_file="/usr/share/i3bar-crypto/data/money_symbols"

    if [ ! -r "$symbols_file" ]; then
        echo '?'
        return
    fi

    symbol=$(grep -E "^${money_code}" "$symbols_file")

    if [ -z "$symbol" ]; then
        echo '?'
        return
    fi

    echo "$symbol" | awk '{print $2}'
}

print_crypto_change()
{
    change="$1"

    if echo "$1" | grep -E '^-' >/dev/null 2>&1; then
        change=$(echo "$change" | sed -e 's/-//')
        change_out=''
        color='#FF0000'
    else
        change_out=''
        color='#00FF00'
    fi

    printf '\t{ "full_text": "%s", "color": "%s" },\n' \
           "${change_out} ${change}%" "$color"
}

change_period_to_api() {
    case $1 in
        hour) echo "1h";;
        day) echo "24h";;
        week) echo "7d";;
        *) echo "24h";;
    esac
}

err() {
    msg="$1"

    printf '{ "full_text": " - [%s]", "color": "#FF0000" },' "$msg"
}

i3bar_crypto()
{
    crypto_name="$1"
    money_code="$2"
    change_period="$3"
    printSymbol="$4"

    idlist_file="/usr/share/i3bar-crypto/data/api_crypto_ids"

    if [ ! -r "$idlist_file" ]; then
        err 'error'
        return 1
    fi

    id=$(grep -E "^${crypto_name} " "$idlist_file" | awk '{print $2}')

    req=$(curl -s "https://api.coinmarketcap.com/v2/ticker/${id}/")

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        err 'bad-request'
        return 2
    fi

    if [ "$money_code" = "USD" ]; then
        exchange=1
    else
        exchange=$(get_money_exchange "$money_code")
    fi

    if [ "$exchange" = "undefine" ]; then
        printf '%s ? ' "$crypto_name"
    else
        price=$(echo "$req" | sed -n 's%.*price": \(-\?[0-9]\+\.[0-9]\+\),.*%\1%p')
        price=$(echo "${price}*${exchange}" | bc -l)

        money_symbol=''
        if $printSymbol; then
            money_symbol=$(moneycode2symbol "$money_code")

            if [ -z "$money_symbol" ]; then
                money_symbol="$money_code"
            fi
        fi

        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ]; then
            err 'money-symbol-error'
            return 1
        fi

        printf '\t{ "full_text": "%s %.2f%s",' "$crypto_name" "$price" \
               "$money_symbol"
        echo '"separator_block_width": 14 },'

        change=$(echo "$req" | \
                 sed -n "s%.*change_${change_period}\": \\(-\\?[0-9]\\+\\.[0-9]\\+\\).*%\\1%p")

        print_crypto_change "$change"
    fi
}

usage() {
    echo 'Usage: i3bar-crypto [-p MONEY_CODE] [-c day] CURRENCY,...

Print crypto-currencies information in i3bar-JSON format.

Argument:
  CURRENCY
        a crypto CURRENCY acronym.

Options:
  -c, --change PERIOD
        set the change on a PERIOD hour, day or week (default: day)
  -p, --price MONEY_CODE
        print the price of the crypto-currencies in official
        money by giving its code (default: USD)
  -s, --symbol
        print the money symbol. It may not work with some moneys.

Example:
  $ i3bar-crypto --price EUR --change day BTC,ETH

See Also:
List all money codes: https://free.currencyconverterapi.com/api/v5/currencies
  '
}

version() {
    echo 'version...'
}

main()
{
    # getopts does not support long options. We convert them to short one.
    for arg in "$@"; do
        shift
        case "$arg" in
            --change) set -- "$@" '-c' ;;
            --price) set -- "$@" '-p' ;;
            *)       set -- "$@" "$arg"
        esac
    done

    change_period='day'
    money='USD'
    sFlag=false

    OPTIND=1
    while getopts 'hvsc:p:' opt; do
        case $opt in
            c)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                change_period="$OPTARG"
                ;;
            p)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                money="$OPTARG"
                ;;
            s) sFlag=true;;
            h)  usage   ; exit;;
            v)  version ; exit;;
            \?) usage; exit 2;;
            :)  usage; exit 2;;
        esac
    done

    shift $((OPTIND-1))

    if [ "$#" -ne 1 ]; then
        return 2
    fi

    currencies="$1"; shift
    change_period=$(change_period_to_api "$change_period")

    IFS=","
    for currency in $currencies; do
        i3bar_crypto "$currency" "$money" "$change_period" "$sFlag"
    done
}

main "$@"

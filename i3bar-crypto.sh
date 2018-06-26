#!/bin/sh

req_money_exchange()
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
        exchange=$(req_money_exchange "$money")

        # shellcheck disable=SC2181
        if [ "$?" -eq 0 ]; then
            echo "$exchange" > "/tmp/USD_${money}"
            echo "$exchange"
            return
        fi

        echo "undefine"
    fi
}

print_money_symbol() {
    case $1 in
        EUR) echo €;;
        USD) echo $;;
    esac
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

i3bar_crypto()
{
    crypto_name="$1"
    money_name="$2"
    change_period="$3"

    data=$(curl -s "https://api.coinmarketcap.com/v1/ticker/${crypto_name}/")

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        printf '{ "full_text": " - [error]", "color": "#FF0000" },'
        return 2
    fi

    if echo "$data" | grep 'id not found' >/dev/null 2>&1; then
        printf '{ "full_text": " - [unknown]", "color": "#FF0000" },'
        return 3
    fi

    symbol=$(echo "$data" | sed -n 's%.*symbol": "\(.*\)".*%\1%p')

    if ! echo "$symbol" | grep -E '[A-Z]{3}' >/dev/null 2>&1; then
        printf '{ "full_text": " - [error]", "color": "#FF0000" },'
        return 4
    fi

    if [ "$money_name" = "USD" ]; then
        exchange=1
    else
        exchange=$(get_money_exchange "$money_name")
    fi

    if [ "$exchange" = "undefine" ]; then
        printf '%s ? ' "$symbol"
    else
        price=$(echo "$data" | sed -n 's%.*price_usd": "\(.*\)".*%\1%p')
        price=$(echo "${price}*${exchange}" | bc -l)

        printf '\t{ "full_text": "%s %.2f%s",' "$symbol" "$price" \
               "$(print_money_symbol "$money_name")"
        echo '"separator_block_width": 14 },'

        change=$(echo "$data" | \
            sed -n "s%.*change_${change_period}\": \"\\(.*\\)\".*%\\1%p")
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

    OPTIND=1
    while getopts 'hvc:p:' opt; do
        case $opt in
            c)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                change_period="$OPTARG"
                ;;
            p)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                money="$OPTARG"
                ;;
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
        i3bar_crypto "$currency" "$money" "$change_period"
    done
}

main "$@"

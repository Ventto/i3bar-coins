#!/bin/sh

coinbase_get_currency_price() {
    currency_code="$1"

    curr_date="$(date +'%Y-%m-%d')"

    req=$(curl -s -H "CB-VERSION: ${curr_date}" \
               "https://api.coinbase.com/v2/prices/${currency_code}-USD/spot")

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        echo "curl-error"
        return 1
    fi

    error="$(echo "$req" | \
             sed -n 's|.*errors":\[{"id":"\(.*\)","message".*|\1|p')"

    if [ -n "$error" ]; then
        echo "coinbase:$error"
        return 1
    fi

    price="$(echo "$req" | sed -n 's|.*amount":"\([0-9]\+\.[0-9]\+\)".*|\1|p')"

    if [ -n "$price" ]; then
        echo "$price"
        return 0
    fi

    echo "unknown-error"
    return 1
}

is_valid_platform() {
    case $1 in
        coinbase) return 0;;
        *) return 1;;
    esac
}

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

change_period_to_api() {
    case $1 in
        hour) echo "1h";;
        day) echo "24h";;
        week) echo "7d";;
        *) echo "24h";;
    esac
}

print_err() {
    msg="$1"

    printf '{ "full_text": " - [%s]", "color": "#FF0000" },' "$msg"
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

print_crypto_data()
{
    crypto_name="$1"
    money_code="$2"
    change_period="$3"
    printSymbol="$4"
    platform="$5"

    idlist_file="/usr/share/i3bar-crypto/data/api_crypto_ids"

    if [ ! -r "$idlist_file" ]; then
        print_err 'error'
        return 1
    fi

    id=$(grep -E "^${crypto_name} " "$idlist_file" | awk '{print $2}')

    req=$(curl -s "https://api.coinmarketcap.com/v2/ticker/${id}/")

    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
        print_err 'curl-error'
        return 2
    fi

    change=$(echo "$req" | \
             sed -n "s%.*change_${change_period}\": \\(-\\?[0-9]\\+\\.[0-9]\\+\\).*%\\1%p")

    exchange=1
    if [ "$money_code" != "USD" ]; then
        exchange=$(get_money_exchange "$money_code")
        if [ "$exchange" = "undefine" ]; then
            print_err 'undefined-exchange'
            return 1
        fi
    fi

    if [ "$platform" = "none" ]; then
        price=$(echo "$req" | sed -n 's%.*price": \(-\?[0-9]\+\.[0-9]\+\),.*%\1%p')
    else
        out="$(eval "${platform}_get_currency_price '${crypto_name}'")"

        if [ "$?" -ne 0 ]; then
            print_err "$out"
            return 1
        fi
        price="$out"
    fi
    price=$(echo "${price}*${exchange}" | bc -l)

    money_symbol=''
    if $printSymbol; then
        money_symbol=$(moneycode2symbol "$money_code")
        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ]; then
            print_err 'money-symbol-error'
            return 1
        fi
    fi

    printf '\t{ "full_text": "%s %.2f%s",' "$crypto_name" "$price" \
           "$money_symbol"
    echo '"separator_block_width": 14 },'

    print_crypto_change "$change"
}

usage() {
    echo 'Usage: i3bar-crypto [-p MONEY_CODE] [-c day] CURRENCY,...

Print crypto-currencies information in i3bar-JSON format.

Argument:
  CURRENCY
        a crypto CURRENCY acronym.

Options:
  -c, --change PERIOD
        set the change on a PERIOD hour, day or week (default: day).
  -m, --money CODE
        print the price of a given crypto-currency in official
        money by giving its CODE (default: USD).
  -s, --symbol
        print the money symbol. It may not work with some moneys.
  -p, --platform NAME
        name of the digital currency platform (ex: coinbase).

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
    # getopts does not support long options, so we convert them to short one.
    for arg in "$@"; do
        shift
        case "$arg" in
            --change) set -- "$@" '-c' ;;
            --money) set -- "$@" '-m' ;;
            --platform) set -- "$@" '-p' ;;
            *) set -- "$@" "$arg"
        esac
    done

    change_period='day'
    money_code='USD'
    platform='none'
    sFlag=false

    OPTIND=1
    while getopts 'hvsc:m:p:' opt; do
        case $opt in
            c)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                change_period="$OPTARG"
                ;;
            m)
                [ -z "$OPTARG" ] && { usage; exit 2; }
                money_code="$OPTARG"
                ;;
            p)
                [ -z "$OPTARG" ] && { usage; exit 2; }

                platform="$OPTARG"

                if ! is_valid_platform "$platform"; then
                    print_err 'unknown-platform'
                    exit 2
                fi
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
        print_crypto_data "$currency" "$money_code" "$change_period" "$sFlag" \
                          "$platform"
    done
}

main "$@"

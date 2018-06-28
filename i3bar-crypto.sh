#!/bin/sh
#
# The MIT License (MIT)
#
# Copyright (c) 2018-2019 Thomas "Ventto" Venriès <thomas.venries@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
usage() {
    echo 'Usage: i3bar-crypto [-m CODE] [-p PLATFORM] [-c day] CURRENCY,...

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
  -p, --platform PLATFORM
        name of the digital currency PLATFORM (ex: coinbase).

Example:
  $ i3bar-crypto --money EUR --change day BTC,ETH
  $ i3bar-crypto -s --platform coinbase BTC

See Also:
  * List all money codes:
  $ curl -s "https://free.currencyconverterapi.com/api/v5/currencies" | \
    python -m json.tool

  * List all crypto-currencies code:
  $ curl -s "https://api.coinmarketcap.com/v2/listings/" | python -m json.tool
    '
}

version() {
    echo 'i3bar-crypto 0.1
Copyright (C) 2018 Thomas "Ventto" Venries.

License MIT: <https://opensource.org/licenses/MIT>.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
'
}
coinbase_get_coin_price() {
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

moneycode_to_symbol() {
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

coincode_to_id() {
    coin_code="$1"

    coin_id_file="/usr/share/i3bar-crypto/data/api_crypto_ids"

    if [ ! -r "$coin_id_file" ]; then
        echo 'error'
        return 1
    fi

    coin_id=$(grep -E "^${coin_code} " "$coin_id_file" | \
                awk '{print $2}')

    if [ -z "$coin_id" ]; then
        echo 'unknown-currency'
        return 1
    fi

    echo "$coin_id"
}

is_connected() {
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

is_valid_platform() {
    case $1 in
        coinbase) return 0;;
        *) return 1;;
    esac
}

print_err() {
    printf '{ "full_text": " - [%s]", "color": "#FF0000" },' "$1"
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
    id="$6"

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
        out="$(eval "${platform}_get_coin_price '${crypto_name}'")"

        if [ "$?" -ne 0 ]; then
            print_err "$out"
            return 1
        fi
        price="$out"
    fi
    price=$(echo "${price}*${exchange}" | bc -l)

    money_symbol=''
    if $printSymbol; then
        money_symbol=$(moneycode_to_symbol "$money_code")
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

main()
{
    # getopts does not support long options, so we convert them to short one.
    for arg in "$@"; do
        shift
        case "$arg" in
            --change)   set -- "$@" '-c' ;;
            --money)    set -- "$@" '-m' ;;
            --platform) set -- "$@" '-p' ;;
            --symbol)   set -- "$@" '-s' ;;
            *)          set -- "$@" "$arg"
        esac
    done

    change_period='day'
    money_code='USD'
    platform='none'
    sFlag=false

    OPTIND=1
    while getopts 'hvsc:m:p:' opt 2>/dev/null; do
        case $opt in
            c)
                [ -z "$OPTARG" ] && { print_err "bad_args"; exit 2; }
                change_period="$OPTARG"
                ;;
            m)
                [ -z "$OPTARG" ] && { print_err "bad_args"; exit 2; }
                money_code="$OPTARG"
                ;;
            p)
                [ -z "$OPTARG" ] && { print_err "bad_args"; exit 2; }

                platform="$OPTARG"

                if ! is_valid_platform "$platform"; then
                    print_err 'unknown-platform'
                    exit 2
                fi
                ;;
            s) sFlag=true;;
            h)  usage   ; exit;;
            v)  version ; exit;;
            \?) print_err "bad-args"; exit 2;;
            :)  print_err "bad-args"; exit 2;;
        esac
    done

    shift $((OPTIND-1))

    if [ "$#" -ne 1 ]; then
        print_err "bad-args"
        exit 2
    fi

    currencies="$1"; shift

    if ! echo "$currencies" | \
       grep -E '^[A-Z]{3}(,[A-Z]{3})*$' >/dev/null 2>&1; then
        print_err "bad-args"
        exit 2
    fi

    change_period=$(change_period_to_api "$change_period")

    if ! is_connected; then
        print_err 'no-connection'
        exit 1
    fi

    IFS=","
    for currency_code in $currencies; do
        out="$(coincode_to_id "$currency_code")"

        [ "$?" -ne 0 ] && { print_err "$out"; continue; }

        crypto_id="$out"

        print_crypto_data "$currency_code" \
                          "$money_code" \
                          "$change_period" \
                          "$sFlag" \
                          "$platform" \
                          "$crypto_id"
    done
}

main "$@"

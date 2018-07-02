i3bar-crypto
============

*"Print crypto-currencies information in i3bar-JSON format"*

![Screenshot of i3](img/screenshot_monitor.png)

# Installation

## Dependencies

```
$ pacman -S i3-wm i3status conky otf-font-awesome   (or)
$ apt-get install i3status
```

## Manual

```
$ git clone --recursive https://github.com/Ventto/i3bar-crypto.git
$ cd i3bar-crypto
$ sudo make install
```

# Usage

## Help

```
Usage: i3bar-crypto [-m CODE] [-p PLATFORM] [-c day] CURRENCY,...

Argument:
  CURRENCY
        a crypto-CURRENCY code (ex: BTC).

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
```

## Examples

```bash
$ i3bar-crypto --money EUR --change day BTC,ETH
```

```bash
$ i3bar-crypto -s --platform coinbase BTC
```

## See Also

* List all money codes:

```bash
$ curl -s "https://free.currencyconverterapi.com/api/v5/currencies" | \
  python -m json.tool
```

* List all crypto-currencies code:

```bash
$ curl -s "https://api.coinmarketcap.com/v2/listings/" | python -m json.tool
```

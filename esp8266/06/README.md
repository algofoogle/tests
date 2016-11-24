# `esp8266/06` test

I will attempt to make this test do a few things:

1.  Use proper initialisation callbacks, WDT, etc.
2.  Connect to a WIFI AP.
3.  Periodically send UDP packets to a known host.

**NOTE:** In these examples I use UDP port 12344.

**NOTE:** This isn't finished yet!

## Progress/findings

*   See: <http://blog.mark-stevens.co.uk/2015/06/udp-on-the-esp01-esp8266-development-board/>
*   Also: <http://smallbits.marshall-tribe.net/blog/2016/05/21/esp8266-networking-basics#udp---user-datagram-protocol>
    *   Hence: <https://github.com/itmarshall/esp8266-projects/tree/master/net-blink>

## A UDP listener for testing.

In order to test that this firmware is correctly sending out packets,
I will need a host to which I can send those packets and verify
that they're being received.

I've looked at using [Netcat](https://en.wikipedia.org/wiki/Netcat)
(`nc`) for this, but it tries to behave like a connection-based
listener, rather than just a general listener.

So, there are at least two solutions for a UDP listener that can
receive and display packets from any host at any time:

### 1. `socat`

[`socat`](http://www.dest-unreach.org/socat/) is like a superior
implementation of Netcat which can be installed, say, on Ubuntu:

    sudo apt-get install socat

...or on macOS:

    brew install socat

Once installed, it can be asked to listen for UDP packets on a
given port, and display them:

    socat -u udp-recv:12344 -

...which can be extended to give basic packet diagnostic info:

    socat -x -u udp-recv:12344 -

...or super detailed debugging info:

    socat -d -d -d -d -x -u udp-recv:12344 -


### 2. A perl-based script

See [`udp.pl`](udp.pl) which came from
[John Graham-Cumming's blog](http://blog.jgc.org/2012/12/listen-on-udp-port-and-dump-received.html).

It works on Linux and macOS.

Run it like this:

    ./udp.pl 12344


## Sending a UDP packet under your Unix

On both Linux and macOS, you have this handy helper to send UDP
packets:

    echo -n 'my packet with no newline' > /dev/udp/127.0.0.1/12344

...so you can test your [listener](#a-udp-listener-for-testing).

## Other general UDP examples

For more about UDP client/server examples, see:
[Programming UDP sockets in C on Linux](http://www.binarytides.com/programming-udp-sockets-c-linux/).


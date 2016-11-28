# `esp8266/06` test

This example does the following:

1.  Uses proper initialisation callbacks (I think?)
2.  Connect to a WIFI AP, using a handler for WiFi events.
3.  Broadcasts a single UDP packet to the network.

**NOTE:** In these examples I use UDP port 12344.


## Resources

Some of the pages I used for information were:

*   <http://blog.mark-stevens.co.uk/2015/06/udp-on-the-esp01-esp8266-development-board/>
*   <http://smallbits.marshall-tribe.net/blog/2016/05/21/esp8266-networking-basics#udp---user-datagram-protocol>
*   <https://github.com/itmarshall/esp8266-projects/tree/master/net-blink>
*	<http://bbs.espressif.com/viewtopic.php?f=31&t=440>


## Clearing WIFI settings stored in flash

```c
  //NOTE: These lines can be used to reset wifi
  // settings in the flash, disabling auto-connect, so
  // we can get total session-level control over all that.
  os_printf("Clearing wifi settings from flash...\n");
  // Wipe wifi config from flash:
  system_restore();
  // Disable wifi auto-connect, setting it in flash:
  os_printf("Setting wifi STATION (client) mode...\n");
  wifi_set_opmode(STATION_MODE);
```


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

It works on Linux and macOS. For some reason it doesn't
work on my home Mac/network, though I have had it working
on a different Mac/network.

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


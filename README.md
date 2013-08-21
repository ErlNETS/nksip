[![Build Status](https://travis-ci.org/kalta/nksip.png)](https://travis-ci.org/kalta/nksip)

Introduction
============

NkSIP is an Erlang SIP framework or _application server_, which greatly facilitates the development of robust and scalable server-side SIP applications like proxy, registrar, redirect or outbound servers and [B2BUAs](http://en.wikipedia.org/wiki/Back-to-back_user_agent).

**This software is still alpha quality!! Do not use it in production!!**

SIP is the standard protocol related to IP voice, video and remote sessions, supported by thousands of devices, softphones and network operators. It is the basic building block for most current voice or video enabled networks and it is the core protocol of the IP Multimedia Subsytem ([IMS](https://en.wikipedia.org/wiki/IP_Multimedia_Subsystem)). SIP is powerful and flexible, but also very complex to work with. SIP basic concepts are easy to understand, but developing robust, scalable, highly available applications is usually quite hard and time consuming, because of the many details you have to take into account.

NkSIP takes care of much of the SIP complexity, while allowing full access to requests and responses. 

NkSIP allows you to run any number of **SipApps**. To start a SipApp, you define a _name_, a set of _transports_ to start listening on and a **callback module**. Currently the only way to develop NkSIP applications is using [Erlang]("http://www.erlang.org") (a new, language-independent way of developing SipApps is in the works). You can now start sending SIP requests, and when your application starts receiving requests, specific functions in the callback module will be called. Each defined callback function has a _sane_ default functionality, so you only have to implement the functions you need to customize. You don't have to deal with transports, retransmissions, authentications or dialog management. All of those aspects are managed by NkSIP in a standard way. In case you need to, you can implement the related callback functions, or even process the request by yourself using the powerful NkSIP Erlang functions.

NkSIP has a clean, written from scratch, [OTP compliant](http://www.erlang.org/doc/design_principles/users_guide.html) and [fully typed](http://www.erlang.org/doc/reference_manual/typespec.html) pure Erlang code. New RFCs and features can be implemented securely and quickly. The codebase includes currently more than 50 unit tests. If you want to customize the way NkSIP behaves beyond what the callback mechanism offers, it should be easy to understand the code and use it as a powerful base for your specific application server.

NkSIP is currently alpha quality, it probably has important bugs and is **not yet production-ready**, but it is already very robust, thanks to its OTP design. Also thanks to its Erlang roots it can perform many actions while running: starting and stopping SipApps, hot code upgrades, configuration changes and even updating your application behavior and  function callbacks on the fly.

NkSIP scales automatically using all of the available cores on the machine. Without any serious optimization done yet, and using common hardware (4-core i7 MacMini), it is easy to get more than 1.000 call cycles (INVITE-ACK-BYE) or 8.000 stateless registrations per second. On the roadmap there is a **fully distributed version**, based on [Riak Core](https://github.com/basho/riak_core), that will allow you to add and remove nodes while running, scale as much as needed and offer a very high availability, all of it without changing your application.

NkSIP is a pure SIP framework, so it _does not support any real RTP media processing_ it can't record a call, host an audio conference or transcode. These type of tasks should be done with a SIP media server, like [Freeswitch](http://www.freeswitch.org) or [Asterisk](http://www.asterisk.org). However NkSIP can act as a standard endpoint (or a B2BUA, actually), which is very useful in many scenarios: registering with an external server, answering and redirecting a call or recovering in real time from a failed media server.


Current Features
----------------


 * Full RFC3261 coverage, including SIP Registrar (RAM storage only).
 * A written from scratch, fully typed Erlang code easy to understand and extend, with more than 50 unit tests.
 * Hot core and application code upgrade.
 * Very few external dependencies: [Lager](https://github.com/basho/lager) for error logging and [Cowboy](http://ninenines.eu") as TCP/SSL acceptor and Websocket server.
 * UDP, TCP and TLS transports, capable of handling thousands of simultaneous sessions.
 * Stateful proxy servers with serial and parallel forking.
 * Stateless proxy servers, even using TCP/TLS.
 * Automatic registrations and timed pings.
 * Dialog and SDP media start and stop detection.
 * SDP processing utilities.
 * Simple STUN server (for future SIP Outbound support).
 * Robust and highly scalable, using all available processor cores.

See [FEATURES.md](docs/FEATURES.md) for up to date RFC support and the [ROADMAP.md](docs/ROADMAP.md).



Documentation
=============
Full documentation is available [here](http://kalta.github.io/nksip).

There are currently **three sample applications** included with NkSIP:
 * [Simple PBX](http://kalta.github.io/nksip/docs/v0.1.0/nksip_pbx/index.html): Registrar server and forking proxy with endpoints monitoring.
 * [LoadTest](http://kalta.github.io/nksip/docs/v0.1.0/nksip_loadtest/index.html): Heavy-load NkSIP testing. 
 * [Tutorial](docs/TUTORIAL.md): Code base for the included tutorial.



Quick Start
===========

NkSIP has been tested on OSX and Linux, using Erlang R15B y R16B

```
> git clone https://github.com/kalta/nksip
> cd nksip
> make
> make tests
```

You could also perform a heavy load test using the included application [nksip_loadtest](http://kalta.github.io/nksip/docs/v0.1.0/nksip_loadtest/index.html):
```erlang
> make loadtest
1> nksip_loadtest:full().
```

Now you can start a simple SipApp using the [client callback module](samples/nksip_tutorial/src/nksip_tutorial_sipapp_client.erl) included in the tutorial:
```erlang
> make tutorial
1> nksip:start(test1, nksip_sipapp, [], []).
2> nksip_uac:options(test1, "sip:sip2sip.info", []).
{ok, 200}
```
 
From this point you can read the [tutorial](docs/TUTORIAL.md) or start hacking with the included [nksip_pbx](http://kalta.github.io/nksip/docs/v0.1.0/nksip_pbx/index.html) application:
```erlang
> make pbx
1> nksip_pbx:start().
```

Contributing
============

Please contribute with code, bug fixes, documentation fixes, testing with SIP devices or any other form. Use 
GitHub Issues and Pull Requests, forking this repository.

Just make sure your code is dialyzer-friendly before submitting!!


<a href="http://es.linkedin.com/in/carlosjgf">
<img src="http://www.linkedin.com/img/webpromo/btn_myprofile_160x33.png" width="160" height="33" border="0" alt="View Carlos González Florido's profile on LinkedIn">
</a>

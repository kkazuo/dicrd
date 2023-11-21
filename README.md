# dircd

Dart Internet Relay Chat Daemon

## Maturity

Not for production yet, but IRC clients can connect and chat each other.

## Build

To create executable binary, run this command:

    dart compile exe bin/dircd.dart

The generated file `bin/dircd.exe` is the daemon program.

## Usage

There is no configuration for now. Just run it.

    bin/dircd.exe

### Environment Variables

| Variable Name            |                           | default |
| ------------------------ | ------------------------- | ------: |
| IRCD_HOSTADDR            | listen inet address       | 0.0.0.0 |
| IRCD_PORT                | listen port               |    6667 |
| IRCD_PRIVATE_KEY         | TLS cert file path        |         |
| IRCD_MOTD                | MOTD file path            |         |
| IRCD_PASSWORD            | connection password       |         |
| IRCD_CONN_CHECK_INTERVAL | connection liveness check |      30 |

## Functionality

- [x] PRIVMSG / NOTICE
- [x] PING / PONG
- [x] JOIN / PART
- [x] NICK / USER / PASS
- [x] QUIT
- [ ] MODE for channel.
- [ ] MODE for user.
- [x] TOPIC
- [ ] INVITE / KICK
- [x] MOTD
- [ ] WHO / WHOIS / WHOWAS
- [x] ISON
- [x] AWAY
- [x] Configure the listen port number.
- [x] Configure the listen interface address.
- [x] Communicates with TLS (Secure Socket).
- [x] CAP capabilities negotiation mechanism.
- [x] PASS authentication with fixed string.
- [x] PASS authentication with custom subclassing.
- [ ] SASL authentication.
- [ ] Flood control.
- [ ] Server-Server communications. (currently out of scope.)

## LICENSE

MIT

See LICENSE file.

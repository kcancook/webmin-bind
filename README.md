# webmin-bind

A Docker image that combines **Webmin** and **BIND 9** so a DNS server can be deployed and administered through the Webmin web interface.

This repository is the source for the published container image. The documentation below is focused on **running and consuming** the image, not rebuilding it locally.

## What the image provides

- Webmin web administration on port `10000`.
- BIND 9 DNS service on port `53` over both TCP and UDP.
- A simple BIND configuration layout using `named.conf`, `named.conf.options`, and `named.conf.local`.
- A sample authoritative zone that can be replaced with real zone data after deployment.

## Exposed ports

Expose these ports when running the container:

- `53/tcp` for DNS over TCP.
- `53/udp` for standard DNS queries.
- `10000/tcp` for Webmin.

## Runtime layout

The image uses the following paths at runtime:

```text
/etc/bind/
├── named.conf
├── named.conf.options
└── named.conf.local

/var/cache/bind/
└── db.home.test

/var/lib/bind/
/etc/webmin/
```

### BIND files

- `/etc/bind/named.conf` is the top-level BIND configuration file.
- `/etc/bind/named.conf.options` contains global DNS settings such as listen addresses, recursion policy, and query controls.
- `/etc/bind/named.conf.local` contains local zone declarations.
- `/var/cache/bind/` stores zone files, including the bundled sample zone.

### Webmin files

- `/etc/webmin/` stores Webmin configuration used by the web interface.

## Included sample zone

The image includes a sample authoritative zone for testing:

- Zone name: `home.test`
- Zone file: `/var/cache/bind/db.home.test`

This sample is provided only as a starting point and should be replaced with real zone data for actual use.

## Persistent data

If persistent configuration is desired, mount these container paths from the host:

- `/etc/bind`
- `/var/cache/bind`
- `/var/lib/bind`
- `/etc/webmin` (optional)

Example host-side layout:

```text
data/
├── etc-bind/
├── cache-bind/
├── lib-bind/
└── etc-webmin/
```

When host bind mounts are used, the mounted directories override the files baked into the image at those same paths. [web:1592]

## Example deployment

```yaml
services:
  webmin-bind:
    image: kcancook/webmin-bind:latest
    container_name: webmin-bind
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "10000:10000/tcp"
    environment:
      TZ: America/New_York
      ROOT_PASSWORD: change-me-now
    volumes:
      - ./data/etc-bind:/etc/bind
      - ./data/cache-bind:/var/cache/bind
      - ./data/lib-bind:/var/lib/bind
```

## First access

After the container starts, open:

```text
https://<server-ip>:10000
```

Then log in and use the **BIND DNS Server** module in Webmin to manage zones and records.

## Post-deployment checks

Basic validation after starting the container:

- Confirm the container is running with `docker compose ps`.
- Open Webmin on port `10000`.
- Query the sample zone with `dig @<server-ip> home.test SOA`.
- Replace the sample zone with your own zone files before production use.

## Notes

- The sample `home.test` zone is meant only for initial validation.
- Firewalls must allow inbound DNS on port 53 over both TCP and UDP if other devices will query the server. [web:1576]
- Webmin requires port 10000 to be reachable from the client if remote administration is needed. [web:1389]
- On hosts without working IPv6 connectivity, BIND may log IPv6 reachability warnings while still working normally over IPv4. [web:1545][web:1552]

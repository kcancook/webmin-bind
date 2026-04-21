# webmin-bind

A starter project for publishing a combined Webmin + BIND Docker image.

## What this includes

- Ubuntu-based Docker image
- BIND 9 installed from Ubuntu packages
- Webmin installed from the official Webmin repository
- Example Docker Compose file
- GitHub Actions workflow to publish images to Docker Hub
- Example BIND ACL and master zone configuration

## Repository layout

```text
.
├── .github/workflows/docker-publish.yml
├── Dockerfile
├── docker-compose.yml
├── docker/
│   └── entrypoint.sh
└── examples/
    └── named.conf.local.example
```

## Build locally

```bash
docker build -t yourdockerhubuser/webmin-bind:dev .
```

## Run locally

```bash
mkdir -p data/etc-bind data/cache-bind data/lib-bind data/etc-webmin
docker compose up -d
```

Then open:

```text
https://<server-ip>:10000
```

## Default ports

- 53/tcp
- 53/udp
- 10000/tcp

## Volumes

- `/etc/bind`
- `/var/cache/bind`
- `/var/lib/bind`
- `/etc/webmin`

## Publish to Docker Hub

1. Create a Docker Hub repository named `webmin-bind`.
2. Add these GitHub repository secrets:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`
3. Push a git tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The included GitHub Actions workflow will build and publish:
- `yourdockerhubuser/webmin-bind:v1.0.0`
- `yourdockerhubuser/webmin-bind:latest`

## Recommended improvements before public release

- Pin package versions or add explicit image labels.
- Add healthchecks.
- Replace the simple startup script with `supervisord` or `s6-overlay`.
- Add a non-default TLS cert strategy for Webmin.
- Test volume upgrade behavior.
- Add documentation for authoritative-only mode and transfer ACLs.

## Notes

This starter is intended as a foundation, not a production-hardened final image.

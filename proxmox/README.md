# Proxmox LXC for this fork

Creates an LXC that runs `ghcr.io/omfgnuts/yamtrack-omfgnuts` (built by GitHub Actions on every push) together with Postgres and Redis in Docker. It runs on the [community-scripts](https://community-scripts.org/scripts/yamtrack) engine, so the prompts and the `update` command work like the official Yamtrack script. It can run next to an official Yamtrack LXC: each container has its own hostname, IP and data.

Run this in the Proxmox host shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/omfgnuts/Yamtrack/dev/proxmox/ct/yamtrack-omfgnuts.sh)"
```

To track a branch image instead of `latest`, set the tag first (a `/` in a branch name becomes `-`, so `feat/foo` is `feat-foo`):

```bash
var_yamtrack_tag=feat-foo bash -c "$(curl -fsSL https://raw.githubusercontent.com/omfgnuts/Yamtrack/dev/proxmox/ct/yamtrack-omfgnuts.sh)"
```

## Image access

The container pulls the image without credentials, so the package must stay public. You can check the visibility in the [package settings](https://github.com/users/omfgnuts/packages/container/yamtrack-omfgnuts/settings).

## Pull errors

The installer and `update` retry a failed pull twice. If it still fails, the installation log shows Docker's error.

If the error contains `lookup ghcr.io on <ip>:53: no such host`, the container's DNS server failed. By default the container uses the Proxmox host's DNS server, often the router. Install with a different DNS server:

```bash
var_ns=1.1.1.1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/omfgnuts/Yamtrack/dev/proxmox/ct/yamtrack-omfgnuts.sh)"
```

For an existing container, run `pct set <CTID> --nameserver 1.1.1.1` on the host, then restart the container.

## Image tags

| You push         | Tags published               |
| ---------------- | ---------------------------- |
| `dev`            | `latest`, `dev`              |
| any other branch | the branch name              |
| a `v*` tag       | `X.Y.Z`, `X.Y`, `X`, `latest` |

The About page shows the version as `<upstream tag>-<commits>-g<sha>-omfgnuts`, so you can tell the instances apart.

## Updating

Run `update` in the container console. It pulls the newest image for the configured tag and restarts the stack.

To switch to another tag, change `YAMTRACK_TAG` in `/opt/yamtrack/.env`, then run `update`.

## Files in the container

- `/opt/yamtrack/compose.yaml` - the Docker Compose stack
- `/opt/yamtrack/.env` - Yamtrack settings (generated `SECRET` and database password); add other [environment variables](../docs/env-variables.md) here
- `/opt/yamtrack/db/` - Postgres data

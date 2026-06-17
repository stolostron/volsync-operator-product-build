# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Downstream product build repository for the VolSync Operator, built via Konflux for Red Hat.
The `main` branch holds shared configuration (Renovate, GitHub workflows). The actual build artifacts
(Dockerfiles, RPM lockfiles, build-arg configs, bundle manifests) live on **release-X.Y branches**.

## Key files (release branches only)

- `Dockerfile.rhtap` / `bundle.Dockerfile.rhtap` — Konflux build Dockerfiles
- `rhtap-buildargs.conf` — build args including submodule GIT hashes and volsync image SHA (Konflux nudges keep this updated)
- `rpms.in.yaml` / `rpms.lock.yaml` — RPM dependency declarations and lockfile
- `drift-cache/volsync/Dockerfile.cached` — must match volsync submodule's Dockerfile; build fails on mismatch
- `bundle-hack/update-bundle.sh` — uses yq submodule for CSV yaml edits during bundle build

## Building (release branches only)

```bash
podman build --build-arg-file rhtap-buildargs.conf -f Dockerfile.rhtap -t volsync:local .
podman build --build-arg-file rhtap-buildargs.conf -f bundle.Dockerfile.rhtap -t volsync-bundle:local .
```

### Updating RPM lockfiles

Requires [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) and registry.redhat.io access in `$HOME/.docker/config.json`:

```bash
container_dir=/work
podman run --rm \
  -v "${PWD}:${container_dir}:z" \
  -v "$HOME/.docker/config.json:/root/.docker/config.json:ro,z" \
  localhost/rpm-lockfile-prototype:latest \
  --outfile="${container_dir}/rpms.lock.yaml" \
  "${container_dir}/rpms.in.yaml"
```

## Submodule update rules

- **volsync** updates require copying its `Dockerfile` to `drift-cache/volsync/Dockerfile.cached`. The build fails if these diverge.
- **rclone, syncthing, diskrsync** must only be updated when the corresponding change is made in the volsync submodule. Update matching GIT hashes in `rhtap-buildargs.conf`.
- Submodules are not checked out on `main` — only on release branches via `git submodule update --init --recursive`.

## Version mapping

ACM X.Y ships volsync release-0.(Y-1), not 0.Y. Example: ACM 2.13 uses the release-0.12 branch.

## Personal configuration

Read personal config at the start of any task that needs an assignee, email, or project key.
Use the tool-aware fallback chain: ~/.config/opencode/user.local.md (OpenCode),
.claude/user.local.md (Claude Code), or .cursor/rules/user.local.mdc (Cursor, already in context).
If none exist, fall back to agent memory (`user-config`), then placeholders.
Run `make personalize` to generate all three files (if this repo uses Fleet Engineering tooling).

## Fleet Engineering Skills

All skills are available as slash commands. See the [Fleet Engineering skills catalog](https://github.com/OpenShift-Fleet/agentic-sdlc/blob/main/skills/README.md) for the full list with when-to-use guidance.

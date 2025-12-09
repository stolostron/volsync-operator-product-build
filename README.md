# volsync-operator-product-build
VolSync Operator Product Build to build downstream VolSync via Konflux

## Getting Started

The main branch for this repo contains the renovate config [renovate.json](renovate.json) used by renovate for all branches.
Look at the release-X.Y branches for configuration related to building the related X.Y release downstream
of VolSync via konflux.

This repo contains submodules in order to have all the dependencies
to build the VolSync Operator.

Current submodules:

- [volsync](volsync) - points to https://github.com/volsync/volsync
- [rclone](rclone) - points to https://github.com/rclone/rclone
- [syncthing](syncthing) - points to https://github.com/syncthing/syncthing
- [diskrsync](diskrsync) - points to https://github.com/dop251/diskrsync
- [yq](yq) - points to https://github.com/mikefarah/yq - This submodule is only needed for editing the CSV yaml
 with custom edits for Red Hat in bundle-hack/update-bundle.sh during the bundle build
- [drift-detection](drift-detection) - points to  https://github.com/arewm/drift-detection - This submodule is only
  needed for the bundle generation and detecting if volsync has diverged from our config.

To clone this repo and submodules it can be done in one step with:

```bash
git clone https://github.com/stolostron/volsync-operator-product-build.git --recurse-submodules
```

Or, after cloning the repo you can do this to pull the submodules:

```bash
cd volsync-operator-product-build
git submodule update --init --recursive
```

## Updating

Submodules such as rclone, syncthing, diskrsync should not be updated unless the corresponding update is made in
volsync itself.

When the volsync submodule is updated, the Dockerfile will need to be copied to [Dockerfile.cached](drift-cache/volsync/Dockerfile.cached).
The volsync build (building Dockerfile.rhtap) will fail if the Dockerfile.cached doesn't match the one in volsync.  Not matching
is usually an indicator something like one of the other submodules was updated.

If another submodule (rclone, syncthing, diskrsync) needs an update, make sure to update the proper GIT hashes in
[rhtap-buildargs.conf](rhtap-buildargs.conf).

The [rhtap-buildargs.conf](rhtap-buildargs.confg) file is also used during the bundle build and will contain the
volsync image SHA to be packaged in the bundle image.  Konflux nudges from the volsync component should keep this up-to-date.

## Building locally

To build locally and simulate/exercise what the konflux build will do, you can do the following:


Build the volsync container

```bash
podman build --build-arg-file rhtap-buildargs.conf -f Dockerfile.rhtap -t volsync-container:local-build-latest .
```

Build the volsync bundle

```bash
podman build --build-arg-file rhtap-buildargs.conf -f bundle.Dockerfile.rhtap -t volsync-bundle:local-build-latest .
```

### Editing RPM dependencies

If any dependencies are added or removed in the Dockerfiles then we will need to update [rpms.in.yaml](rpms.in.yaml)
and [rpms.lock.yaml](rpms.lock.yaml)

Using the [rpm-lockfile-prototype tool](https://github.com/konflux-ci/rpm-lockfile-prototype)

Steps to locally update rpms lockfile: 


0. Intial setup of [rpm-lockfile-prototype tool](https://github.com/konflux-ci/rpm-lockfile-prototype)
1. Update the rpms.in.yaml inside the project
1. Check if `$HOME/.docker/config.json` has access to registry.redhat.io
1. Now run the tool inside the container

```bash
container_dir=/work
podman run --rm \
  -v "${PWD}:${container_dir}:z" \
  -v "$HOME/.docker/config.json:/root/.docker/config.json:ro,z" \
  localhost/rpm-lockfile-prototype:latest \
  --outfile="${container_dir}/rpms.lock.yaml" \
  "${container_dir}/rpms.in.yaml"
```

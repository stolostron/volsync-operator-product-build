#!/usr/bin/env bash

# Originally from cpaas build render_templates file

export MANIFESTS_DIR=/manifests
export METADATA_DIR=/metadata
export CSV_FILENAME="volsync.clusterserviceversion.yaml"
export CSV_FILE="${MANIFESTS_DIR}/${CSV_FILENAME}"

set -x
env

# Check for needed env vars - these are set from rhtap-buildargs.conf
if [[ -z "$VERSION" ]] ||
  [[ -z "$STAGE_VOLSYNC_IMAGE_PULLSPEC" ]] ||
  [[ -z "$OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC" ]] ||
  [[ -z "$ACM_DOCLINK" ]]; then
  echo "ERROR: All required environment variables not loaded"
  echo "    VERSION"
  echo "    STAGE_VOLSYNC_IMAGE_PULLSPEC"
  echo "    OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC"
  echo "    ACM_DOCLINK"
  exit 2
fi

# Check the version we're trying to build matches volsync
vs_version=$(cat /tmp/version.mk | grep "^VERSION :=")
vs_version="${vs_version##* }"

echo "VolSync vs_version: ${vs_version}, VERSION: ${VERSION}"
if [[ "${vs_version}" != "${VERSION}" ]]; then
  echo "ERROR: version of volsync ${vs_version} does not match expected version: ${VERSION}"
  exit 2
fi

# Update img reference to final registry.redhat.io location
export VOLSYNC_IMAGE_PULLSPEC="registry.redhat.io/rhacm2/volsync-rhel9@${STAGE_VOLSYNC_IMAGE_PULLSPEC##*@}"

# Update rbac proxy image link to remove the tag - rhtap-buildargs has pinned digest with tag so renovate can update,
# But we don't want the tag in the bundle references
export OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC="${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC/:*@sha256/@sha256}"

echo "### Updated image refs: ###"
echo " VOLSYNC_IMAGE_PULLSPEC: ${VOLSYNC_IMAGE_PULLSPEC}"
echo " OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC: ${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC}"
echo ""

if [ ! -f "${CSV_FILE}" ]; then
  echo "CSV file not found, the version or name might have changed on us!"
  exit 5
fi

set -e -o pipefail

# Check for yq
echo "### PATH IS: $PATH ####"
yq --version

# For backwards compatibility ... just in case, separately rip out docker.io
# as this is no longer used as of version 0.2.0.
sed -i \
  -e "s|quay.io/backube/volsync:latest|${VOLSYNC_IMAGE_PULLSPEC}|g" \
  -e "s|gcr.io/kubebuilder/kube-rbac-proxy:.*$|${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC}|g" \
  -e "s|quay.io/brancz/kube-rbac-proxy:.*$|${OSE_KUBE_RBAC_PROXY_IMAGE_PULLSPEC}|g" \
  "${CSV_FILE}"

# Convert volsync name to volsync-product in files
sed -i -e "s|volsync\\.v|volsync-product\\.v|g" "${CSV_FILE}"
sed -i -e "s|volsync|volsync-product|g" "${METADATA_DIR}/annotations.yaml"

# Add -product to the CSV name
export TARGET_CSV_FILE="${MANIFESTS_DIR}/${CSV_FILENAME%%.*}-product.${VERSION}.${CSV_FILENAME#*.}"

# Rename CSV file with version
mv "${CSV_FILE}" "${TARGET_CSV_FILE}"

export EPOC_TIMESTAMP=$(date +%s)

# time for some direct modifications to the csv
#yq -i '
#  .spec.maintainers[0].email = "acm-contact@redhat.com" |
#  .spec.maintainers[0].name = "Red Hat ACM Team" |
yq -i '
  .spec.maintainers = [{ "email": "acm-contact@redhat.com", "name": "Red Hat ACM Team"}] |
  .spec.provider.name = "Red Hat"
' "${TARGET_CSV_FILE}"

# Remove spec.relatedImages section as it is not needed in midstream build
yq -i '
  del(.spec.relatedImages)
' "${TARGET_CSV_FILE}"

# Add arch support labels
yq -i '
  .metadata.labels.["operatorframework.io/arch.amd64"] = "supported" |
  .metadata.labels.["operatorframework.io/arch.arm64"] = "supported" |
  .metadata.labels.["operatorframework.io/arch.ppc64le"] = "supported" |
  .metadata.labels.["operatorframework.io/arch.s390x"] = "supported" |
  .metadata.labels.["operatorframework.io/os.linux"] = "supported"
' "${TARGET_CSV_FILE}"

#TODO: this annotation
#createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')

# Annotations
yq -i '
  .metadata.annotations.["support"] = "Red Hat" |
  .metadata.annotations.["features.operators.openshift.io/disconnected"] = "true" |
  .metadata.annotations.["features.operators.openshift.io/fips-compliant"] = "true" |
  .metadata.annotations.["features.operators.openshift.io/proxy-aware"] = "true" |
  .metadata.annotations.["features.operators.openshift.io/tls-profiles"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/token-auth-aws"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/token-auth-azure"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/token-auth-gcp"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/cnf"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/cni"] = "false" |
  .metadata.annotations.["features.operators.openshift.io/csi"] = "false" |
  .metadata.annotations.["operators.openshift.io/valid-subscription"] = "[\"OpenShift Platform Plus\", \"Red Hat Advanced Cluster Management for Kubernetes\"]" |
  .metadata.annotations.["repository"] = "https://github.com/backube/volsync" |
  .metadata.annotations.["containerImage"] = strenv(VOLSYNC_IMAGE_PULLSPEC)
' "${TARGET_CSV_FILE}"

# Update description and
# Update to use the ACM doclink
export CSV_DESCRIPTION=$(
  cat <<EOF


### Documentation

For documentation about installing and using the VolSync Operator with Red Hat Advanced Cluster Management for
Kubernetes, see [VolSync persistent volume replication service]($ACM_DOCLINK) in the Red Hat Advanced Cluster Management
documentation.

For additional information about the VolSync project, including features that might not be supported by Red Hat, see
the [VolSync community](https://volsync.readthedocs.ioe/) documentation.

### Support & Troubleshooting

Product support, which includes Support Cases, Product Pages, and Knowledgebase articles, is available when you have
a [Red Hat Advanced Cluster Management](https://www.redhat.com/en/technologies/management/advanced-cluster-management)
subscription.
EOF

)

# CSV name contains the product name and version
export CSV_NAME="volsync-product.v${VERSION}"

# Update description, name, version and doclink
yq -i '
  .spec.description += strenv(CSV_DESCRIPTION) |
  .metadata.name = strenv(CSV_NAME) |
  .spec.version = strenv(VERSION) |
  (.spec.links[] | select(.name == "Documentation") | .url) = strenv(ACM_DOCLINK)
' "${TARGET_CSV_FILE}"

cat ${TARGET_CSV_FILE}

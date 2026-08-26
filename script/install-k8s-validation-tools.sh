#!/usr/bin/env bash
set -euo pipefail

# Keep CI rendering and schema validation reproducible across GitHub and
# GitCode runners. Updating either version requires reviewing and updating the
# release-asset checksums below.
kustomize_version="${KUSTOMIZE_VERSION:-5.7.1}"
kubeconform_version="${KUBECONFORM_VERSION:-0.8.0}"
install_dir="${1:-/usr/local/bin}"

if [[ "$kustomize_version" != "5.7.1" ]]; then
  echo "unsupported Kustomize version: $kustomize_version" >&2
  exit 1
fi
if [[ "$kubeconform_version" != "0.8.0" ]]; then
  echo "unsupported kubeconform version: $kubeconform_version" >&2
  exit 1
fi

case "$(uname -s)" in
  Linux) os="linux" ;;
  *)
    echo "the pinned CI validator installer currently supports Linux only" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64)
    arch="amd64"
    kustomize_sha256="ea375e7372f9aa029129d4b2d16c66b7750b7f1213c4f66f910d981c895818d8"
    kubeconform_sha256="9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883"
    ;;
  aarch64 | arm64)
    arch="arm64"
    kustomize_sha256="4261a040217df3bd6896597c3986d1465925726e4f22a945304b5233a4dcdbda"
    kubeconform_sha256="1f53fc8e81258197a35e8603054162a5af1de8c5af13746c71ab680d9534ed87"
    ;;
  *)
    echo "unsupported validator architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

kustomize_archive="$work_dir/kustomize.tar.gz"
kubeconform_archive="$work_dir/kubeconform.tar.gz"
kustomize_url="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${kustomize_version}/kustomize_v${kustomize_version}_${os}_${arch}.tar.gz"
kubeconform_url="https://github.com/yannh/kubeconform/releases/download/v${kubeconform_version}/kubeconform-${os}-${arch}.tar.gz"

curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
  --retry 3 --retry-all-errors --output "$kustomize_archive" "$kustomize_url"
curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
  --retry 3 --retry-all-errors --output "$kubeconform_archive" "$kubeconform_url"

printf '%s  %s\n' "$kustomize_sha256" "$kustomize_archive" | sha256sum --check --strict
printf '%s  %s\n' "$kubeconform_sha256" "$kubeconform_archive" | sha256sum --check --strict

tar -xzf "$kustomize_archive" -C "$work_dir" kustomize
tar -xzf "$kubeconform_archive" -C "$work_dir" kubeconform
mkdir -p -- "$install_dir"
install -m 0755 "$work_dir/kustomize" "$install_dir/kustomize"
install -m 0755 "$work_dir/kubeconform" "$install_dir/kubeconform"

[[ "$("$install_dir/kustomize" version)" == "v${kustomize_version}" ]]
[[ "$("$install_dir/kubeconform" -v)" == "v${kubeconform_version}" ]]
echo "installed kustomize v${kustomize_version} and kubeconform v${kubeconform_version}"

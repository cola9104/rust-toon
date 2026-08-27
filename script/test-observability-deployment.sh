#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_dir="$repo_root/deploy/logging-agent"
work_dir="$(mktemp -d)"
rendered_file="$work_dir/rendered.yaml"
kubernetes_schema_version="${KUBERNETES_SCHEMA_VERSION:-1.31.0}"

cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

if command -v kustomize >/dev/null 2>&1; then
  kustomize build "$manifest_dir" >"$rendered_file"
elif command -v kubectl >/dev/null 2>&1; then
  kubectl kustomize "$manifest_dir" >"$rendered_file"
else
  echo "kustomize or kubectl is required to validate the logging agent" >&2
  exit 1
fi

if command -v kubeconform >/dev/null 2>&1; then
  kubeconform \
    -strict \
    -summary \
    -kubernetes-version "$kubernetes_schema_version" \
    "$rendered_file"
elif [[ "${CI:-false}" == "true" ]]; then
  echo "CI requires kubeconform for logging-agent schema validation" >&2
  exit 1
fi

ruby - "$rendered_file" <<'RUBY'
require "yaml"

def assert(condition, message)
  raise message unless condition
end

objects = YAML.load_stream(File.read(ARGV.fetch(0))).compact.to_h do |object|
  [[object.fetch("kind"), object.dig("metadata", "name")], object]
end

namespace = objects.fetch(["Namespace", "rust-toon-logging"])
assert(namespace.dig("metadata", "labels", "rust-toon.io/logging-agent") == "true",
       "logging namespace must carry the cross-namespace policy label")
assert(namespace.dig("metadata", "labels", "pod-security.kubernetes.io/enforce") == "baseline",
       "logging namespace must explicitly enforce the baseline Pod Security profile")

daemon_set = objects.fetch(["DaemonSet", "rust-toon-vector"])
pod = daemon_set.dig("spec", "template", "spec")
assert(pod.dig("serviceAccountName") == "rust-toon-vector",
       "Vector must use its scoped service account")
container = pod.fetch("containers").find { |entry| entry["name"] == "vector" }
assert(container && !container.fetch("image").end_with?(":latest"),
       "Vector image must use a pinned version")
assert(container.dig("securityContext", "allowPrivilegeEscalation") == false,
       "Vector must disable privilege escalation")
assert(container.dig("securityContext", "readOnlyRootFilesystem") == true,
       "Vector must use a read-only root filesystem")
pod_log_mount = container.fetch("volumeMounts").find { |entry| entry["name"] == "pod-logs" }
assert(pod_log_mount && pod_log_mount["readOnly"] == true,
       "Kubernetes Pod logs must be mounted read-only")

config = objects.fetch(["ConfigMap", "rust-toon-vector-config"]).dig("data", "vector.yaml")
assert(config.include?('.kubernetes.pod_namespace == "rust-toon"'),
       "Vector must discard logs outside the Rust Toon namespace")
assert(config.include?("rust-toon-loki.rust-toon.svc.cluster.local:3100"),
       "Vector must send logs to the in-cluster Loki service")

role = objects.fetch(["ClusterRole", "rust-toon-vector"])
verbs = role.fetch("rules").flat_map { |rule| rule.fetch("verbs") }.uniq.sort
assert(verbs == %w[get list watch], "Vector RBAC must remain read-only")
objects.fetch(["ClusterRoleBinding", "rust-toon-vector"])
objects.fetch(["NetworkPolicy", "rust-toon-vector-egress"])

puts "validated #{objects.length} logging-agent objects"
RUBY

echo "Observability logging-agent checks passed"

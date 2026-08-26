#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_dir="$repo_root/deploy/k8s"
work_dir="$(mktemp -d)"
rendered_file="$work_dir/rendered.yaml"
kustomize_version="${KUSTOMIZE_VERSION:-5.7.1}"
kubeconform_version="${KUBECONFORM_VERSION:-0.8.0}"
kubernetes_schema_version="${KUBERNETES_SCHEMA_VERSION:-1.31.0}"
ci_mode=false
case "${CI:-false}" in
  1 | true | TRUE | yes | YES) ci_mode=true ;;
esac

cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

if command -v kustomize >/dev/null 2>&1; then
  actual_kustomize_version="$(kustomize version)"
  if $ci_mode && [[ "$actual_kustomize_version" != "v${kustomize_version}" ]]; then
    echo "CI requires kustomize v${kustomize_version}, found ${actual_kustomize_version}" >&2
    exit 1
  fi
  kustomize build "$manifest_dir" >"$rendered_file"
  renderer="kustomize ${actual_kustomize_version}"
elif $ci_mode; then
  echo "CI requires the pinned standalone kustomize binary" >&2
  exit 1
elif command -v kubectl >/dev/null 2>&1; then
  kubectl kustomize "$manifest_dir" >"$rendered_file"
  renderer="kubectl kustomize (local fallback)"
else
  : >"$rendered_file"
  renderer="repository YAML (local fallback)"
fi

# Kubeconform validates Kubernetes OpenAPI shape. The Ruby checks below are
# additional repository-specific invariants, never a schema-validation
# substitute in CI.
if command -v kubeconform >/dev/null 2>&1; then
  actual_kubeconform_version="$(kubeconform -v)"
  if $ci_mode && [[ "$actual_kubeconform_version" != "v${kubeconform_version}" ]]; then
    echo "CI requires kubeconform v${kubeconform_version}, found ${actual_kubeconform_version}" >&2
    exit 1
  fi
  kubeconform \
    -strict \
    -summary \
    -kubernetes-version "$kubernetes_schema_version" \
    "$rendered_file"
  schema_validator="kubeconform ${actual_kubeconform_version} (Kubernetes ${kubernetes_schema_version})"
elif $ci_mode; then
  echo "CI requires the pinned kubeconform binary; schema fallback is disabled" >&2
  exit 1
else
  schema_validator="not available (local semantic checks only)"
fi

if command -v ruby >/dev/null 2>&1; then
  ruby - "$manifest_dir" "$rendered_file" <<'RUBY'
require "yaml"

manifest_dir, rendered_file = ARGV

def assert(condition, message)
  raise message unless condition
end

def load_documents(path)
  YAML.load_stream(File.read(path)).compact
rescue Psych::SyntaxError => error
  raise "invalid YAML in #{path}: #{error.message}"
end

kustomization_path = File.join(manifest_dir, "kustomization.yaml")
kustomization = load_documents(kustomization_path).fetch(0)
assert(kustomization["apiVersion"] == "kustomize.config.k8s.io/v1beta1" &&
       kustomization["kind"] == "Kustomization",
       "deploy/k8s/kustomization.yaml is not a supported Kustomization")
assert(kustomization["namespace"] == "rust-toon",
       "Kustomize base must target the rust-toon namespace")
backend_image = kustomization.fetch("images").find { |image| image["name"] == "rust-toon/backend" }
assert(backend_image, "Kustomize image replacement for rust-toon/backend is missing")
assert(backend_image["newTag"] != "latest", "Kustomize must not deploy a floating latest tag")
resources = kustomization.fetch("resources")
assert(!resources.include?("secret.example.yaml"),
       "the plaintext Secret example must not be part of the Kustomize base")

resources.each do |resource|
  path = File.join(manifest_dir, resource)
  assert(File.file?(path), "Kustomize resource does not exist: #{resource}")
end

forbidden_development_secrets = [
  "admin123", "Admin#123456", "rust_toon_password",
  "local-development-jwt-secret"
]
manifest_text = Dir.glob(File.join(manifest_dir, "*.yaml")).map { |path| File.read(path) }.join("\n")
forbidden_development_secrets.each do |value|
  assert(!manifest_text.include?(value),
         "Kubernetes manifests contain a known development credential: #{value}")
end

secret_path = File.join(manifest_dir, "secret.example.yaml")
secret_examples = load_documents(secret_path)
secret_requirements = {
  "rust-toon-gateway-secrets" => %w[
    DATABASE_URL REDIS_URL JWT_SECRET SECRET_ENCRYPTION_KEY
    MINIO_ACCESS_KEY MINIO_SECRET_KEY BOOTSTRAP_ADMIN_PASSWORD
  ],
  "rust-toon-worker-secrets" => %w[
    DATABASE_URL MINIO_ACCESS_KEY MINIO_SECRET_KEY NATS_URL
  ]
}
secret_requirements.each do |name, required_keys|
  secret = secret_examples.find { |entry| entry.dig("metadata", "name") == name }
  assert(secret && secret["kind"] == "Secret", "Secret example is missing #{name}")
  secret_data = secret.fetch("stringData")
  required_keys.each do |key|
    assert(secret_data.key?(key), "#{name} is missing #{key}")
    assert(secret_data.fetch(key).to_s.include?("REPLACE_ME"),
           "Secret example must not contain a usable value for #{name}.#{key}")
  end
end

rendered = File.size?(rendered_file) ? load_documents(rendered_file) : resources.flat_map do |resource|
  load_documents(File.join(manifest_dir, resource))
end

objects = {}
rendered.each do |object|
  kind = object["kind"]
  name = object.dig("metadata", "name")
  assert(kind && name, "every rendered object must have kind and metadata.name")
  key = [kind, name]
  assert(!objects.key?(key), "duplicate rendered object #{kind}/#{name}")
  objects[key] = object
end

def object!(objects, kind, name)
  objects.fetch([kind, name]) { raise "missing #{kind}/#{name}" }
end

def binary_storage_bytes(quantity)
  match = /\A([0-9]+(?:\.[0-9]+)?)([KMGTPE]i)?\z/.match(quantity.to_s)
  raise "invalid binary storage quantity: #{quantity.inspect}" unless match

  scales = {
    nil => 1,
    "Ki" => 1024,
    "Mi" => 1024**2,
    "Gi" => 1024**3,
    "Ti" => 1024**4,
    "Pi" => 1024**5,
    "Ei" => 1024**6
  }
  match[1].to_f * scales.fetch(match[2])
end

namespace = object!(objects, "Namespace", "rust-toon")
assert(namespace.dig("metadata", "labels", "pod-security.kubernetes.io/enforce") == "restricted",
       "Namespace must enforce the restricted Pod Security profile")

service_account = object!(objects, "ServiceAccount", "rust-toon")
assert(service_account["automountServiceAccountToken"] == false,
       "ServiceAccount token automount must be disabled")

gateway = object!(objects, "Deployment", "rust-toon-gateway")
worker = object!(objects, "Deployment", "rust-toon-worker")
assert(gateway.dig("spec", "replicas") == 1, "Gateway must stay at exactly one replica")
assert(gateway.dig("spec", "strategy", "type") == "Recreate",
       "Gateway rollouts must not overlap process-local runtimes")
assert(worker.dig("spec", "replicas").to_i >= 2,
       "Worker base must start with at least two replicas")

[
  [gateway, "gateway", 45, "rust-toon-gateway-secrets"],
  [worker, "worker", 75, "rust-toon-worker-secrets"]
].each do |deployment, container_name, grace, secret_name|
  pod = deployment.dig("spec", "template", "spec")
  assert(pod["automountServiceAccountToken"] == false,
         "#{container_name} must not mount a Kubernetes API token")
  assert(pod["terminationGracePeriodSeconds"].to_i >= grace,
         "#{container_name} termination grace period is too short")
  assert(pod.dig("securityContext", "runAsNonRoot") == true,
         "#{container_name} must run as non-root")
  assert(pod.dig("securityContext", "seccompProfile", "type") == "RuntimeDefault",
         "#{container_name} must use RuntimeDefault seccomp")

  container = pod.fetch("containers").find { |entry| entry["name"] == container_name }
  assert(container, "#{container_name} container is missing")
  security = container.fetch("securityContext")
  assert(security["allowPrivilegeEscalation"] == false,
         "#{container_name} must disable privilege escalation")
  assert(security["readOnlyRootFilesystem"] == true,
         "#{container_name} must use a read-only root filesystem")
  assert(security.dig("capabilities", "drop") == ["ALL"],
         "#{container_name} must drop all Linux capabilities")
  assert(container.dig("livenessProbe", "httpGet", "path") == "/livez",
         "#{container_name} liveness probe must use /livez")
  assert(container.dig("readinessProbe", "httpGet", "path") == "/readyz",
         "#{container_name} readiness probe must use /readyz")
  %w[requests limits].each do |class_name|
    %w[cpu memory ephemeral-storage].each do |resource_name|
      assert(container.dig("resources", class_name, resource_name),
             "#{container_name} is missing #{class_name}.#{resource_name}")
    end
  end
  image = container.fetch("image")
  assert(!image.end_with?(":latest"), "#{container_name} must not use the latest tag")
  refs = container.fetch("envFrom")
  assert(refs.any? { |ref| ref.dig("secretRef", "name") == secret_name },
         "#{container_name} must load only its scoped Secret")
end

worker_pod = worker.dig("spec", "template", "spec")
{
  gateway => "8080",
  worker => "8081"
}.each do |deployment, port|
  annotations = deployment.dig("spec", "template", "metadata", "annotations") || {}
  assert(annotations["prometheus.io/scrape"] == "true" &&
         annotations["prometheus.io/path"] == "/metrics" &&
         annotations["prometheus.io/port"] == port,
         "#{deployment.dig('metadata', 'name')} must expose per-Pod Prometheus discovery annotations")
end

worker_container = worker_pod.fetch("containers").find { |entry| entry["name"] == "worker" }
assert(worker_container.dig("resources", "limits", "ephemeral-storage") == "48Gi",
       "Worker ephemeral-storage limit must cover the supported export working set")
{
  gateway => ["gateway", "6Gi"],
  worker => ["worker", "48Gi"]
}.each do |deployment, (container_name, expected_limit)|
  pod = deployment.dig("spec", "template", "spec")
  container = pod.fetch("containers").find { |entry| entry["name"] == container_name }
  ephemeral_limit = container.dig("resources", "limits", "ephemeral-storage")
  tmp_volume = pod.fetch("volumes").find { |entry| entry["name"] == "tmp" }
  tmp_size_limit = tmp_volume&.dig("emptyDir", "sizeLimit")
  assert(ephemeral_limit == expected_limit,
         "#{container_name} ephemeral-storage limit must remain #{expected_limit}")
  assert(tmp_size_limit,
         "#{container_name} /tmp emptyDir must define sizeLimit")
  assert(binary_storage_bytes(ephemeral_limit) > binary_storage_bytes(tmp_size_limit),
         "#{container_name} ephemeral-storage limit must exceed /tmp emptyDir.sizeLimit")
end

init = worker_pod.fetch("initContainers").find do |entry|
  entry["name"] == "wait-for-gateway-migrations"
end
assert(init, "Worker needs an init container that waits for Gateway migrations")
init_command = init.fetch("command").join("\n")
assert(init_command.include?("http://rust-toon-gateway:8080/readyz"),
       "Worker init container must wait for Gateway /readyz")
assert(init.dig("securityContext", "readOnlyRootFilesystem") == true,
       "Worker init container must use a read-only root filesystem")
assert(init.dig("securityContext", "allowPrivilegeEscalation") == false,
       "Worker init container must disable privilege escalation")

gateway_config = object!(objects, "ConfigMap", "rust-toon-gateway-config")
worker_config = object!(objects, "ConfigMap", "rust-toon-worker-config")
assert(worker_config.dig("data", "TOON_WORKER_CONCURRENCY") == "1",
       "Worker base concurrency must preserve temporary-disk headroom")
assert(gateway_config.dig("data", "READINESS_REQUIRE_REDIS") == "true",
       "Gateway readiness must require Redis")
assert(gateway_config.dig("data", "READINESS_REQUIRE_MINIO") == "true",
       "Gateway readiness must require MinIO")
assert(gateway_config.dig("data", "TELEMETRY_LOG_FORMAT") == "json" &&
       worker_config.dig("data", "TELEMETRY_LOG_FORMAT") == "json",
       "Kubernetes workloads must emit production JSON logs")
assert(gateway_config.dig("data", "TELEMETRY_METRICS_ENABLED") == "true" &&
       worker_config.dig("data", "TELEMETRY_METRICS_ENABLED") == "true",
       "Kubernetes workloads must expose Prometheus metrics")
assert(!gateway_config.fetch("data").key?("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") &&
       !worker_config.fetch("data").key?("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"),
       "OTLP endpoint must be supplied only by an environment overlay")
assert(worker_config.dig("data", "TOON_WORKER_ALLOW_HTTP_SOURCES") == "false",
       "Worker HTTP source downloads must stay disabled")

object!(objects, "Service", "rust-toon-gateway")
object!(objects, "Service", "rust-toon-worker")
hpa = object!(objects, "HorizontalPodAutoscaler", "rust-toon-worker")
assert(hpa["apiVersion"] == "autoscaling/v2", "Worker HPA must use autoscaling/v2")
assert(hpa.dig("spec", "scaleTargetRef", "name") == "rust-toon-worker",
       "HPA must target only the Worker")
assert(hpa.dig("spec", "minReplicas").to_i >= 2, "Worker HPA minReplicas must be at least 2")
assert(hpa.dig("spec", "maxReplicas").to_i > hpa.dig("spec", "minReplicas").to_i,
       "Worker HPA maxReplicas must exceed minReplicas")
assert(objects.keys.none? { |kind, name| kind == "HorizontalPodAutoscaler" && name.include?("gateway") },
       "Gateway must not have an HPA")

pdb = object!(objects, "PodDisruptionBudget", "rust-toon-worker")
assert(pdb.dig("spec", "minAvailable").to_i >= 1,
       "Worker PDB must preserve at least one available replica")
gateway_pdb = object!(objects, "PodDisruptionBudget", "rust-toon-gateway")
assert(gateway_pdb.dig("spec", "minAvailable").to_i == 1,
       "Singleton Gateway PDB must block uncoordinated voluntary eviction")

%w[
  default-deny allow-dns-egress gateway-ingress worker-ingress
  gateway-external-egress worker-external-egress
].each do |name|
  object!(objects, "NetworkPolicy", name)
end
default_deny = object!(objects, "NetworkPolicy", "default-deny")
assert(default_deny.dig("spec", "policyTypes") == ["Ingress", "Egress"],
       "default-deny must isolate ingress and egress")
assert(!default_deny.dig("spec").key?("ingress") && !default_deny.dig("spec").key?("egress"),
       "default-deny must not contain allow rules")
worker_egress = object!(objects, "NetworkPolicy", "worker-external-egress")
gateway_wait_rule = worker_egress.dig("spec", "egress").find do |rule|
  rule.fetch("to", []).any? do |peer|
    peer.dig("podSelector", "matchLabels", "app.kubernetes.io/name") == "rust-toon-gateway"
  end
end
assert(gateway_wait_rule&.fetch("ports", [])&.any? { |port| port["port"] == 8080 },
       "Worker egress must allow the migration wait request to Gateway port 8080")
network_policy_ports = objects.filter_map do |(kind, _name), object|
  next unless kind == "NetworkPolicy"
  object.dig("spec", "egress")&.flat_map { |rule| rule.fetch("ports", []).map { |port| port["port"] } }
end.flatten
assert(!network_policy_ports.include?(4317),
       "Base NetworkPolicy must not globally expose the optional OTLP port")

deployment_doc = File.expand_path("../../docs/deployment.md", manifest_dir)
deployment_text = File.read(deployment_doc)
assert(deployment_text.include?("location = /metrics { return 404; }"),
       "Deployment docs must require public ingress to block /metrics")

assert(objects.keys.none? { |kind, _name| kind == "Secret" },
       "Kustomize base must not render a plaintext Secret")

puts "validated #{objects.length} Kubernetes objects"
RUBY
elif $ci_mode; then
  echo "CI requires Ruby for repository-specific Kubernetes invariants; grep fallback is disabled" >&2
  exit 1
else
  required_patterns=(
    'kind: Deployment'
    'name: rust-toon-gateway'
    'name: rust-toon-worker'
    'readOnlyRootFilesystem: true'
    'runAsNonRoot: true'
    'path: /readyz'
    'kind: HorizontalPodAutoscaler'
    'kind: PodDisruptionBudget'
    'kind: NetworkPolicy'
  )
  for pattern in "${required_patterns[@]}"; do
    grep -R -F -q -- "$pattern" "$manifest_dir" || {
      echo "missing Kubernetes requirement: $pattern" >&2
      exit 1
    }
  done
fi

echo "Kubernetes deployment checks passed (renderer: $renderer; schema: $schema_validator)"

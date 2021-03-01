(import "ksonnet-util/kausal.libsonnet") +
{
  _config:: {
    runner: {
      name: "runner",
      image: "raynix/github-runner-tanka",
    }
  },

  local clusterRoleBinding = $.rbac.v1.clusterRoleBinding,
  local namespace = $.core.v1.namespace,
  local deployment = $.apps.v1.deployment,
  local container = $.core.v1.container,
  local port = $.core.v1.containerPort,
  local service = $.core.v1.service,
  local secret = $.core.v1.secret,

  runner: {
    clusterRoleBinding: clusterRoleBinding.new()
    + clusterRoleBinding.withSubjects(
      {
        name: 'default',
        kind: "ServiceAccount",
        namespace: 'tanka'
      }
    )
    + clusterRoleBinding.mixin.roleRef.withKind("ClusterRole").withName("cluster-admin").withApiGroup("rbac.authorization.k8s.io")
    + clusterRoleBinding.mixin.metadata.withName("tanka-admin"),

    namespace: namespace.new("tanka"),

    deployment: deployment.new(
      name=$._config.runner.name,
      replicas=1,
      containers=[
        container.new($._config.runner.name, $._config.runner.image)
        + container.withEnvFrom(
            {
              secretRef: { name: "runner"}
            }
          ),
      ],
    )
    + deployment.mixin.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTerms(
        {
          matchExpressions: [
            { key: "kubernetes.io/arch", operator: "In", values:["arm64"]}
          ]
        }
      )

  }
}

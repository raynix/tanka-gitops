(import "ksonnet-util/kausal.libsonnet") +
{
  _config:: {
    httpbin: {
      port: 80,
      name: "httpbin",
      image: "kennethreitz/httpbin",
    }
  },

  local deployment = $.apps.v1.deployment,
  local container = $.core.v1.container,
  local port = $.core.v1.containerPort,
  local service = $.core.v1.service,
  local c = $._config.httpbin,

  httpbin: {
    deployment: deployment.new(
      name=c.name,
      replicas=1,
      containers=[
        container.new(c.name, c.image)
        + container.withPorts([port.new(c.name, c.port)])
        + $.util.resourcesRequests("100m", "100Mi")
        + $.util.resourcesLimits("500m", "500Mi")
        + container.mixin.livenessProbe.httpGet.withPath("/").withPort(c.port)
        + container.mixin.readinessProbe.httpGet.withPath("/").withPort(c.port),
      ],
    )
    + deployment.mixin.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTerms(
      {
        matchExpressions: [{
          key: "kubernetes.io/arch",
          operator: "In",
          values: [
            "amd64",
          ]
        }]
      }),

    service: $.util.serviceFor(self.deployment),
    ingress: $.util.ingressHelper('httpbin.awes.one', c.name, c.port)

  },
}

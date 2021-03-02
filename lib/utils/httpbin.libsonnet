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
  local ingress = $.networking.v1beta1.ingress,
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
    ),

    service: $.util.serviceFor(self.deployment),

    ingress: ingress.new()
      + ingress.mixin.metadata.withName(c.name)
      + ingress.mixin.metadata.withAnnotations({ "kubernetes.io/ingress.class": "prod" })
      + ingress.mixin.spec.withRules(
          {
            host: "httpbin.awes.one",
            http: {
              paths: [
                {
                  path: "/",
                  backend: {
                    serviceName: c.name,
                    servicePort: c.port
                  }
                }
              ]

            }

          }
        )
  },
}

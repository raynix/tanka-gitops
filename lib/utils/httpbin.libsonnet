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
  local c = $._config,

  httpbin: {
    deployment: deployment.new(
      name=c.httpbin.name,
      replicas=1,
      containers=[
        container.new(c.httpbin.name, c.httpbin.image)
        + container.withPorts([port.new(c.httpbin.name, c.httpbin.port)]),
      ],
    ),
    service: $.util.serviceFor(self.deployment),
  },
}

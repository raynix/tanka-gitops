// util.libsonnet provides a number of useful (opinionated) shortcuts to replace boilerplate code

local util(k) = {
  // mapToFlags converts a map to a set of golang-style command line flags.
  mapToFlags(map, prefix='-'): [
    '%s%s=%s' % [prefix, key, map[key]]
    for key in std.objectFields(map)
    if map[key] != null
  ],

  ingressHelper(host_name, service_name, service_port)::
    local ingress = k.networking.v1beta1.ingress;

    ingress.new()
      + ingress.mixin.metadata.withName("ingress-" + service_name)
      + ingress.mixin.metadata.withAnnotations({ "kubernetes.io/ingress.class": "prod" })
      + ingress.mixin.spec.withRules(
          {
            host: host_name,
            http: {
              paths: [
                {
                  path: "/",
                  backend: {
                    serviceName: service_name,
                    servicePort: service_port
                  }
                }
              ]
            }
          }
        ),

  // serviceFor create service for a given deployment.
  serviceFor(deployment, ignored_labels=[], nameFormat='%(container)s-%(port)s')::
    local container = k.core.v1.container;
    local service = k.core.v1.service;
    local servicePort = k.core.v1.servicePort;
    local ports = [
      servicePort.newNamed(
        name=(nameFormat % { container: c.name, port: port.name }),
        port=port.containerPort,
        targetPort=port.containerPort
      ) +
      if std.objectHas(port, 'protocol')
      then servicePort.withProtocol(port.protocol)
      else {}
      for c in deployment.spec.template.spec.containers
      for port in (c + container.withPortsMixin([])).ports
    ];
    local labels = {
      [x]: deployment.spec.template.metadata.labels[x]
      for x in std.objectFields(deployment.spec.template.metadata.labels)
      if std.count(ignored_labels, x) == 0
    };

    service.new(
      deployment.metadata.name,  // name
      labels,  // selector
      ports,
    ) +
    service.mixin.metadata.withLabels({ name: deployment.metadata.name }),

  // rbac creates a service account, role and role binding with the given
  // name and rules.
  rbac(name, rules, namespace):: {
    local clusterRole = k.rbac.v1.clusterRole,
    local clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
    local subject = k.rbac.v1.subject,
    local serviceAccount = k.core.v1.serviceAccount,

    service_account:
      serviceAccount.new(name),

    cluster_role:
      clusterRole.new() +
      clusterRole.mixin.metadata.withName(name) +
      clusterRole.withRules(rules),

    cluster_role_binding:
      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName(name) +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withKind('ClusterRole') +
      clusterRoleBinding.mixin.roleRef.withName(name) +
      clusterRoleBinding.withSubjects([
        subject.new() +
        subject.withKind('ServiceAccount') +
        subject.withName(name) +
        subject.withNamespace(namespace),
      ]),
  },

  namespacedRBAC(name, rules, namespace):: {
    local role = k.rbac.v1.role,
    local roleBinding = k.rbac.v1.roleBinding,
    local subject = k.rbac.v1.subject,
    local serviceAccount = k.core.v1.serviceAccount,

    service_account:
      serviceAccount.new(name) +
      serviceAccount.mixin.metadata.withNamespace(namespace),

    role:
      role.new() +
      role.mixin.metadata.withName(name) +
      role.mixin.metadata.withNamespace(namespace) +
      role.withRules(rules),

    cluster_role_binding:
      roleBinding.new() +
      roleBinding.mixin.metadata.withName(name) +
      roleBinding.mixin.metadata.withNamespace(namespace) +
      roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      roleBinding.mixin.roleRef.withKind('Role') +
      roleBinding.mixin.roleRef.withName(name) +
      roleBinding.withSubjects([
        subject.new() +
        subject.withKind('ServiceAccount') +
        subject.withName(name) +
        subject.withNamespace(namespace),
      ]),
  },

  // VolumeMount helper functions can be augmented with mixins.
  // For example, passing "volumeMount.withSubPath(subpath)" will result in
  // a subpath mixin.
  configVolumeMount(name, path, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(
      volumeMount.new(name, path) +
      volumeMountMixin,
    );

    deployment.mapContainers(addMount) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap(name, name),
    ]),

  // configMapVolumeMount adds a configMap to deployment-like objects.
  // It will also add an annotation hash to ensure the pods are re-deployed
  // when the config map changes.
  configMapVolumeMount(configMap, path, volumeMountMixin={})::
    local name = configMap.metadata.name,
          hash = std.md5(std.toString(configMap)),
          container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(
      volumeMount.new(name, path) +
      volumeMountMixin,
    );

    deployment.mapContainers(addMount) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap(name, name),
    ]) +
    deployment.mixin.spec.template.metadata.withAnnotationsMixin({
      ['%s-hash' % name]: hash,
    }),

  hostVolumeMount(name, hostPath, path, readOnly=false, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(
      volumeMount.new(name, path, readOnly=readOnly) +
      volumeMountMixin,
    );

    deployment.mapContainers(addMount) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromHostPath(name, hostPath),
    ]),

  secretVolumeMount(name, path, defaultMode=256, volumeMountMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(
      volumeMount.new(name, path) +
      volumeMountMixin,
    );

    deployment.mapContainers(addMount) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromSecret(name, secretName=name) +
      volume.mixin.secret.withDefaultMode(defaultMode),
    ]),

  emptyVolumeMount(name, path, volumeMountMixin={}, volumeMixin={})::
    local container = k.core.v1.container,
          deployment = k.apps.v1.deployment,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume,
          addMount(c) = c + container.withVolumeMountsMixin(
      volumeMount.new(name, path) +
      volumeMountMixin,
    );

    deployment.mapContainers(addMount) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromEmptyDir(name) + volumeMixin,
    ]),

  manifestYaml(value):: (
    local f = std.native('manifestYamlFromJson');
    f(std.toString(value))
  ),

  resourcesRequests(cpu, memory)::
    k.core.v1.container.mixin.resources.withRequests(
      (if cpu != null
       then { cpu: cpu }
       else {}) +
      (if memory != null
       then { memory: memory }
       else {})
    ),

  resourcesLimits(cpu, memory)::
    k.core.v1.container.mixin.resources.withLimits(
      (if cpu != null
       then { cpu: cpu }
       else {}) +
      (if memory != null
       then { memory: memory }
       else {})
    ),

  antiAffinity:
    {
      local deployment = k.apps.v1.deployment,
      local podAntiAffinity = deployment.mixin.spec.template.spec.affinity.podAntiAffinity,
      local name = super.spec.template.metadata.labels.name,

      spec+: podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution([
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.new() +
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.mixin.labelSelector.withMatchLabels({ name: name }) +
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.withTopologyKey('kubernetes.io/hostname'),
      ]).spec,
    },

  antiAffinityStatefulSet:
    {
      local statefulSet = k.apps.v1.statefulSet,
      local podAntiAffinity = statefulSet.mixin.spec.template.spec.affinity.podAntiAffinity,
      local name = super.spec.template.metadata.labels.name,

      spec+: podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution([
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.new() +
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.mixin.labelSelector.withMatchLabels({ name: name }) +
        podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecutionType.withTopologyKey('kubernetes.io/hostname'),
      ]).spec,
    },

  // Add a priority to the pods in a deployment (or deployment-like objects
  // such as a statefulset).
  local deployment = k.apps.v1.deployment,
  podPriority(p):
    deployment.mixin.spec.template.spec.withPriorityClassName(p),
};

util((import 'grafana.libsonnet')) + {
  withK(k):: util(k),
}

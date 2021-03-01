(import "bootstrap/bootstrap.libsonnet") +
(import "./ss.json") +
{
  _config+:: {
    runner+: {
      image: "raynix/github-runner-tanka:v0.3",
    }
  }
}

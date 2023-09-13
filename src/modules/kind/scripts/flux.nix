{ cluster }:

{
  flux-uninstall = ''
    set +e
    helm --kube-context kind-${cluster.name} uninstall flux

    kubectl --context kind-${cluster.name} delete ns \
      flux-system
    set -e
  '';
  flux-install = ''
    set +e
    helm --kube-context kind-${cluster.name} install --create-namespace \
      --values ${
        builtins.toFile "helm-values-argocd" cluster.features.flux.values
      } \
      --create-namespace \
      --replace \
      --force \
      --namespace flux-system flux \
      oci://ghcr.io/fluxcd-community/charts/flux2

    set -e
  '';
}

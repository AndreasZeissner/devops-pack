{ cluster, argocd, flux }:

rec {
  kind-clean = ''
    function kind_cluster_delete {
      kind delete cluster --name ${cluster.name}
    }
    trap kind_cluster_delete EXIT
  '';
  kind-install-ingress = ''
    kubectl --context kind-${cluster.name} apply \
      -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    kubectl --context kind-${cluster.name} wait \
      --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s

    kubectl --context kind-${cluster.name} apply \
      -f $PROJECT_ROOT/src/modules/kind/templates/ingress-nginx/pod.yaml
  '';
  kind-features-bootstrap = ''
    echo "bootrapping features"

    ${if cluster.ingress then ''
      ${kind-install-ingress}
    '' else ''
      echo "not installing ingress"
    ''}

    ${if cluster.features.argocd.enable then ''
      ${argocd.argocd-install}
    '' else ''
      ${argocd.argocd-uninstall}
    ''}

    ${if cluster.features.flux.enable then ''
      ${flux.flux-install}
    '' else ''
      ${flux.flux-uninstall}
    ''}
  '';
  kind-health-cmd = ''
    kubectl --context kind-${cluster.name} get cs
  '';
  kind-health = ''
    while true
    do 
      ${kind-health-cmd}
      sleep 10
    done
  '';
  kind-up = ''
    set -euo pipefail

    cat <<EOF | kind create cluster --name ${cluster.name} --config=-
    ${cluster.definition}
    EOF
  '';
}

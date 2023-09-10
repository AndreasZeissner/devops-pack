{ cluster }:

{
  argocd-install-example = ''
    argocd app create app-${cluster.name}-example \
      --repo https://github.com/AndreasZeissner/devops-pack.git \
      --path src/modules/kind/templates/argocd \
      --dest-namespace default \
      --dest-server https://kubernetes.default.svc \
      --auto-prune --revision main --self-heal \
      --directory-recurse
  '';
  argocd-uninstall = ''
    set +e
    kubectl --context kind-${cluster.name} delete ns \
      argocd
    set -e
  '';
  argocd-install = ''
    set +e

    helm repo add argo https://argoproj.github.io/argo-helm
    helm --kube-context kind-${cluster.name} install \
    --namespace argocd \
    --atomic \
    --create-namespace \
    --replace \
    --force \
    --values ${
      builtins.toFile "helm-values-argocd" cluster.features.argocd.values
    } \
    argo-cd argo/argo-cd

    ADMIN_PASSWORD=$(kubectl --context kind-${cluster.name} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    argocd --kube-context kind-${cluster.name} login localhost \
      --insecure \
      --username admin \
      --password $ADMIN_PASSWORD

    argocd --kube-context kind-${cluster.name} app create guestbook \
      --repo https://github.com/argoproj/argocd-example-apps.git \
      --path guestbook \
      --dest-namespace default \
      --dest-server https://kubernetes.default.svc \
      --directory-recurse

    argocd --kube-context kind-${cluster.name} app sync argocd/guestbook

    set -e
  '';
}

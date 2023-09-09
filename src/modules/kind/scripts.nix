{ cluster }:

rec {
  features = rec {
    argocd = ''
      set +e
      helm repo add argo https://argoproj.github.io/argo-helm
      helm --kube-context kind-${cluster.name} template \
      --namespace argocd \
      --atomic \
      --create-namespace \
      --replace \
      --values ${
        builtins.toFile "helm-values-argocd" cluster.features.argocd.values
      } \
      --dry-run \
      argo-cd argo/argo-cd

      helm --kube-context kind-${cluster.name} install \
      --namespace argocd \
      --atomic \
      --create-namespace \
      --replace \
      --values ${
        builtins.toFile "helm-values-argocd" cluster.features.argocd.values
      } \
      argo-cd argo/argo-cd

      kubectl --kube-context kind-${cluster.name} -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d

      # argocd login localhost \
      #   --insecure \
      #   --username admin \

      set -e
    '';
    bootstrap = ''
      echo "bootrapping features"

      ${if cluster.features.argocd.enable then ''
        ${features.argocd}
      '' else ''
        echo "feature argocd is disabled"
      ''}
    '';
  };
  kind-clean = ''
    function kind_cluster_delete {
      kind delete cluster --name ${cluster.name}
    }
    trap kind_cluster_delete EXIT
  '';
  kind-health = ''
    while true
    do 
      kubectl --context kind-${cluster.name} get cs
      sleep 10
    done
  '';
  kind-up = ''
    set -e
    set -u


    cat <<EOF | kind create cluster --name ${cluster.name} --config=-
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
      kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
      extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
    EOF

    kubectl --context kind-${cluster.name} apply \
      -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    sleep 30
    kubectl --context kind-${cluster.name} wait \
      --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s

    kubectl --context kind-${cluster.name} apply \
      -f $PROJECT_ROOT/src/modules/kind/templates/ingress-nginx/pod.yaml

    sleep 30
  '';
}

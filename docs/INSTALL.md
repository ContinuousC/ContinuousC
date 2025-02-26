```
export IP_ADDRESS=10.140.222.100
```


```
helm repo add metallb https://metallb.github.io/metallb
helm repo add jetstack https://charts.jetstack.io
helm repo add traefik https://traefik.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add cortex-helm https://cortexproject.github.io/cortex-helm-chart
```

```
helm install metallb --namespace metallb --create-namespace --version 0.14.9 metallb/metallb

kubectl apply -f- <<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb
EOF

kubectl apply -f- <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: pool
  namespace: metallb
spec:
  addresses:
    - "$IP_ADDRESS/32"
EOF

helm install cert-manager --namespace cert-manager --create-namespace --version 1.17.1 jetstack/cert-manager --set crds.enabled=true

helm install traefik --namespace traefik --create-namespace --version 34.4.0 traefik/traefik -f- <<EOF
providers.kubernetesCRD.allowCrossNamespace: true
ports.web.redirections.entryPoint:
  to: websecure
  schema: https
ports.websecure.http3.enabled: true
EOF

helm install minio-operator --namespace minio-operator --create-namespace --version 7.0.0 minio-operator/operator
helm install minio-tenant --namespace cortex --create-namespace --version 7.0.0 minio-operator/tenant -f- <<EOF
tenant.pools:
- name: cortex
  servers: 3
  volumesPerServer: 2
  size: 10Gi
  storageClassName: csi-rawfile-default
EOF

# kubectl port-forward -n cortex svc/myminio-console 9443:9443
# Create bucket cortex
# Edit values/cortex.yaml

helm install cortex --namespace cortex --version 2.5.0 cortex-helm/cortex -f values/cortex.yaml
```

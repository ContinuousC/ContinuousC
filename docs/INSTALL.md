```
export IP_ADDRESS=10.140.222.100
export PASSWORD=password
export DOMAIN=continuousc.com
export SSO_DOMAIN=sso.${DOMAIN}
export SSO_ADMIN_DOMAIN=admin-sso.${DOMAIN}
export AUTH_DOMAIN=app.${DOMAIN}
export OPENSEARCH_ADMIN_HASH_PASSWORD=$(htpasswd -bnBC10 '' $PASSWORD | sed -rne 's/^:(.+)$/\1/p')
export OIDC_CLIENT_SECRET=
export DOMAIN_CERT = 
```


```
helm repo add metallb https://metallb.github.io/metallb
helm repo add jetstack https://charts.jetstack.io
helm repo add traefik https://traefik.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add cortex-helm https://cortexproject.github.io/cortex-helm-chart
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
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
#TODO setup certificates + tls store

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
# Create buckets `cortex`, `alertmanager` and `ruler`
# Add user `cortex` and assign policies `readwrite` and `consoleAdmin`
# Edit values/cortex.yaml

helm install cortex --namespace cortex --version 2.5.0 cortex-helm/cortex -f values/cortex.yaml

helm install postgresql --namespace auth --create-namespace bitnami/postgresql --version 16.4.14 -f values/postgres.yaml --set auth.password=${PASSWORD}
#Edit values/keycloak.yaml for KEYCLOAK_ADMIN_PASSWORD, SSO_DOMAIN and SSO_ADMIN_DOMAIN in extraEnv
helm install keycloakx --namespace auth --create-namespace codecentric/keycloakx --version 7.0.1 -f values/keycloak.yaml --set database.password=${PASSWORD}
kubectl apply -f- <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: keycloak
  namespace: auth
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - kind: Rule
      match: Host(`$SSO_ADMIN_DOMAIN`)
      services:
        - name: keycloak-http
          port: http
    - kind: Rule
      match: "Host(`$SSO_DOMAIN`)
      services:
        - name: keycloak-http
          port: http
EOF

helm install oidc-client --namespace auth --create-namespace ghcr.io/continuousc/auth --version 0.0.0-acc.16 -f values/oidc-client.yaml --set auth.domain=${AUTH_DOMAIN} --set auth.oidc.issuer=${SSO_DOMAIN}/realms/continuousc --set auth.secrets.oidc-client-secret=${OIDC_CLIENT_SECRET} --set auth.secrets.keycloak-server-cert=${DOMAIN_CERT}

helm install c9c --namespace c9c-demo --create-namespace docker pull ghcr.io/continuousc/continuousc --version 0.0.5-acc.106 --set continuousc.registry=oci://ghcr.io/continuousc --set continuousc.domain=${DOMAIN} --set continuousc.secrets.opensearch-admin-password=${PASSWORD} --set continuousc.secrets.opensearch-admin-hash-password=${OPENSEARCH_ADMIN_HASH_PASSWORD} --set continuousc.secrets.grafana-postgresql-user-password=${PASSWORD}

helm install c9c-agent --namespace c9c-agent --create-namespace ghcr.io/continuousc/k8s-discovery-chart --version 0.0.8-acc.30 -f values/k8s-agent

```

```
export IP_ADDRESS=10.140.222.100
export PASSWORD=
export CA_DOMAIN_CERT = 
export CA_DOMAIN_KEY = 
export DOMAIN=continuousc.com
export SSO_DOMAIN=sso.${DOMAIN}
export SSO_ADMIN_DOMAIN=admin-sso.${DOMAIN}
export AUTH_DOMAIN=app.${DOMAIN}
export OPENSEARCH_ADMIN_HASH_PASSWORD=$(htpasswd -bnBC10 '' $PASSWORD | sed -rne 's/^:(.+)$/\1/p')
export MINIO_DOMAIN=minio.com
export MINIO_DOMAIN_CONSOLE=minio-console.com
export MINIO_ACCESS_KEY=
export OIDC_CLIENT_SECRET=
export CLUSTER_NAME = test-cluster
export OIDC_SERVICE_ACCOUNT=
export OIDC_SERVICE_ACCOUNT_SECRET=
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

# Generate CA_DOMAIN_CERT and CA_DOMAIN_KEY, see [link](https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/)

kubectl apply -f- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
  namespace: sandbox
data:
  tls.crt: {CA_DOMAIN_CERT}
  tls.key: ${CA_DOMAIN_KEY}
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: issuer
  namespace: traefik
spec:
  ca:
    secretName: ca-key-pair
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: certificate-ingress
  namespace: traefik
spec:
  secretName: certificate-ingress
  duration: 2160h0m0s
  renewBefore: 360h0m0s
  commonName: contc
  subject:
    organizations:
      - ContinuousC
    organizationalUnits:
      - Ingress
  usages:
    - server auth
    - digital signature
    - key encipherment
    - content commitment
  dnsNames:
    - ${DOMAIN}
    - ${SSO_DOMAIN}
    - ${SSO_ADMIN_DOMAIN}
    - ${AUTH_DOMAIN}
    - ${MINIO_DOMAIN_CONSOLE}
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  issuerRef:
    name: issuer
    kind: Issuer
    group: cert-manager.io
---
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: traefik
spec:
  defaultCertificate:
    secretName: certificate-ingress
EOF

helm install minio-operator --namespace minio-operator --create-namespace --version 7.0.0 minio-operator/operator
helm install minio-tenant --namespace cortex --create-namespace --version 7.0.0 minio-operator/tenant -f- <<EOF
tenant.pools:
- name: cortex
  servers: 3
  volumesPerServer: 2
  size: 10Gi
EOF

kubectl apply -f- <<EOF
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: minio-transport
  namespace: cortex
spec:
  insecureSkipVerify: true
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: minio
  namespace: cortex
spec:
  entryPoints:
  - web
  - websecure
  routes:
  - kind: Rule
    match: Host(`$MINIO_DOMAIN`)
    services:
    - name: minio
      port: 443
      scheme: https
      serversTransport: minio-transport
  - kind: Rule
    match: Host(`${MINIO_DOMAIN_CONSOLE}`)
    services:
    - name: selfmon-console
      port: 9443
      scheme: https
      serversTransport: minio-transport
  tls:
    domains:
    - main: $MINIO_DOMAIN
EOF
# Get credentials for minio console: kubectl get -n cortex secrets selfmon-user-0 -oyaml
# Go to MINIO_DOMAIN_CONSOLE with those credentials
# Create buckets `cortex`, `alertmanager` and `ruler`
# Add user `cortex` and set password MINIO_ACCESS_KEY
# Assign policies `consoleAdmin`

# Edit install-values/cortex.yaml for MINIO_ACCESS_KEY
helm install cortex --namespace cortex --version 2.5.0 cortex-helm/cortex -f install-values/cortex.yaml

# Edit install-values/postgres.yaml for PASSWORD
helm install postgresql --namespace auth --create-namespace bitnami/postgresql --version 16.4.14 -f install-values/postgres.yaml

#Edit install-values/keycloak.yaml for PASSWORD, SSO_DOMAIN and SSO_ADMIN_DOMAIN
helm install keycloakx --namespace auth --create-namespace codecentric/keycloakx --version 7.0.1 -f install-values/keycloak.yaml
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

#BEFORE CONTINUING, see docs 'keycloak settings' in Auth repo -> This will get you OIDC_CLIENT_SECRET, OIDC_SERVICE_ACCOUNT and OIDC_SERVICE_ACCOUNT_SECRET

# Edit install-values/oidc-client.yaml for AUTH_DOMAIN, SSO_DOMAIN, OIDC_CLIENT_SECRET and CA_DOMAIN_CERT
helm install oidc-client --namespace auth --create-namespace ghcr.io/continuousc/auth --version 0.0.0-acc.16 -f install-values/oidc-client.yaml

# Edit install-values/c9c-demo.yaml for DOMAIN, PASSWORD and OPENSEARCH_ADMIN_HASH_PASSWORD
helm install c9c --namespace c9c-demo --create-namespace docker pull ghcr.io/continuousc/continuousc --version 0.0.5-acc.106 -f install-values/c9c-demo.yaml

kubectl apply -f- <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: c9c-agent
---
apiVersion: v1
kind: Secret
metadata:
  name: oidc-service-account
  namespace: c9c-agent
stringData:
  secret: ${OIDC_SERVICE_ACCOUNT_SECRET}
EOF
#Edit install-values/k8s-agent.yaml for CA_DOMAIN_CERT, CLUSTER_NAME, DOMAIN, SSO_DOMAIN, OIDC_SERVICE_ACCOUNT
helm install c9c-agent --namespace c9c-agent --create-namespace ghcr.io/continuousc/k8s-discovery-chart --version 0.0.8-acc.30 -f install-values/k8s-agent.yaml
```

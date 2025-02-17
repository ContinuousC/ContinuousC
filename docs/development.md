# Development

## Install dependencies:

### devspace

```
npm install -g devspace

```

### argocd-vault-plugin

```
sudo curl -L https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.16.1/argocd-vault-plugin_1.16.1_linux_amd64 \
  -o argocd-vault-plugin && chmod +x argocd-vault-plugin && mv argocd-vault-plugin /usr/bin
```

## Configuration

### kubernetes

Access to kubernetes cluster by config in ~/.kube/config

### devspace

```
devspace use context                  # to select the right Kubernetes cluster
devspace use namespace $NAMESPACE     # namespace is unique working namespace in k8s cluster for a developer -> USE YOUR INITIALS
```

### vault

TODO:
should be done by a tool wich use a configuration file

For the moment:
Get a token for vault with access to your specific secrets in vault
~/.vaultrc.yaml with content:
AVP_TYPE: vault
AVP_AUTH_TYPE: token
VAULT_ADDR: https://vault.contc
VAULT_TOKEN: $TOKEN

### ssh to access rust registry

```
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub git@sigit01

```

### gitea.contc docker registry

```
docker login gitea.contc

```

### gitea.contc npm registry

```
npm config set @continuousc:registry https://gitea.contc/api/packages/continuousc/npm/
npm config set -- '//gitea.contc/api/packages/continuousc/npm/:_authToken' $ACCESS_TOKEN
```

### setup dns

Namespace is configured from devspace context
Normally you would develop with one tenant TENANT=demo

- "$NAMESPACE-app.continuousc.contc"
- "$TENANT.$NAMESPACE-app.continuousc.contc"

## Developing

```
devspace deploy
```

```
devspace dev
```

Login domain in must be run before running tenant domain, folder: /Auth
For tenant domain go to root folder, You will be asked to set a $TENANT

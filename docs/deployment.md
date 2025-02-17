In repo 'ControlPlane/Configuration' update $cluster-name/applications/$tenant-name.continuousc.yaml, example:

```
namespace: $tenant-name
helmChart:
  repository: https://gitea.contc/api/packages/ContinuousC/helm
  name: continuousc
  version: $helm-chart-version
  values:
    tenant:
      name: $tenant-name
```

Argocd will then deploy the application in the given cluster for the given tenant.

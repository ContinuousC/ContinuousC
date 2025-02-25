[![Build Status](https://drone.contc/api/badges/ContinuousC/ContinuousC/status.svg)](https://drone.contc/ContinuousC/ContinuousC)

# ContinuousC Architecture

[![Architecture Overview](ContinuousC%20architecture.svg)](https://excalidraw.com/#json=Nx9X3Iu7My9e-ZXnb8tbt,RszT-6qDpQM8lW01WyUwHw)

## Steps
1. Install external dependencies
2. Install internal dependencies
3. Install main chart (Components)
4. Install k8s discovery chart

## Dependencies 
### [MetalLB](https://metallb.io/) - Optional
  
MetallB is used to create an external load balancer for on prem k8s clusters.

### [Cert-Manager](https://cert-manager.io/)

Certificates management for our dbdaemon and relation graph; and for opensearch.

### [Traefik](https://doc.traefik.io/traefik/)

Traefik is our ingresscontroller that manage ingress in our cluster.  Make sure to enable http3 access in websecure and set allowCrossNamespace to true for kubernetesCRD, see [helm values example](./external/traefik-values.yaml). Also make sure to create the default TLSStore for the domain that will be set later for c9c chart, and for the keycloak domains.

### [Cortex](https://cortexproject.github.io/cortex-helm-chart/)

Long term storage for Prometheus. See [helm values example](./external/cortex-values.yaml). Change the backend config where needed

Analysis documents:

  - [Storage](Storage.pptx)
  - [Cortex Authentication and Multi-Tenancy](Cortex%20Authentication%20and%20Multi-Tenancy.pptx)

### Authentication
Our design decisions can be found [here](Authenticatie.pptx). 

#### Keycloak

We have setup our IAM solution with [Keycloak](https://www.keycloak.org/), see our custom [helm chart](./external/keycloak). Change in templates/recources the password in <>.

#### OIDC-client
[oidcclient](https://gitea.contc/ContinuousC/Auth/src/branch/main/docs) will handle our authentication flows. Here you can also find on how to configure Keycloak.

### [User Documentation](https://gitea.contc/ContinuousC/Documentation)

We use the framework [docusaurus](https://docusaurus.io/) to create our user documentation. You can find the analysis document [here](User%20Documentation.pptx)

## Components

### [Frontend](https://gitea.contc/ContinuousC/Frontend/src/branch/main/docs)

The frontend is built in React + Typescript. In a production build,
the bundled files are served by an nginx server. The frontend code
reuses code from the relation graph library through a webassembly
module (RelationGraph/wasm). For more info, refer to the frontend
documentation.

### [Relation Graph Engine](https://gitea.contc/ContinuousC/RelationGraph/src/branch/main/docs)

The Relation Graph Engine manages the entity graph as well as status
and alert information. Among other functions, it allows querying and
updating the entity graph. It keeps the current state of the entity
graph in memory to speed up queries and to allow transaction support
when updating the graph. For historical queries, it queries the
DBDaemon, which in turns queries Opensearch.

Analysis documents:

  - [Declarative relations](Declarative%20relations.pptx)
  - [Prometheus Metrics Schema](Prometheus%20Metrics%20Schema.pptx)
  - [Role-based authorization](Role-based%20authorization.pptx)

### [DBDaemon](https://gitea.contc/ContinuousC/DBDaemon/src/branch/main/docs)

The Database Daemon manages the connection to the elasticsearch
database, manages document versioning, ensures proper serialization of
concurrent requests and checks the schema of documents saved to the
database (with limited transformation support for backward compatible
schema updates).

### Jaeger Discovery

The Jaeger Discovery daemon reads trace data from Opensearch,
processes it to find Operations, Services and their relations, and
writes this information to the Relation Graph Engine.

### [Jaeger Anomaly Detection](https://gitea.contc/ContinuousC/JaegerAnomalyDetection/src/branch/main/docs)

The Jaeger Anomaly Detection daemon reads trace data from Opensearch
and calculates statistical variables over time on the metrics. The
results are written to Cortex via the Prometheus Remove Write
protocol.

Among other statistics produced, the Anomaly Score on a metric
reflects the measure in which the value of a metric over the short
term (immediate interval) lies within the variability of the metric
over the long term (reference interval). It is expressed as a factor,
with values of 1 and below indicating a "normal" situation (current
value equal or below the reference), and values (much) higher than 1
indicating an abnormality (current value (at least) x times higher
than "normal").

### [K8s agent](https://gitea.contc/ContinuousC/K8sDiscovery/src/branch/main/docs)

Consist of a k8s discovery agent to send discovery data to the
relation graph engine and a prometheus exporter to export metrics to
our cortex instance. This is not part of the main chart, but must be installed on K8s cluster to communicate with the relation graph engine.

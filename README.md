# README

A Helm chart for a PostgreSQL cluster with a PgPool frontend.

## 1.Prerequisites

### 1.1. Build and publish PgPool image

Build and tag the image for PgPool. Say, for example, we tag the image as `registry.internal:5000/pgpool:4`:

    docker build ./pgpool -f pgpool/Dockerfile -t registry.internal:5000/pgpool:4

Push the image to the respective registry:

    docker push registry.internal:5000/pgpool:4
 
### 1.2. Configure the Helm chart

Create a YAML file, say `values-local.yml`, to provide or override values from `values.yml`.

For password-related secrets, if not mentioned otherwise, we expect a single item named `password`. This can be created for example:

    kubectl create secret generic some-postgres-password --from-file=password=secrets/postgres-password

All values are documented inside `values.yml`.

### 1.3. Provide persistent volumes (PVs)

A set of PVs must be created to bind to PVCs from master/standby statefulsets.

There are 2 ways to achieve a predictable binding of PVCs to PVs:
  (a) defining a `claimRef` in a PV (which is created in advance) to match the expected PVC name
  (b) define selective `matchLabels` for PVs to match labels requested by generated PVCs

In any case, the storage class for a data/archive directory can be specified in `values.yaml` (default is `local-1` for data and `nfs-1` for archive).

#### 1.3.a. Provide a PV using a `claimRef`

The expected names for PVCs are deterministic (in the case of statefulsets), so we can prepare PVs that reference this expected PVC name (using `claimRef`). Note that selector labels (if requested at the PVC side) will be ignored if a `claimRef` is specified. On the contrary, requested storage classes must be respected.

The PVC names are:
 
 * `data-{{releaseName}}-master-0`: data directory for master (a single instance in the statefulset)
 * `archive-{{releaseName}}-master-0`:  archive directory where master stores WAL segments (and standby servers recover from them)
 * `data-{{releaseName}}-standby-{{ordinal}}`: data directory for a standby instance (`ordinal` comes from the statefulset)

An example for providing a PV for master data directory, for a Helm release named `postgres-c1`:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-c1-data-ac30a47d44f2
  labels:
    app.kubernetes.io/name: postgresql-cluster
    app.kubernetes.io/instance: postgres-c1
spec:
  storageClassName: local-1
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    namespace: default
    name: data-postgres-c1-master-0
  local:
    path: /data/postgres-c1/data-ac30a47d44f2
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube
```

#### 1.3.b. Provide a PV matching labels

The labels requested for the PVC for the data directory for the master (and similar for standby):
```yaml
app.kubernetes.io/name: postgresql-cluster
app.kubernetes.io/instance: {{releaseName}}
backend-role: master
```

The labels requested for the PVC for the archive directory for the master:
```yaml
app.kubernetes.io/name: postgresql-cluster
app.kubernetes.io/instance: {{releaseName}}
```

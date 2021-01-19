# README

A Helm chart for a PostgreSQL cluster with a PgPool frontend.

## 1.Prerequisites

### 1.1. Build and publish PgPool image

Build and tag the image for PgPool. Say, for example, we tag the image as `registry.internal:5000/pgpool:4`:

    docker build ./pgpool -f pgpool/Dockerfile -t registry.internal:5000/pgpool:4

Push the image to the respective registry:

    docker push registry.internal:5000/pgpool:4
 
### 1.2. Configure the Helm chart

Create a YAML file, say `values-local.yml`, to override values from `values.yml`.

For password-related secrets, if not mentioned otherwise, we expect a single item named `password`. This can be created for example:

    kubectl create secret generic some-postgres-password --from-file=password=secrets/postgres-password

The required values are described below:

    * `postgresPassword.secretName`: The name of a secret holding the password of `postgres` user (the administrator) for the database cluster
    * `replicationPassword.secretName`: The name of a secret holding the password of the replication-charged user (namely `replicator`) for the database cluster
    * `monitorPassword.secretName`: The name of a secret holding the password of a monitoring-charged user (namely `monitor`, member of `pg_monitor` group) for the database cluster
    * `pgpoolAdminPassword.secretName`: The name of a secret holding the password of `pgpool` user (the administrator) for PgPool
    * `userPasswords.secretName`:  The name of a secret holding a list of items of user credentials. Each item is named with the username and contains the password.
    * `pgpool.image`: The tag of the Docker image for PgPool (for example, the one provided at step `1.1`)
    * `pgpool.imagePullSecrets`: The name of a secret holding the authorization needed for fetching the PgPool image from the Docker registry. This value may be ommited in the case of a public registry. See also `kubectl explain pod.spec.imagePullSecrets`.
   

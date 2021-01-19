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


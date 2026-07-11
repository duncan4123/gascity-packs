# Native PostgreSQL Beads backend

This pack selects the PostgreSQL backend compiled into upstream `bd`. Gas City
uses one PostgreSQL database connection and derives a separate schema for each
city or rig bead scope. There is no external Beads backend-plugin process.

Requires a `bd` release with `bd init --backend=postgres` support and a local
PostgreSQL installation reachable through the current OS user's admin access.
With no URL configured, `gc init` creates the database, login role, generated
password, and city schema automatically. Set `GC_POSTGRES_ADMIN_URL` when local
admin access needs an explicit connection.

```toml
[imports.bd-native-postgres]
source = "../gascity-packs/bd-native-postgres"

[beads]
provider = "bd"
backend = "postgres"
# Optional: omit for automatic local provisioning.
postgres_url = "postgres://beads@127.0.0.1:5432/beads?sslmode=disable"
```

Omit `postgres_url` for automatic local provisioning. Set it only to use an
already-provisioned PostgreSQL database. Keep its password out of `city.toml`.
Provide the password through the upstream variable
`BEADS_PG_PASSWORD`, the compatibility variable `BEADS_POSTGRES_PASSWORD`, a
scope-local `.beads/.env` file with mode `0600`, or the Beads credentials file.

The city scope defaults to schema `hq`; rig schemas use their Gas City prefix.
Set `[beads].postgres_schema` only when the city scope needs an explicit name.
PostgreSQL does not provide Dolt history, remotes, or `bd dolt push/pull`.

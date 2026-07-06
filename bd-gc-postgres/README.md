# BD GC Postgres

`bd-gc-postgres` is a Gas City beads-backend plugin pack for a Postgres
backend-process plugin that conforms to the Beads backend plugin protocol from
our Beads plugin architecture PR.

The pack provides the setup/provider layer and a build command:

- builds `bd-backend-postgres` from the standalone plugin source containing
  `cmd/bd-backend-postgres`;
- runs that plugin's `init` method during `gc init`;
- writes `.beads/metadata.json` with `backend = "postgres"`,
  `postgres_dsn`, and `postgres_schema`;
- writes `.beads/config.local.yaml` with the trusted local plugin command.

The runtime shape matches `bd-gc-dl`: Beads from the plugin architecture PR
launches a trusted local plugin process over the `beads.backend.v1alpha1`
newline-delimited JSON protocol. The plugin owns direct Postgres access and
Beads core talks to it through the plugin adapter.

## Configuration

By default, `gc init --beads-backend postgres` provisions a local Postgres
database, login role, generated password, and city schema. The provider stores
the password in `.beads/.env`, writes redacted connection metadata to
`.beads/metadata.json`, and runs plugin init against that database.

Local provisioning uses `psql` through the current OS user's local Postgres
admin access. To use a specific admin connection, set:

```sh
export GC_POSTGRES_ADMIN_URL='postgres://postgres:admin-secret@127.0.0.1:5432/postgres?sslmode=disable'
```

Optional local provisioning overrides:

```sh
export GC_POSTGRES_DATABASE=my_city_beads
export GC_POSTGRES_USER=my_city_beads
export GC_POSTGRES_SCHEMA=my_city
export GC_POSTGRES_HOST=127.0.0.1
export GC_POSTGRES_PORT=5432
export GC_POSTGRES_PASSWORD=...
```

To use an already-provisioned Postgres database instead, set:

```sh
export GC_POSTGRES_URL='postgres://beads:secret@127.0.0.1:5432/beads?sslmode=disable'
export GC_POSTGRES_SCHEMA=my_city
```

The provider also accepts the upstream Beads names:

```sh
export BEADS_POSTGRES_URL='postgres://beads:secret@127.0.0.1:5432/beads?sslmode=disable'
export BEADS_POSTGRES_SCHEMA=my_city
```

The plugin redacts any password in the init URL before writing
`.beads/metadata.json`. For runtime commands, prefer:

```sh
export GC_POSTGRES_PASSWORD=...
```

or the upstream Beads variable:

```sh
export BEADS_PG_PASSWORD=...
```

The provider exports `GC_POSTGRES_PASSWORD` as `BEADS_PG_PASSWORD` while running
plugin init. For local provisioning, it persists the generated password in
`.beads/.env` so trusted Beads and GC commands can reconnect through the plugin.

## Build

```sh
gc bd-gc-postgres build backend --install \
  --plugin-source /data/projects/doltlite-gascity/rigs/beads-backend-postgres-plugin
```

The default local plugin source is
`$BD_GC_POSTGRES_PLUGIN_SOURCE` when set. Otherwise the build command clones
`https://github.com/duncan4123/beads-backend-postgres.git` into the city cache
and builds from that checkout.

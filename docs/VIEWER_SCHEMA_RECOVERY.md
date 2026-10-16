# Viewer schema recovery

`Meme catalog registration unavailable` with `PG::UndefinedTable` indicates
catalog registration could not find a relation. Browsing may still return 200,
but exact sharing is unavailable. It does not prove why an image or Next failed.

In a trusted shell with the same DATABASE_URL (or POSTGRES_URL) and search path
as the web service, run:

```sh
bundle exec ruby scripts/check_viewer_schema.rb
```

This defaults to read-only table-existence checks: exit 0 means all three tables
are visible, exit 2 means tables are missing, exit 1 means connection/SQL failure.
Presence alone does not prove correct columns, indexes or permissions.

After a database backup/snapshot and migration review, explicitly apply only the
catalog and impression migrations:

```sh
bundle exec ruby scripts/check_viewer_schema.rb --apply
bundle exec ruby scripts/check_viewer_schema.rb
```

The two additive/idempotent files run in one transaction with bounded lock and
statement timeouts. Existing content is not rewritten. Never run the full schema
file as a production repair. No migration runs automatically at application boot.

Verify new Share links and impression acknowledgments in a browser afterward.
Do not drop these tables to roll back application code; preserve registered links
and engagement data. If checks pass but UndefinedTable persists, compare the web
service's actual database/search path privately. Do not paste database credentials.

These commands have been validated locally, not executed against production.
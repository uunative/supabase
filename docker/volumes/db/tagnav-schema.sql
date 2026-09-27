-- TagNav application schema.
-- Applied on first container start via docker-entrypoint-initdb.d (see docker-compose.yml).
-- Reconciled against the app's actual Dexie/IndexedDB schema (src/services/db.ts, src/types.ts)
-- as of the self-hosted Supabase migration — see tag_navigator/SUPABASE_MIGRATION_PLAN.md
-- and the migration plan for the full reconciliation notes.

create extension if not exists pgcrypto;

create table artifacts (
  id text primary key,
  owner_id uuid not null default auth.uid(),
  type text not null check (type in ('bookmark','document','note','video','image')),
  title text not null,
  url text,
  storage_uri text,
  thumbnail text,
  html_snapshot text,
  snapshot_taken_at timestamptz,
  published_date timestamptz,
  tags text[] not null default '{}',
  notes text,
  favorite boolean default false,
  sort_order integer,
  created_at timestamptz not null default now(),
  last_accessed_at timestamptz not null default now(),
  -- nullable: unlike tags.last_modified, this field is never actually set on
  -- most artifacts client-side (declared optional in the Artifact type) — a
  -- bulk upsert batch mixing artifacts with/without it sends explicit JSON
  -- null for the ones missing it, which a NOT NULL column would reject.
  last_modified timestamptz default now(),
  ai_recommended_tags text[],
  groups text[] default '{}'
);
create index idx_artifacts_tags on artifacts using gin(tags);
create index idx_artifacts_groups on artifacts using gin(groups);
create index idx_artifacts_owner on artifacts(owner_id);
create index idx_artifacts_fts on artifacts using gin(
  to_tsvector('english', coalesce(title,'') || ' ' || coalesce(notes,'')));

create table tags (
  canonical text primary key,
  owner_id uuid not null default auth.uid(),
  display text not null,
  color text,
  parent_tag text references tags(canonical) on delete set null,
  is_root boolean default false,
  created_at timestamptz not null default now(),
  last_modified timestamptz not null default now()
);

create table collections (
  id text primary key,
  owner_id uuid not null default auth.uid(),
  name text not null,
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table projects (
  id text primary key,
  owner_id uuid not null default auth.uid(),
  name text not null,
  description text,
  artifact_ids text[] not null default '{}',
  tasks jsonb not null default '[]',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table settings (
  owner_id uuid not null default auth.uid(),
  key text not null,
  -- nullable: some settings are legitimately null (e.g. "no default tag set"),
  -- distinct from the row not existing yet (which getSetting() treats as "use the caller's default").
  value jsonb,
  primary key (owner_id, key)
);

alter table artifacts enable row level security;
alter table tags enable row level security;
alter table collections enable row level security;
alter table projects enable row level security;
alter table settings enable row level security;

create policy owner_all on artifacts for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy owner_all on tags for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy owner_all on collections for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy owner_all on projects for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy owner_all on settings for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

alter publication supabase_realtime add table artifacts, tags, collections, projects;

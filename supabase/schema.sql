-- Kitten Office database. Run once in the Supabase SQL editor (or via the API).
-- Security model:
--   * Nobody can read or write the tables directly (RLS on, no policies, grants revoked).
--   * Hooks write through report_agent(), which needs the WRITER key.
--   * The iPad page reads through get_agents(), which needs the VIEWER key.
--   * Only bcrypt hashes of the keys are stored. The keys themselves are never committed.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.agents (
  id          text primary key check (char_length(id) <= 100), -- Claude Code session id
  project     text not null default '',
  machine     text not null default 'mac' check (machine in ('mac', 'cloud')),
  state       text not null check (state in ('working', 'waiting', 'done', 'ended')),
  task        text not null default '',  -- what the page shows
  prompt      text not null default '',  -- last thing you asked, shown again when work resumes
  state_since timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.agents enable row level security;
revoke all on table public.agents from anon, authenticated;

create table if not exists public.app_keys (
  name     text primary key check (name in ('writer', 'viewer')),
  key_hash text not null
);
alter table public.app_keys enable row level security;
revoke all on table public.app_keys from anon, authenticated;

create or replace function public.key_ok(p_name text, p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.app_keys k
    where k.name = p_name and k.key_hash = extensions.crypt(p_key, k.key_hash)
  );
$$;
revoke execute on function public.key_ok(text, text) from public, anon, authenticated;

-- Called by the Claude Code hook. Empty p_task means "keep what was there".
create or replace function public.report_agent(
  p_key text, p_id text, p_state text,
  p_project text default null, p_machine text default null, p_task text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  t text := nullif(left(coalesce(p_task, ''), 200), '');
begin
  if p_key is null or not public.key_ok('writer', p_key) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  insert into public.agents as a (id, project, machine, state, task, prompt)
  values (left(p_id, 100), left(coalesce(p_project, ''), 80), coalesce(p_machine, 'mac'), p_state,
          coalesce(t, ''), case when p_state = 'working' then coalesce(t, '') else '' end)
  on conflict (id) do update set
    project     = coalesce(nullif(left(p_project, 80), ''), a.project),
    machine     = coalesce(p_machine, a.machine),
    prompt      = case when p_state = 'working' and t is not null then t else a.prompt end,
    task        = coalesce(t, case when p_state = 'working' and a.prompt <> '' then a.prompt else a.task end),
    state_since = case when a.state is distinct from p_state then now() else a.state_since end,
    state       = p_state,
    updated_at  = now();

  -- Tidy up: forget ended sessions after 10 minutes and anything silent for a day.
  delete from public.agents
  where updated_at < now() - interval '1 day'
     or (state = 'ended' and updated_at < now() - interval '10 minutes');
end $$;

-- Called by the iPad page every couple of seconds.
create or replace function public.get_agents(p_key text)
returns table (id text, project text, machine text, state text, task text, state_since timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_key is null or not public.key_ok('viewer', p_key) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select a.id, a.project, a.machine, a.state, a.task, a.state_since
    from public.agents a
    where a.updated_at > now() - interval '12 hours'
    order by a.state_since;
end $$;

revoke execute on function public.report_agent(text, text, text, text, text, text) from public;
revoke execute on function public.get_agents(text) from public;
grant execute on function public.report_agent(text, text, text, text, text, text) to anon;
grant execute on function public.get_agents(text) to anon;

-- Keys are set separately (never commit them):
--   insert into public.app_keys values
--     ('writer', extensions.crypt('<writer key>', extensions.gen_salt('bf'))),
--     ('viewer', extensions.crypt('<viewer key>', extensions.gen_salt('bf')))
--   on conflict (name) do update set key_hash = excluded.key_hash;

-- Zombie Defense 100: public Top-10 leaderboard
-- Casual leaderboard design: public read + public insert with strict CHECK constraints.
-- This does not make browser-submitted scores cheat-proof. For competitive use, route
-- submissions through a server/Edge Function with additional verification.

create table if not exists public.leaderboard (
  id bigint generated always as identity primary key,
  nickname text not null check (
    char_length(nickname) between 2 and 12
    and nickname ~ '^[A-Za-z0-9가-힣_]+$'
  ),
  score bigint not null check (score between 0 and 999999999),
  max_round smallint not null check (max_round between 1 and 100),
  kills integer not null check (kills between 0 and 1000000),
  created_at timestamptz not null default now()
);

create index if not exists leaderboard_order_idx
on public.leaderboard (score desc, max_round desc, kills desc, created_at asc);

alter table public.leaderboard enable row level security;

revoke all on table public.leaderboard from anon, authenticated;
grant select, insert on table public.leaderboard to anon, authenticated;
grant usage, select on sequence public.leaderboard_id_seq to anon, authenticated;

drop policy if exists "leaderboard_public_read" on public.leaderboard;
create policy "leaderboard_public_read"
on public.leaderboard
for select
to anon, authenticated
using (true);

drop policy if exists "leaderboard_public_insert" on public.leaderboard;
create policy "leaderboard_public_insert"
on public.leaderboard
for insert
to anon, authenticated
with check (
  score between 0 and 999999999
  and max_round between 1 and 100
  and kills between 0 and 1000000
);

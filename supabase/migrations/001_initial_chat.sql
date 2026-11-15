-- Dear Diary: initial direct-message schema. Apply in a NEW Supabase development
-- project using the SQL Editor or `supabase db push` after linking the project.
-- Then enable Realtime replication for friend_requests, conversations, messages,
-- and message_receipts in the dashboard (or a reviewed publication migration).
-- Configure Auth separately. Use the public/publishable client key only; never
-- put a service-role key in a client. Exercise RLS with distinct authenticated
-- users and anonymous requests before using a real project.
--
-- IMPORTANT: message bodies are PLAINTEXT to the database/provider. This schema
-- provides authorization and transport support, NOT end-to-end encryption.
-- Do not use it for sensitive messages until a reviewed E2EE design, device-key
-- verification and recovery are implemented. No app PIN is stored here.

begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  username_normalized text generated always as (lower(username)) stored unique,
  updated_at timestamptz not null default now()
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  user_low uuid generated always as (least(requester_id, recipient_id)) stored,
  user_high uuid generated always as (greatest(requester_id, recipient_id)) stored,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> recipient_id),
  unique (user_low, user_high)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_low < user_high),
  unique (user_low, user_high)
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (conversation_id, user_id)
);
create index conversation_members_by_user on public.conversation_members (user_id, conversation_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  client_message_id uuid not null,
  body text not null check (char_length(btrim(body)) between 1 and 10000),
  sent_at timestamptz not null default now(),
  unique (sender_id, client_message_id)
);
create index messages_by_conversation_time on public.messages (conversation_id, sent_at, id);

create table public.message_receipts (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  delivered_at timestamptz not null,
  read_at timestamptz,
  primary key (message_id, user_id),
  check (read_at is null or read_at >= delivered_at)
);

-- Diary bodies are plaintext on the server in this initial development schema.
-- A share begins pending; its recipient can read an entry only after accepting.
create table public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 100000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);
create index diary_entries_by_owner on public.diary_entries (owner_id, updated_at desc);

create table public.diary_shares (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  permission text not null default 'read' check (permission = 'read'),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  revoked_at timestamptz,
  check (owner_id <> recipient_id),
  foreign key (entry_id, owner_id) references public.diary_entries(id, owner_id) on delete cascade,
  unique (entry_id, recipient_id)
);
create index diary_shares_by_recipient on public.diary_shares (recipient_id, entry_id);

alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_receipts enable row level security;
alter table public.diary_entries enable row level security;
alter table public.diary_shares enable row level security;

-- Functions execute as the migration owner to make multi-table writes atomic.
-- Every function has a fixed empty search_path, fully qualified object names,
-- and checks auth.uid(). The caller never gets direct table write permissions.
create function public.is_conversation_member(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.conversation_members m
    join public.conversations c on c.id = m.conversation_id
    join public.friend_requests r on r.user_low = c.user_low and r.user_high = c.user_high
    where m.conversation_id = p_conversation_id and m.user_id = auth.uid() and r.status = 'accepted'
  );
$$;

create function public.is_friend(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.friend_requests r
    where r.status = 'accepted'
      and r.user_low = least(auth.uid(), p_user_id)
      and r.user_high = greatest(auth.uid(), p_user_id)
  );
$$;

-- Signup creates a profile only when the new Auth user supplies username
-- metadata. OAuth accounts without it call set_username after signing in.
-- No auth.users are created by this migration. Duplicate/invalid usernames
-- reject that signup; the caller must ask for another name.
create function public.create_profile_from_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_username text := new.raw_user_meta_data ->> 'username';
begin
  if v_username is not null and v_username <> '' then
    if v_username !~ '^[A-Za-z0-9_]{3,24}$' then
      raise exception 'Invalid username' using errcode = '22023';
    end if;
    insert into public.profiles (id, username) values (new.id, v_username);
  end if;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.create_profile_from_signup();

create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or exists (
    select 1 from public.friend_requests r where r.status in ('pending', 'accepted')
      and r.user_low = least(auth.uid(), profiles.id) and r.user_high = greatest(auth.uid(), profiles.id)
  ));
create policy requests_read on public.friend_requests for select to authenticated
  using (requester_id = auth.uid() or recipient_id = auth.uid());
create policy conversations_read on public.conversations for select to authenticated
  using (public.is_conversation_member(id));
create policy members_read on public.conversation_members for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy messages_read on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));
create policy receipts_read on public.message_receipts for select to authenticated
  using (exists (select 1 from public.messages m where m.id = message_id
    and public.is_conversation_member(m.conversation_id)));
create policy diary_shares_read on public.diary_shares for select to authenticated
  using (owner_id = auth.uid() or recipient_id = auth.uid());
create policy diary_entries_read on public.diary_entries for select to authenticated
  using (owner_id = auth.uid() or exists (
    select 1 from public.diary_shares s
    where s.entry_id = diary_entries.id and s.recipient_id = auth.uid()
      and s.accepted_at is not null and s.revoked_at is null
      and public.is_friend(s.owner_id)
  ));

-- Claim/change a unique case-insensitive handle. Stable user_id, friendships and
-- conversations survive username changes. Handle lookup is exact, not directory search.
create function public.set_username(p_username text)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_profile public.profiles;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_username is null or p_username !~ '^[A-Za-z0-9_]{3,24}$' then
    raise exception 'Username must be 3-24 ASCII letters, digits or underscores' using errcode = '22023';
  end if;
  insert into public.profiles (id, username) values (v_uid, p_username)
  on conflict (id) do update set username = excluded.username, updated_at = now()
  returning * into v_profile;
  return v_profile;
end;
$$;

-- Exact username requests can reveal whether a name exists; apply abuse/rate
-- limits at an authenticated server/API layer before public release.
create function public.send_friend_request(p_username text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_recipient uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'Set a username first' using errcode = '22023';
  end if;
  if p_username is null or p_username !~ '^[A-Za-z0-9_]{3,24}$' then
    raise exception 'Invalid username' using errcode = '22023';
  end if;
  select id into v_recipient from public.profiles where username_normalized = lower(p_username);
  if v_recipient is null or v_recipient = v_uid then
    raise exception 'Request cannot be sent' using errcode = '22023';
  end if;
  insert into public.friend_requests (requester_id, recipient_id)
  values (v_uid, v_recipient)
  on conflict (user_low, user_high) do update
    set requester_id = excluded.requester_id, recipient_id = excluded.recipient_id,
        status = 'pending', created_at = now(), updated_at = now()
    where public.friend_requests.status = 'declined'
  returning id into v_id;
  if v_id is null then raise exception 'Request already exists' using errcode = '23505'; end if;
  return v_id;
end;
$$;

create function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_request public.friend_requests; v_conversation uuid;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_accept is null then raise exception 'Response required' using errcode = '22023'; end if;
  select * into v_request from public.friend_requests
    where id = p_request_id and recipient_id = v_uid and status = 'pending' for update;
  if not found then raise exception 'Pending request not found' using errcode = '42501'; end if;
  update public.friend_requests set status = case when p_accept then 'accepted' else 'declined' end,
    updated_at = now() where id = v_request.id;
  if not p_accept then return null; end if;
  insert into public.conversations (user_low, user_high)
    values (v_request.user_low, v_request.user_high)
    on conflict (user_low, user_high) do update set user_low = excluded.user_low
    returning id into v_conversation;
  insert into public.conversation_members (conversation_id, user_id)
    values (v_conversation, v_request.user_low), (v_conversation, v_request.user_high)
    on conflict do nothing;
  return v_conversation;
end;
$$;

-- Ending a friendship removes access through RLS while keeping the shared
-- conversation and message rows. A new accepted request between the same pair
-- reuses this conversation, so the history is available again.
create function public.end_friendship(p_other_user_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or p_other_user_id is null or p_other_user_id = v_uid then
    raise exception 'Invalid friendship' using errcode = '42501';
  end if;
  update public.friend_requests
    set status = 'declined', updated_at = now()
    where status = 'accepted'
      and user_low = least(v_uid, p_other_user_id)
      and user_high = greatest(v_uid, p_other_user_id);
  return found;
end;
$$;

create function public.send_message(p_conversation_id uuid, p_client_message_id uuid, p_body text)
returns public.messages language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_message public.messages;
begin
  if v_uid is null or not public.is_conversation_member(p_conversation_id) then
    raise exception 'Not a conversation member' using errcode = '42501';
  end if;
  if p_client_message_id is null or p_body is null or char_length(btrim(p_body)) not between 1 and 10000 then
    raise exception 'Invalid message' using errcode = '22023';
  end if;
  insert into public.messages (conversation_id, sender_id, client_message_id, body)
    values (p_conversation_id, v_uid, p_client_message_id, p_body)
    on conflict (sender_id, client_message_id) do nothing returning * into v_message;
  if v_message.id is null then
    select * into v_message from public.messages
      where sender_id = v_uid and client_message_id = p_client_message_id;
    if v_message.conversation_id <> p_conversation_id or v_message.body <> p_body then
      raise exception 'Message id already used for different content' using errcode = '23505';
    end if;
  end if;
  return v_message;
end;
$$;

-- Receipt is a client acknowledgement, not proof of delivery or human reading.
-- Only the recipient can acknowledge a message. All times are server assigned.
create function public.acknowledge_message(p_message_id uuid, p_read boolean default false)
returns public.message_receipts language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_message public.messages; v_receipt public.message_receipts; v_now timestamptz := clock_timestamp();
begin
  if v_uid is null or p_read is null then raise exception 'Invalid request' using errcode = '42501'; end if;
  select * into v_message from public.messages where id = p_message_id;
  if v_message.id is null or v_message.sender_id = v_uid or not public.is_conversation_member(v_message.conversation_id) then
    raise exception 'Message unavailable' using errcode = '42501';
  end if;
  insert into public.message_receipts (message_id, user_id, delivered_at, read_at)
    values (p_message_id, v_uid, v_now, case when p_read then v_now else null end)
    on conflict (message_id, user_id) do update
      set read_at = case when excluded.read_at is null then public.message_receipts.read_at
        else coalesce(public.message_receipts.read_at, greatest(public.message_receipts.delivered_at, excluded.read_at)) end
    returning * into v_receipt;
  return v_receipt;
end;
$$;

create function public.save_diary_entry(p_entry_id uuid, p_body text)
returns public.diary_entries language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_entry public.diary_entries;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_entry_id is null or p_body is null or char_length(p_body) > 100000 then
    raise exception 'Invalid diary entry' using errcode = '22023';
  end if;
  insert into public.diary_entries (id, owner_id, body) values (p_entry_id, v_uid, p_body)
  on conflict (id) do update set body = excluded.body, updated_at = now()
    where public.diary_entries.owner_id = v_uid returning * into v_entry;
  if v_entry.id is null then raise exception 'Entry unavailable' using errcode = '42501'; end if;
  return v_entry;
end;
$$;

create function public.share_diary_entry(p_entry_id uuid, p_recipient_id uuid)
returns public.diary_shares language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_share public.diary_shares;
begin
  if v_uid is null or p_recipient_id is null or p_recipient_id = v_uid
      or not exists (select 1 from public.diary_entries where id = p_entry_id and owner_id = v_uid) then
    raise exception 'Entry or recipient unavailable' using errcode = '42501';
  end if;
  -- Lock friendship first so a concurrent unfriend cannot miss revocation.
  perform 1 from public.friend_requests where status = 'accepted'
    and user_low = least(v_uid, p_recipient_id) and user_high = greatest(v_uid, p_recipient_id) for update;
  if not found then raise exception 'Entry or recipient unavailable' using errcode = '42501'; end if;
  insert into public.diary_shares (entry_id, owner_id, recipient_id)
    values (p_entry_id, v_uid, p_recipient_id)
    on conflict (entry_id, recipient_id) do update set created_at = now(), accepted_at = null, revoked_at = null
      where public.diary_shares.revoked_at is not null returning * into v_share;
  if v_share.id is null then
    select * into v_share from public.diary_shares where entry_id = p_entry_id and recipient_id = p_recipient_id;
  end if;
  return v_share;
end;
$$;

create function public.respond_diary_share(p_share_id uuid, p_accept boolean)
returns public.diary_shares language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_owner uuid; v_share public.diary_shares;
begin
  if v_uid is null or p_accept is null then raise exception 'Invalid request' using errcode = '42501'; end if;
  select owner_id into v_owner from public.diary_shares
    where id = p_share_id and recipient_id = v_uid and accepted_at is null and revoked_at is null;
  if v_owner is null then raise exception 'Pending share unavailable' using errcode = '42501'; end if;
  perform 1 from public.friend_requests where status = 'accepted'
    and user_low = least(v_uid, v_owner) and user_high = greatest(v_uid, v_owner) for update;
  if not found then raise exception 'Pending share unavailable' using errcode = '42501'; end if;
  update public.diary_shares set accepted_at = case when p_accept then now() else null end,
      revoked_at = case when p_accept then null else now() end
    where id = p_share_id and recipient_id = v_uid and accepted_at is null and revoked_at is null
      and owner_id = v_owner returning * into v_share;
  if v_share.id is null then raise exception 'Pending share unavailable' using errcode = '42501'; end if;
  return v_share;
end;
$$;

create function public.revoke_diary_share(p_share_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  update public.diary_shares set revoked_at = now()
    where id = p_share_id and owner_id = v_uid and revoked_at is null;
  return found;
end;
$$;

-- Future unfriend/block functions must change/delete the accepted request in the
-- same transaction. This trigger revokes shares in BOTH directions while leaving
-- each owner's diary entries intact; renewed friendship does not revive old shares.
create function public.revoke_shares_on_friendship_end()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'accepted' then
    if tg_op = 'DELETE' then
      update public.diary_shares set revoked_at = now() where revoked_at is null
        and least(owner_id, recipient_id) = old.user_low and greatest(owner_id, recipient_id) = old.user_high;
    elsif new.status <> 'accepted' then
      update public.diary_shares set revoked_at = now() where revoked_at is null
        and least(owner_id, recipient_id) = old.user_low and greatest(owner_id, recipient_id) = old.user_high;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger friendship_end_update after update of status on public.friend_requests
  for each row execute function public.revoke_shares_on_friendship_end();
create trigger friendship_end_delete after delete on public.friend_requests
  for each row execute function public.revoke_shares_on_friendship_end();

revoke all on public.profiles, public.friend_requests, public.conversations,
  public.conversation_members, public.messages, public.message_receipts, public.diary_entries,
  public.diary_shares from public, anon, authenticated;
grant select on public.profiles, public.friend_requests, public.conversations,
  public.conversation_members, public.messages, public.message_receipts, public.diary_entries,
  public.diary_shares to authenticated;

revoke all on function public.is_conversation_member(uuid), public.is_friend(uuid),
  public.set_username(text), public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean), public.send_message(uuid, uuid, text),
  public.end_friendship(uuid),
  public.acknowledge_message(uuid, boolean), public.save_diary_entry(uuid, text),
  public.share_diary_entry(uuid, uuid), public.respond_diary_share(uuid, boolean),
  public.revoke_diary_share(uuid), public.create_profile_from_signup(),
  public.revoke_shares_on_friendship_end() from public, anon, authenticated;
grant execute on function public.is_conversation_member(uuid), public.is_friend(uuid),
  public.set_username(text), public.send_friend_request(text),
  public.respond_friend_request(uuid, boolean), public.send_message(uuid, uuid, text),
  public.end_friendship(uuid),
  public.acknowledge_message(uuid, boolean), public.save_diary_entry(uuid, text),
  public.share_diary_entry(uuid, uuid), public.respond_diary_share(uuid, boolean),
  public.revoke_diary_share(uuid) to authenticated;

commit;

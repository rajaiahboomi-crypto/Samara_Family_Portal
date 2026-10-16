-- Family Portal: existing tube feeds for the session's own guest only.
begin;
create or replace function public.family_portal_tube_feeds(p_session_token text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare d jsonb; pid uuid;
begin
 if coalesce(trim(p_session_token),'')='' then return '[]'::jsonb; end if;
 d := public.family_portal_dashboard(p_session_token);
 if d is null or jsonb_typeof(d)<>'object' then return '[]'::jsonb; end if;
 pid := nullif(d->'patient'->>'patient_uuid','')::uuid;
 if pid is null then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',e.id,'entry_at',e.entry_at,'item',e.item,'volume_ml',e.volume_ml
 ) order by e.entry_at desc,e.id)
 from public.io_entries e
 where e.patient_id=pid and e.direction='Intake' and e.category='Tube feed'
   and not e.voided and e.entry_at>=now()-interval '120 days'), '[]'::jsonb);
end $$;
revoke all on function public.family_portal_tube_feeds(text) from public;
grant execute on function public.family_portal_tube_feeds(text) to anon, authenticated;
notify pgrst, 'reload schema';
commit;
select public.family_portal_tube_feeds('')='[]'::jsonb as empty_session_blocked,
 public.family_portal_tube_feeds('invalid-session-check')='[]'::jsonb as invalid_session_blocked;

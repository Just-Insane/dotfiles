import {captureEnvelope} from './capture-envelope.mjs';
const bytes = value => Buffer.byteLength(JSON.stringify(value));
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const MAX_PAGE = 1_000_000;
function decode(raw, account, conversation) {
  if (raw === undefined) return null;
  if (typeof raw !== 'string' || raw.length > 8192 || !/^[A-Za-z0-9_-]+$/.test(raw)) throw Error();
  const c = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
  if (c.v !== 1 || c.account !== account || c.conversation !== conversation ||
      Object.keys(c).sort().join(',') !== 'account,after,conversation,v' ||
      typeof c.after !== 'string' || !c.after || c.after.length > 4096) throw Error();
  return c.after;
}
/** Opt-in bounded cache enumeration. No file/network access or provider writes. */
export function enumerationEnvelope(view, tool, args, now) {
  if (!args.capture || !['list_conversations','read_conversation'].includes(tool)) return undefined;
  const schema = tool === 'list_conversations' ? 'teams-cache-conversations/v1' : 'teams-cache-messages/v1';
  const unavailable = reason => ({schema,status:'unavailable',reason});
  if (!view.meta.schemaMatched) return unavailable('schema_unrecognized');
  const account = view.meta.selfMri;
  if (!account || account !== args.expected_account_id) return unavailable('account_mismatch');
  if (['since','until','kind','query','participant','cursor','reactions'].some(k => args[k] !== undefined))
    return unavailable('capture_filters_unsupported');
  const conversation = tool === 'read_conversation' ? args.expected_conversation_id : null;
  if (conversation !== null && (typeof conversation !== 'string' || !conversation || conversation.length > 2048))
    return unavailable('identity_unavailable');
  let after;
  try { after = decode(args.capture_cursor, account, conversation); }
  catch { return unavailable('cursor_invalid'); }
  const common = {schema,status:'observed',account_id:account,
    observed_at:new Date(now).toISOString(),cache_as_of:Number.isSafeInteger(view.meta.asOf) && view.meta.asOf > 0 ? new Date(view.meta.asOf).toISOString() : null,
    may_be_stale:!!view.mayBeStale,lossy:!!view.meta.lossy,provider_complete:false,gaps:[]};
  const cursor = last => encode({v:1,account,conversation,after:last});
  if (tool === 'list_conversations') {
    const n = args.n ?? 30;
    if (!Number.isInteger(n) || n < 1 || n > 30) return unavailable('limit_invalid');
    const rows = view.conversations.list({n:n+1,includeEmpty:true,captureAfter:after ?? '',captureOrder:true});
    if (rows.some((r,i) => !r.id || typeof r.id !== 'string' || r.id.length > 2048 ||
        (after !== null && Buffer.compare(Buffer.from(r.id),Buffer.from(after)) <= 0) || (i && Buffer.compare(Buffer.from(r.id),Buffer.from(rows[i-1].id)) <= 0))) return unavailable('enumeration_order_invalid');
    const selected = rows.slice(0,n);
    const result = {...common,conversations:selected.map(r=>({conversation_id:r.id,conversation:r.handle,kind:r.kind})),
      next_cursor:rows.length > n ? cursor(selected.at(-1).id) : null,cache_complete:rows.length <= n};
    return bytes(result) <= MAX_PAGE ? result : unavailable('page_too_large');
  }
  // Native identity is authoritative; display handles can change after refresh.
  const current = view.conversations.get(conversation);
  if (!current) return {...common,conversation_id:conversation,messages:[],next_cursor:null,cache_complete:true,
    gaps:[{code:'CONVERSATION_NOT_CACHED',detail:'Previously discovered conversation is no longer accessible in this cache; deletion is unknown.'}]};
  if (current.id !== conversation) return unavailable('conversation_mismatch');
  if (after !== null && !/^older:\d+:.+$/.test(after)) return unavailable('cursor_invalid');
  const n = args.limit ?? 50;
  if (!Number.isInteger(n) || n < 1 || n > 200) return unavailable('limit_invalid');
  const result = view.messages.inConversation(conversation,{limit:n+1,cursor:after ?? undefined,captureIncludeSystem:true});
  if (!result.ok) return unavailable('conversation_unavailable');
  // Facade returns ascending story order; enumerate newest first with (ts,id) keyset.
  const rows = [...result.rows].reverse();
  const out = {...common,conversation_id:conversation,messages:[],next_cursor:null,cache_complete:false};
  let consumed = 0;
  for (const row of rows.slice(0,n)) {
    const next = `older:${row.ts}:${row.id}`;
    if (!Number.isSafeInteger(row.ts) || row.ts < 0 || row.convId !== conversation || !row.id) return unavailable('identity_unavailable');
    const envelope = captureEnvelope(view,'get_message',{conversation:current.handle,message:`m:${row.id}`},now);
    if (envelope?.status !== 'observed') {
      if (envelope?.reason !== 'message_too_large') return unavailable('message_unavailable');
      if (!out.gaps.some(g=>g.code==='MESSAGE_TOO_LARGE')) out.gaps.push({code:'MESSAGE_TOO_LARGE',detail:'A cached message exceeded the 128000-byte capture limit.'});
    } else {
      out.messages.push(envelope);
      // Reserve enough room for the largest allowed cursor and gap metadata.
      if (bytes(out) > MAX_PAGE - 16384) { out.messages.pop(); break; }
    }
    consumed++;
    out.next_cursor = cursor(next);
  }
  out.cache_complete = consumed === rows.length;
  if (out.cache_complete) out.next_cursor = null;
  if (rows.length && !consumed) return unavailable('page_too_large');
  return out;
}

/** Additive machine-readable evidence from the same pinned view as get_message.
 * Does not read files, refresh the cache, or expose provider writes. */
export function captureEnvelope(view, tool, args, observedAt) {
  if (tool !== 'get_message') return undefined;
  const unavailable = reason => ({schema:'teams-cache-message/v1',status:'unavailable',reason});
  if (!view.meta.schemaMatched) return unavailable('schema_unrecognized');
  if (args.offset !== undefined && args.offset !== 0) return unavailable('body_continuation');
  const matches = view.conversations.resolve(String(args.conversation));
  if (matches.length !== 1) return unavailable('conversation_unresolved');
  const conversation = matches[0];
  const id = String(args.message).replace(/^m:/,'');
  const row = view.messages.get(conversation.id,id);
  if (!row) return unavailable('not_cached'); // Never a deletion assertion.
  const account = view.meta.selfMri;
  if (!account || !conversation.id || row.convId !== conversation.id || String(row.id) !== id)
    return unavailable('identity_unavailable');
  const result = {schema:'teams-cache-message/v1',status:'observed',
    account_id:account,conversation_id:conversation.id,message_id:id,
    sender_id:row.senderMri ?? null,sender_name:row.senderName ?? null,
    root_id:row.rootId ?? null,event_time:Number.isSafeInteger(row.ts) && row.ts > 0
      ? new Date(row.ts).toISOString() : null,
    observed_at:new Date(observedAt).toISOString(),
    cache_as_of:Number.isSafeInteger(view.meta.asOf) && view.meta.asOf > 0
      ? new Date(view.meta.asOf).toISOString() : null,
    text:row.content ?? '',body_completeness:'reader_text',
    provider_revision:null,deletion_state:'unknown',mutation_fidelity:'unknown',
    partial:true,may_be_stale:!!view.mayBeStale,lossy:!!view.meta.lossy,
    has_attachment:!!row.hasAttachment};
  if (new TextEncoder().encode(JSON.stringify(result)).byteLength > 128_000)
    return unavailable('message_too_large');
  return result;
}

import test from 'node:test';
import assert from 'node:assert/strict';
import {enumerationEnvelope} from './enumeration-envelope.mjs';
const now=1792885495668;
function fixture(count=65,messages=205) {
 const conversations=Array.from({length:count},(_,i)=>({id:`native-${String(i).padStart(4,'0')}`,handle:`c:${String(i).padStart(6,'0')}`,kind:i%2?'channel':'group'}));
 const rows=Array.from({length:messages},(_,i)=>({id:String(i).padStart(5,'0'),convId:conversations[0].id,ts:now,content:'body',rootId:'root',isSystem:i%2===0}));
 return {meta:{schemaMatched:true,selfMri:'owner',asOf:now}, rows,
 conversations:{get:id=>conversations.find(c=>c.id===id),list:o=>{assert.equal(o.captureOrder,true);assert.equal(o.includeEmpty,true);return conversations.filter(c=>c.id>(o.captureAfter??'')).slice(0,o.n);},resolve:h=>conversations.filter(c=>c.handle===h)},
 messages:{get:(c,id)=>rows.find(r=>r.convId===c&&r.id===id),inConversation:(c,o)=>{assert.equal(o.captureIncludeSystem,true);const boundary=o.cursor?.split(':').slice(2).join(':');return {ok:true,rows:rows.filter(r=>r.convId===c&&(!boundary||r.id<boundary)).slice(-o.limit)}}}};
}
const args={capture:true,expected_account_id:'owner'};
const readArgs={...args,conversation:'c:000000',expected_conversation_id:'native-0000',limit:50};
const read=(view,a=readArgs)=>enumerationEnvelope(view,'read_conversation',a,now);
test('all conversations enumerate across more than thirty including empty',()=>{
 const v=fixture();let cursor;const ids=[];
 do {const p=enumerationEnvelope(v,'list_conversations',{...args,n:30,...(cursor?{capture_cursor:cursor}:{})},now);assert.equal(p.status,'observed');assert.equal(p.provider_complete,false);ids.push(...p.conversations.map(c=>c.conversation_id));cursor=p.next_cursor;assert.equal(p.cache_complete,cursor===null);}while(cursor);
 assert.equal(ids.length,65);assert.equal(new Set(ids).size,65);
});
test('all messages including channel replies/system rows; equal timestamps retain every native ID',()=>{
 const v=fixture();let cursor;const ids=[];
 do {const p=read(v,{...readArgs,...(cursor?{capture_cursor:cursor}:{})});assert.equal(p.status,'observed');ids.push(...p.messages.map(r=>r.message_id));cursor=p.next_cursor;assert.equal(p.cache_complete,cursor===null);}while(cursor);
 assert.equal(ids.length,205);assert.equal(new Set(ids).size,205);
});
test('account and conversation pins, corrupt and cross-scope continuations reject',()=>{
 const v=fixture();assert.equal(read(v,{...readArgs,expected_account_id:'other'}).reason,'account_mismatch');
 assert.equal(read(v,{...readArgs,expected_conversation_id:'other'}).gaps[0].code,'CONVERSATION_NOT_CACHED');
 assert.equal(read(v,{...readArgs,capture_cursor:'malformed'}).reason,'cursor_invalid');
 const p=enumerationEnvelope(v,'list_conversations',{...args,n:1},now);
 assert.equal(read(v,{...readArgs,capture_cursor:p.next_cursor}).reason,'cursor_invalid');
});
test('oversized message produces explicit gap and cursor progress',()=>{
 const v=fixture(2,3);v.rows[2].content='x'.repeat(128000);
 const p=read(v,{...readArgs,limit:1});assert.equal(p.messages.length,0);assert.equal(p.gaps[0].code,'MESSAGE_TOO_LARGE');assert.ok(p.next_cursor);
 const q=read(v,{...readArgs,capture_cursor:p.next_cursor});assert.equal(q.messages.length,2);assert.equal(q.cache_complete,true);
});
test('page bytes bounded and resume preserves all unsent rows',()=>{
 const v=fixture(1,25);v.rows.forEach(r=>r.content='x'.repeat(100000));let cursor;const ids=[];
 do {const p=read(v,{...readArgs,...(cursor?{capture_cursor:cursor}:{})});assert.ok(Buffer.byteLength(JSON.stringify(p))<1000000);ids.push(...p.messages.map(r=>r.message_id));cursor=p.next_cursor;}while(cursor);
 assert.equal(ids.length,25);assert.equal(new Set(ids).size,25);
});
test('legacy tools unchanged, filtered capture fails, missing identity never deletion',()=>{
 const v=fixture();assert.equal(enumerationEnvelope(v,'list_conversations',{},now),undefined);
 assert.equal(read(v,{...readArgs,since:'-1d'}).reason,'capture_filters_unsupported');
 v.meta.schemaMatched=false;assert.equal(read(v).reason,'schema_unrecognized');
});

test('native identity survives handle reassignment',()=>{const v=fixture();const original=v.conversations.get;v.conversations.get=id=>({...original(id),handle:'c:reassigned'});const resolve=v.conversations.resolve;v.conversations.resolve=h=>resolve(h==='c:reassigned'?'c:000000':h);assert.equal(read(v).messages.length,50);});

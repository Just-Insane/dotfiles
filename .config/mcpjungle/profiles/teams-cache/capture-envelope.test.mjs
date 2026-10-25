import test from 'node:test';
import assert from 'node:assert/strict';
import {captureEnvelope} from './capture-envelope.mjs';
const time=1792885495668;
function fixture(){
 const row={id:'m1',convId:'native-c1',senderMri:'sender1',rootId:'m1',ts:time,content:'hello'};
 return {row,meta:{schemaMatched:true,selfMri:'owner1',asOf:time},
 conversations:{resolve:()=>[{id:'native-c1'}]},messages:{get:()=>row}};
}
const read=v=>captureEnvelope(v,'get_message',{conversation:'c:123456',message:'m:m1'},time+999);
test('native identity and exact timestamp; unknown mutation semantics',()=>{
 const r=read(fixture()); assert.equal(r.conversation_id,'native-c1');
 assert.equal(r.account_id,'owner1');assert.equal(r.sender_id,'sender1');
 assert.equal(r.event_time,new Date(time).toISOString());
 assert.equal(r.provider_revision,null);assert.equal(r.deletion_state,'unknown');
 assert.equal(r.partial,true);assert.equal(r.text,'hello');
});
test('all other tools retain original response',()=>{
 assert.equal(captureEnvelope(fixture(),'search',{},time),undefined);
});
test('missing, ambiguous, and wrong identity are unavailable, never deleted',()=>{
 for (const change of [v=>v.messages.get=()=>null,v=>v.conversations.resolve=()=>[],
  v=>v.conversations.resolve=()=>[{id:'a'},{id:'b'}],v=>v.row.convId='wrong',
  v=>v.meta.selfMri=null]){const v=fixture();change(v);assert.equal(read(v).status,'unavailable');}
});
test('bounded message, unknown schema and continuation fail closed',()=>{
 const v=fixture();v.row.content='x'.repeat(128000);assert.equal(read(v).reason,'message_too_large');
 v.meta.schemaMatched=false;assert.equal(read(v).reason,'schema_unrecognized');
 assert.equal(captureEnvelope(fixture(),'get_message',{offset:4000},time).reason,'body_continuation');
});
test('changed content observed without inventing provider revision',()=>{
 const v=fixture();const a=read(v);v.row.content='edited';const b=read(v);
 assert.notEqual(a.text,b.text);assert.equal(b.provider_revision,null);
});

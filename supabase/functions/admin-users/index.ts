import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 const auth=req.headers.get("Authorization");if(!auth)return json({error:"Unauthorized"},401);
 const url=Deno.env.get("SUPABASE_URL")!,anon=Deno.env.get("SUPABASE_ANON_KEY")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const caller=createClient(url,anon,{global:{headers:{Authorization:auth}}}),admin=createClient(url,service);
 const {data:{user},error:uerr}=await caller.auth.getUser();if(uerr||!user)return json({error:"Unauthorized"},401);
 const body=await req.json(),{organization_id}=body;
 const {data:member}=await admin.from("organization_members").select("role").eq("organization_id",organization_id).eq("user_id",user.id).eq("status","active").maybeSingle();
 if(!member||!["owner","admin"].includes(member.role))return json({error:"Forbidden"},403);
 if(body.action==="invite"){
  const {data,error}=await admin.auth.admin.inviteUserByEmail(body.email,{data:{full_name:body.full_name}});
  if(error)return json({error:error.message},400);
  const {data:membership,error:merr}=await admin.from("organization_members").upsert({organization_id,user_id:data.user.id,full_name:body.full_name,email:body.email,role:body.role,destination_id:body.destination_id||null,status:"active"},{onConflict:"organization_id,user_id"}).select().single();
  if(merr)return json({error:merr.message},400);return json({membership});
 }
 if(body.action==="disable"){const {error}=await admin.from("organization_members").update({status:"disabled"}).eq("organization_id",organization_id).eq("user_id",body.user_id);if(error)return json({error:error.message},400);return json({ok:true})}
 return json({error:"Unknown action"},400);
});
function json(v:unknown,status=200){return new Response(JSON.stringify(v),{status,headers:{...cors,"Content-Type":"application/json"}})}

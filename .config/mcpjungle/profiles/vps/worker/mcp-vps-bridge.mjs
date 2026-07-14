export default {
  async fetch(request, env) {
    if (request.headers.get("Authorization") !== `Bearer ${env.BRIDGE_TOKEN}`) {
      return new Response("Unauthorized", { status: 401 });
    }
    const source = new URL(request.url);
    const target = new URL(`https://mcp-vps-origin.gauthier.id${source.pathname}${source.search}`);
    const headers = new Headers(request.headers);
    headers.set("Authorization", `Bearer ${env.MCPJUNGLE_TOKEN}`);
    headers.delete("host");
    const init = { method: request.method, headers, redirect: "manual" };
    if (request.method !== "GET" && request.method !== "HEAD") init.body = request.body;
    return fetch(target, init);
  },
};

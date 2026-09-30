// Deploy with JWT verification disabled: registration and login have no user JWT yet.
// SUPABASE_SERVICE_ROLE_KEY stays in Supabase Edge Function secrets, never in the game.
const origin = "https://sanypower90-ops.github.io";
const gamePublishableKey = "sb_publishable_gVzVGZCEtFpJUCFrTJLM2g_enGnvg03";
const cors = {
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Headers": "apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  Vary: "Origin",
};

function response(status: number, value: Record<string, unknown>): Response {
  return new Response(JSON.stringify(value), { status, headers: cors });
}

async function syntheticEmail(username: string): Promise<string> {
  const bytes = new TextEncoder().encode(username);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  const hex = Array.from(new Uint8Array(hash), (n) => n.toString(16).padStart(2, "0")).join("");
  return `${hex}@accounts.zombie-defense.example`;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return response(405, { error: "POST 요청만 가능합니다." });
  if (request.headers.get("content-length") && Number(request.headers.get("content-length")) > 4096) {
    return response(413, { error: "입력 내용이 너무 깁니다." });
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !serviceKey || !publicKey) return response(503, { error: "계정 서버 설정을 확인해 주세요." });
  if (request.headers.get("apikey") !== gamePublishableKey) return response(401, { error: "접근할 수 없습니다." });

  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return response(400, { error: "입력 형식을 확인해 주세요." });
  }
  const action = String(input.action ?? "");
  const username = String(input.username ?? "").normalize("NFKC").trim().toLowerCase();
  const password = String(input.password ?? "");
  if (!/^[a-z0-9가-힣_]{2,20}$/u.test(username)) {
    return response(400, { error: "아이디는 한글·영문·숫자·_로 2~20자 입력해 주세요." });
  }
  if (password.length < 8 || password.length > 72) {
    return response(400, { error: "비밀번호는 8~72자로 입력해 주세요." });
  }
  if (action !== "register" && action !== "login") return response(400, { error: "요청을 확인해 주세요." });
  const email = await syntheticEmail(username);

  try {
    if (action === "register") {
      const created = await fetch(`${url}/auth/v1/admin/users`, {
        method: "POST",
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { username } }),
      });
      if (!created.ok) {
        return response(created.status === 422 ? 409 : 502, {
          error: created.status === 422 ? "이미 사용 중인 아이디입니다." : "계정을 만들지 못했습니다. 다시 시도해 주세요.",
        });
      }
    }
    const login = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: publicKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    if (!login.ok) return response(401, { error: "아이디 또는 비밀번호를 확인해 주세요." });
    const session = await login.json();
    return response(200, {
      username,
      user_id: session.user?.id,
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
    });
  } catch {
    return response(503, { error: "계정 서버에 연결하지 못했습니다." });
  }
});

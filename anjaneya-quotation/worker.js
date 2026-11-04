// Anjaneya Traders quotation maker: photo reader helper (Cloudflare Worker).
// Your Claude API key is stored as the secret ANTHROPIC_API_KEY in Cloudflare.
// It never leaves Cloudflare and is never sent to the website.
// This helper only accepts photos from your GitHub page, and only does one job:
// reading a handwritten quotation into JSON.

const ALLOWED_ORIGIN = "https://mokaseshu.github.io";
const PROMPT = "You are reading a photo of a handwritten price note for ANJANEYA TRADERS, a rolling shutter supplier in Bhimavaram, Andhra Pradesh, India. The note will be typed into a formal quotation.\nTypical items: rolling shutter (often priced per sq ft from width x height in feet and inches), motor (e.g. Jielong, with lifting capacity in kg), TATA pipe, guides (per ft), bottom angle, locks, springs, installation, transport. Words may be English or Telugu; translate Telugu to plain English.\nCopy what is written. Never invent prices, items or specs. Numbers are plain numbers without commas. If a written amount differs from rate x quantity, keep the written amount.\n\nReply with ONLY this JSON object:\n{\n \"customer_name\": \"\" ,            // name of the customer if written, else \"\"\n \"customer_place\": \"\",            // village/town if written\n \"customer_phone\": \"\",            // phone if written\n \"subject\": \"\",                   // e.g. \"Supply & Installation of Motorised Rolling Shutter\" (use \"Supply of ...\" when no installation)\n \"intro\": \"\",                     // short phrase for 'supply of a ...', e.g. \"rolling shutter with motor, pipe and guides\"\n \"quantity\": \"\",                  // e.g. \"1 complete set\" or \"2 shutters\"\n \"size\": \"\",                      // shutter size in words, e.g. \"21 ft 3 in \u00d7 16 ft 6 in\", else \"\"\n \"items\": [ { \"name\": \"Rolling Shutter\", \"details\": \"21\u20323\u2033 \u00d7 16\u20326\u2033 = 354 sq ft @ \u20b9250 per sq ft \u00b7 Patty 1 mm, 19 gauge\", \"rate\": 250, \"rate_unit\": \"sq ft\", \"qty\": 354, \"qty_unit\": \"sq ft\", \"amount\": 88500 } ],\n                                  // rate_unit/qty_unit \"\" for lump-sum items (then qty 1); amount = the written amount\n \"gst\": \"none\",                   // \"add18\" if GST/CGST/SGST is to be added on top, \"included\" if written as including GST, else \"none\"\n \"installation_included\": false,\n \"transport_included\": false,\n \"final_total\": null,             // the final total written on the note (after any rounding), else null\n \"terms\": [],                     // spec/condition lines from the note, each as \"Label: text.\", e.g. \"Motor warranty: 1 year.\"\n \"unclear\": []                    // short notes on anything you could not read for sure\n}";

export default {
  async fetch(request, env) {
    const cors = {
      "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "content-type",
      "Vary": "Origin",
    };
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    if (request.method !== "POST" || request.headers.get("Origin") !== ALLOWED_ORIGIN) {
      return new Response("Not allowed", { status: 403, headers: cors });
    }
    if (!env.ANTHROPIC_API_KEY) {
      return json({ error: "no_key" }, 500, cors);
    }
    let body;
    try { body = await request.json(); } catch { return json({ error: "bad_request" }, 400, cors); }
    const image = body && body.image;
    if (typeof image !== "string" || image.length < 100 || image.length > 7000000) {
      return json({ error: "bad_request" }, 400, cors);
    }
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2026-10-21",
        "anthropic-beta": "server-side-fallback-2026-07-01",
      },
      body: JSON.stringify({
        model: "claude-opus-5-5",
        max_tokens: 16000,
        fallbacks: "default",
        output_config: { effort: "medium" },
        messages: [{ role: "user", content: [
          { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image } },
          { type: "text", text: PROMPT },
        ] }],
      }),
    });
    return new Response(await r.text(), { status: r.status, headers: { ...cors, "content-type": "application/json" } });
  },
};

function json(obj, status, headers) {
  return new Response(JSON.stringify(obj), { status, headers: { ...headers, "content-type": "application/json" } });
}

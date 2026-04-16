import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * dlocal-checkout
 * Generates a dLocal Smart Checkout session URL with regional prioritization.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) throw new Error('Unauthorized');

    const { plan_id, currency = 'USD' } = await req.json();

    // 1. Plan Config
    const planPrices: Record<string, number> = {
      'premium_monthly': 9.99,
      'premium_annual': 99.99
    };
    const amount = planPrices[plan_id] || 9.99;

    // 2. dLocal Credentials
    const xLogin = Deno.env.get('DLOCAL_X_LOGIN');
    const secretKey = Deno.env.get('DLOCAL_SECRET_KEY');
    if (!xLogin || !secretKey) throw new Error('dLocal configuration missing');

    const country = req.headers.get('cf-ipcountry') || 'BR'; // Default to Brazil for dLocal focus
    const orderId = `${user.id}_${Date.now()}`;

    // 3. Prepare Body
    const body = {
      amount,
      currency,
      country,
      order_id: orderId,
      success_url: `${Deno.env.get('SITE_URL')}/dashboard.html?payment=success`,
      back_url: `${Deno.env.get('SITE_URL')}/pricing.html`,
      notification_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/dlocal-webhook`,
      customer: {
        name: user.user_metadata?.display_name || 'Seedling User',
        email: user.email,
        external_id: user.id
      }
    };

    const bodyString = JSON.stringify(body);
    const xDate = new Date().toISOString();

    // 4. Generate Signature (V2-HMAC-SHA256)
    // HMAC(SecretKey, X-Login + X-Date + Body)
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secretKey);
    const messageData = encoder.encode(xLogin + xDate + bodyString);

    const cryptoKey = await crypto.subtle.importKey(
      'raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
    );
    const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, messageData);
    const signature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0')).join('');

    // 5. Call dLocal API
    const response = await fetch('https://sandbox.dlocal.com/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Date': xDate,
        'X-Login': xLogin,
        'X-Trans-Key': secretKey,
        'Authorization': `V2-HMAC-SHA256 ${signature}`
      },
      body: bodyString
    });

    const result = await response.json();
    if (!response.ok) {
      console.error('dLocal Error:', result);
      throw new Error(result.message || 'dLocal request failed');
    }

    // dLocal returns a checkout link in redirect_url
    return new Response(
      JSON.stringify({ url: result.redirect_url || result.checkout_url }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

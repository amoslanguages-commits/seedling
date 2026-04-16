import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * flutterwave-checkout
 * Generates a Flutterwave Standard hosted checkout URL with regional geo-detect.
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

    const { plan_id } = await req.json();

    // 1. Plan Pricing
    const baseAmounts: Record<string, number> = {
      'premium_monthly': 9.99,
      'premium_annual': 99.99
    };
    const amountUsd = baseAmounts[plan_id] || 9.99;

    // 2. Geo-Detect Currency & Rate
    const country = req.headers.get('cf-ipcountry') || 'MZ';
    
    // Mapping for common Flutterwave countries
    const currencyMap: Record<string, string> = {
      'MZ': 'MZN', 'NG': 'NGN', 'GH': 'GHS', 'KE': 'KES', 'ZA': 'ZAR', 'UG': 'UGX', 'TZ': 'TZS'
    };
    const currency = currencyMap[country] || 'USD';

    // Mock exchange rates (In production, call Flutterwave's rates API)
    const rates: Record<string, number> = {
      'MZN': 63.85, 'NGN': 1350.0, 'GHS': 13.5, 'KES': 130.0, 'ZAR': 18.2, 'UGX': 3700.0, 'USD': 1.0
    };
    const rate = rates[currency] || 1.0;
    const localAmount = Math.ceil(amountUsd * rate);

    // 3. Create Flutterwave Payment
    const response = await fetch('https://api.flutterwave.com/v3/payments', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('FLUT_SECRET_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        tx_ref: `${user.id}_${Date.now()}`,
        amount: localAmount,
        currency: currency,
        redirect_url: `${Deno.env.get('SITE_URL')}/dashboard.html?payment=flut_success`,
        customer: {
          email: user.email,
          name: user.user_metadata?.display_name || 'Seedling User',
          phonenumber: '' 
        },
        customizations: {
          title: 'Seedling Premium',
          description: `Unlock ${plan_id} path`,
          logo: 'https://seedling.app/assets/app_logo.png'
        },
        payment_options: 'mobilemoney, card'
      })
    });

    const result = await response.json();
    if (!response.ok) {
      console.error('FW Error:', result);
      throw new Error(result.message || 'Flutterwave request failed');
    }

    return new Response(
      JSON.stringify({ url: result.data.link }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

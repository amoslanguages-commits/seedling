import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * lemon-checkout
 * Generates a Lemon Squeezy checkout URL with pre-filled user data and geo-detect.
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

    // 1. Variant Mapping
    const variants: Record<string, string> = {
      'premium_monthly': Deno.env.get('LEMON_SQUEEZY_VARIANT_MONTHLY')!,
      'premium_annual': Deno.env.get('LEMON_SQUEEZY_VARIANT_ANNUAL')!
    };
    const variantId = variants[plan_id];
    if (!variantId) throw new Error('Invalid plan selection');

    // 2. Geo-Detect for Tax/VAT consistency
    const country = req.headers.get('cf-ipcountry') || 'US';

    // 3. Create Lemon Squeezy Checkout
    const response = await fetch('https://api.lemonsqueezy.com/v1/checkouts', {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
        'Authorization': `Bearer ${Deno.env.get('LEMON_SQUEEZY_API_KEY')}`
      },
      body: JSON.stringify({
        data: {
          type: 'checkouts',
          attributes: {
            checkout_data: {
              email: user.email,
              name: user.user_metadata?.display_name || '',
              custom: { user_id: user.id },
              billing_address: { country: country } // Pre-fill country
            },
            product_options: {
              redirect_url: `${Deno.env.get('SITE_URL')}/dashboard.html?payment=success`,
              enabled_variants: [parseInt(variantId)]
            },
            checkout_options: {
              button_color: '#4BAE4F',
              embed: true // Allows for overlay checkout or direct redirect
            }
          },
          relationships: {
            store: { data: { type: 'stores', id: Deno.env.get('LEMON_SQUEEZY_STORE_ID')! } },
            variant: { data: { type: 'variants', id: variantId } }
          }
        }
      })
    });

    const result = await response.json();
    if (!response.ok) {
      console.error('LS Error:', result);
      throw new Error(result.errors?.[0]?.detail || 'Lemon Squeezy request failed');
    }

    return new Response(
      JSON.stringify({ url: result.data.attributes.url }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

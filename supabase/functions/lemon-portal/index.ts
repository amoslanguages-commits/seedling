import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * lemon-portal
 * Generates a Lemon Squeezy Customer Portal URL for subscription management.
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

    // 1. Fetch customer from Lemon Squeezy by email
    const response = await fetch(`https://api.lemonsqueezy.com/v1/customers?filter[email]=${user.email}`, {
      headers: {
        'Accept': 'application/vnd.api+json',
        'Authorization': `Bearer ${Deno.env.get('LEMON_SQUEEZY_API_KEY')}`
      }
    });

    const result = await response.json();
    if (!response.ok || !result.data?.[0]) {
      throw new Error('No subscription found. Please upgrade first.');
    }

    const customerId = result.data[0].id;

    // 2. Generate Portal Link
    // Note: Lemon Squeezy API v1 doesn't have a direct "create portal session" endpoint like Stripe,
    // but the Customer object has a 'customer_portal_url' in its attributes.
    const portalUrl = result.data[0].attributes.urls.customer_portal;

    return new Response(
      JSON.stringify({ url: portalUrl }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

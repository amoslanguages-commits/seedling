import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * verify-receipt
 * Secures native in-app purchases by validating receipts with Apple/Google.
 * 
 * NOTE: Currently in MOCK mode until Store Credentials are provided.
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

    const { provider, receiptData, productId, isSandbox } = await req.json();

    // 1. Validation Logic
    let isValid = false;
    let expiryDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(); // Default +30 days

    // --- MOCK MODE: Always valid for testing if receiptData is present ---
    if (receiptData) {
      console.log(`[Mock] Verifying ${provider} receipt for ${productId}`);
      isValid = true; 
    }

    // --- PRODUCTION LOGIC (Placeholders) ---
    /*
    if (provider === 'apple') {
      const appleResp = await fetch(isSandbox ? 'https://sandbox.itunes.apple.com/verifyReceipt' : 'https://buy.itunes.apple.com/verifyReceipt', {
        method: 'POST',
        body: JSON.stringify({ 'receipt-data': receiptData, 'password': Deno.env.get('APPLE_SHARED_SECRET') })
      });
      const result = await appleResp.json();
      isValid = (result.status === 0);
    } else if (provider === 'google') {
      // Need Google Service Account Auth for 'androidpublisher' API
      // isValid = await verifyGoogleToken(productId, receiptData);
    }
    */

    if (!isValid) throw new Error('Invalid Receipt');

    // 2. Grant Entitlement
    const isAnnual = productId.includes('annual');
    // If the receipt has a "grace", we add 3 days instead of standard renewal.
    // E.g. in RTDN or Apple status updates, they might flag a grace period.
    const isGracePeriod = req.headers.get('x-grace-period') === 'true'; 
    const baseDays = isGracePeriod ? 3 : (isAnnual ? 365 : 30);
    const expiry = new Date(Date.now() + baseDays * 24 * 60 * 60 * 1000).toISOString();
    const finalStatus = isGracePeriod ? 'past_due' : 'active';

    const roleClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { error: dbError } = await roleClient
      .from('subscriptions')
      .upsert({
        user_id: user.id,
        provider: provider, // 'apple' or 'google'
        status: finalStatus,
        plan_id: isAnnual ? 'premium_annual' : 'premium_monthly',
        current_period_end: expiry,
        external_id: receiptData.substring(0, 100) // Store slice of receipt for auditing
      }, { onConflict: 'user_id' });

    if (dbError) throw dbError;

    return new Response(
      JSON.stringify({ success: true, expiry }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

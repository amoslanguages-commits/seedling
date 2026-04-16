import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * flutterwave-webhook
 * Handles payment verification notifications from Flutterwave.
 */

Deno.serve(async (req) => {
  try {
    const signature = req.headers.get('verif-hash');
    const secretHash = Deno.env.get('FLUT_SECRET_HASH');

    // 1. Verify Signature
    if (!signature || signature !== secretHash) {
      return new Response('Invalid signature', { status: 401 });
    }

    const payload = await req.json();
    const data = payload.data;
    
    // Flutterwave tx_ref format: user_id_timestamp
    const [userId] = data.tx_ref.split('_');

    if (!userId) {
      console.warn('No userId in tx_ref');
      return new Response('No user id', { status: 200 });
    }

    // 2. Process Charge
    if (payload.event === 'charge.completed' && data.status === 'successful') {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      // Determine plan based on amount or metadata
      // For simplicity, we assume any successful Flutterwave payment is a 'premium' upgrade.
      const isAnnual = data.amount > 3000; // Rough heuristic for MZN/NGN or check customizations
      
      const { error } = await supabase
        .from('subscriptions')
        .upsert({
          user_id: userId,
          provider: 'flutterwave',
          status: 'active',
          plan_id: isAnnual ? 'premium_annual' : 'premium_monthly',
          current_period_end: new Date(Date.now() + (isAnnual ? 365 : 30) * 24 * 60 * 60 * 1000).toISOString(),
          flutterwave_id: data.id.toString()
        }, { onConflict: 'user_id' });

      if (error) throw error;
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Webhook Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});

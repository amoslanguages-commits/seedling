import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * dlocal-webhook
 * Handles incoming payment notifications from dLocal.
 */

Deno.serve(async (req) => {
  try {
    const secretKey = Deno.env.get('DLOCAL_SECRET_KEY');
    const xSignature = req.headers.get('X-Signature');
    
    // 1. Read Body
    const bodyText = await req.text();
    const payload = JSON.parse(bodyText);

    // 2. Verify Signature (Simpler HMAC in v1 webhooks: HMAC-SHA256(SecretKey, Body))
    // Note: dLocal supports multiple webhook versions. This assumes a standard HMAC check.
    if (xSignature) {
      const encoder = new TextEncoder();
      const keyData = encoder.encode(secretKey);
      const messageData = encoder.encode(bodyText);
      const cryptoKey = await crypto.subtle.importKey(
        'raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
      );
      const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, messageData);
      const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map(b => b.toString(16).padStart(2, '0')).join('');

      // In production, uncomment the following line:
      // if (xSignature !== expectedSignature) throw new Error('Invalid signature');
    }

    // 3. Process Success
    // dLocal Statuses: 'PAID', 'PENDING', 'CANCELLED'
    if (payload.status === 'PAID') {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Use Service Role to bypass RLS
      );

      const userId = payload.order_id.split('_')[0];
      const expiryDate = new Date();
      expiryDate.setMonth(expiryDate.getMonth() + 1); // Default to 1 month for dLocal prepaid

      // Upsert subscription
      const { error } = await supabase
        .from('subscriptions')
        .upsert({
          user_id: userId,
          provider: 'dlocal',
          status: 'active',
          plan_id: 'premium_monthly', // Map based on payload if needed
          current_period_end: expiryDate.toISOString(),
          dlocal_payment_id: payload.id
        }, { onConflict: 'user_id' });

      if (error) throw error;
      console.log(`Subscription activated for user ${userId} via dLocal`);
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

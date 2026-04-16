import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * lemon-webhook
 * Handles incoming events from Lemon Squeezy (subscription updates, etc.)
 */

Deno.serve(async (req) => {
  try {
    const signature = req.headers.get('x-signature');
    const secret = Deno.env.get('LEMON_SQUEEZY_WEBHOOK_SECRET');

    // 1. Verify Signature
    // Verify using HMAC-SHA256(secret, body)
    const bodyText = await req.text();
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const messageData = encoder.encode(bodyText);
    const cryptoKey = await crypto.subtle.importKey(
      'raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
    );
    const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, messageData);
    const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0')).join('');

    if (signature !== expectedSignature) {
      return new Response('Invalid signature', { status: 401 });
    }

    const payload = JSON.parse(bodyText);
    const eventName = payload.meta.event_name;
    const customData = payload.meta.custom_data;
    const userId = customData?.user_id;

    if (!userId) {
      console.warn('No user_id in webhook custom_data');
      return new Response('No user_id', { status: 200 });
    }

    // 2. Process Events
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    if (eventName === 'subscription_created' || eventName === 'subscription_updated') {
      const attributes = payload.data.attributes;
      const status = attributes.status; // 'active', 'on_trial', 'cancelled', 'expired'
      
      const { error } = await supabase
        .from('subscriptions')
        .upsert({
          user_id: userId,
          provider: 'lemonsqueezy',
          status: status,
          plan_id: attributes.variant_name.toLowerCase().includes('annual') ? 'premium_annual' : 'premium_monthly',
          current_period_end: attributes.renews_at || attributes.ends_at,
          lemon_squeezy_id: payload.data.id
        }, { onConflict: 'user_id' });

      if (error) throw error;
    }

    if (eventName === 'subscription_cancelled') {
        const { error } = await supabase
          .from('subscriptions')
          .update({ status: 'cancelled' })
          .eq('user_id', userId);
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

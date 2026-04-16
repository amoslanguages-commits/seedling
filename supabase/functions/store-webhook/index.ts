import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * store-webhook
 * Receives Server-to-Server (S2S) notifications from Apple App Store and Google Play Store.
 * Keeps our database in sync with native refunds, cancellations, and renewals.
 */

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const payload = await req.json();

    console.log('[Store Webhook] Received payload:', JSON.stringify(payload));

    const roleClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    let externalId = null;
    let newStatus = null;
    let platform = 'unknown';

    // 1. Detect Payload Type
    if (payload.signedPayload) {
      // APPLE APP STORE SERVER NOTIFICATIONS V2
      platform = 'apple';
      // In production, we decode JWT (signedPayload).
      // For now, we assume simple mock structure:
      const decodedPayload = payload.mockDecoded || payload;
      
      const notificationType = decodedPayload.notificationType; // e.g. REFUND, DID_CHANGE_RENEWAL_STATUS, EXPIRED
      externalId = decodedPayload.originalTransactionId;
      
      if (notificationType === 'EXPIRED' || notificationType === 'DID_FAIL_TO_RENEW') {
        newStatus = 'past_due'; // Provide grace period
      } else if (notificationType === 'REFUND' || notificationType === 'REVOKE') {
        newStatus = 'canceled';
      } else if (notificationType === 'SUBSCRIBED' || notificationType === 'DID_RENEW') {
        newStatus = 'active';
      }
    } 
    else if (payload.subscriptionNotification) {
      // GOOGLE PLAY SHARE (RTDN)
      platform = 'google';
      const notification = payload.subscriptionNotification;
      externalId = notification.purchaseToken;
      
      const type = notification.notificationType;
      // Google Notification Types (integers):
      // 1: RECOVERED, 2: RENEWED, 3: CANCELED, 5: ACCOUNT_HOLD, 6: GRACE_PERIOD, 12: REVOKED, 13: EXPIRED
      if (type === 5 || type === 6 || type === 13) {
        newStatus = 'past_due';
      } else if (type === 12) { // Revoked / Refunded
        newStatus = 'canceled';
      } else if (type === 1 || type === 2 || type === 4) { // Recovered, Renewed, Purchased
        newStatus = 'active';
      }
    }

    // 2. Update Database
    if (externalId && newStatus) {
      console.log(`[Store Webhook] Updating ${platform} subscription ${externalId} to ${newStatus}`);
      
      const { error } = await roleClient
        .from('subscriptions')
        .update({ status: newStatus })
        // Since we slice the receipt in verify-receipt, we might need a more robust mapping here.
        // For now, we mock exact matching.
        .eq('external_id', externalId);

      if (error) throw error;
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('[Store Webhook Error]', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * payment-config
 * Detects user country and returns the optimized payment configuration.
 *
 * Priorities:
 * 1. Africa -> Flutterwave (M-Pesa, etc.)
 * 2. Asia/LATAM -> dLocal (PIX, GCash, etc.)
 * 3. Global -> Lemon Squeezy (Card, PayPal)
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });

  try {
    // 1. Detect Country
    // Supabase Edge Functions on Cloudflare provide 'cf-ipcountry'
    const country = req.headers.get('cf-ipcountry') || 'US';
    
    // 2. Map Country to Provider and Currency
    let primaryProvider = 'lemonsqueezy';
    let localProvider = null;
    let localCurrency = 'USD';
    let localMethodName = 'International Card / PayPal';

    // Africa Region (Simplified)
    const africaCodes = ['MZ', 'ZA', 'KE', 'NG', 'GH', 'TZ', 'UG', 'RW'];
    // LATAM/Asia Region (dLocal focus)
    const latamAsiaCodes = ['BR', 'MX', 'AR', 'CO', 'CL', 'PE', 'PH', 'ID', 'IN', 'VN', 'TH'];

    if (africaCodes.includes(country)) {
      primaryProvider = 'flutterwave';
      localProvider = 'flutterwave';
      localCurrency = country === 'MZ' ? 'MZN' : 'USD'; 
      localMethodName = country === 'MZ' ? 'M-Pesa / Mobile Money' : 'Mobile Money';
    } else if (latamAsiaCodes.includes(country)) {
      primaryProvider = 'dlocal'; // Parallel priority
      localProvider = 'dlocal';
      const currencyMap: Record<string, string> = {
        'BR': 'BRL', 'MX': 'MXN', 'AR': 'ARS', 'CO': 'COP', 'CL': 'CLP',
        'PH': 'PHP', 'ID': 'IDR', 'IN': 'INR', 'VN': 'VND', 'TH': 'THB'
      };
      localCurrency = currencyMap[country] || 'USD';
      const methodMap: Record<string, string> = {
        'BR': 'PIX / Boleto', 'MX': 'OXXO / Card', 'PH': 'GCash / Maya',
        'IN': 'UPI / NetBanking', 'ID': 'GoPay / OVO'
      };
      localMethodName = methodMap[country] || 'Local Payment Method';
    }

    // 3. Simple Rate Fetching (Mocking for dev, can hook into LS/Flutterwave/dLocal API)
    // In production, we'd call a real rates API here.
    const rates: Record<string, number> = {
      'MZN': 63.85, 'BRL': 5.05, 'MXN': 17.10, 'PHP': 56.20, 'INR': 83.30, 'IDR': 15800, 'USD': 1.0
    };
    const rate = rates[localCurrency] || 1.0;

    return new Response(
      JSON.stringify({
        country,
        primary_provider: 'lemonsqueezy', // Always primary
        local_provider: localProvider, // Optional secondary if detected
        local_currency: localCurrency,
        local_method_name: localMethodName,
        exchange_rate: rate,
        is_parallel: true
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});

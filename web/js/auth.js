/* ═══════════════════════════════════════════════════════════
   SEEDLING AUTH.JS
   Handles sign in, sign up, sign out, Google OAuth.
   Uses the global `window.sb` Supabase client from supabase-client.js.
═══════════════════════════════════════════════════════════ */

/* ── Helpers ─────────────────────────────────────────────── */
function switchTab(tab) {
  const isSignIn = tab === 'signin';
  document.getElementById('tabSignIn').classList.toggle('active', isSignIn);
  document.getElementById('tabSignUp').classList.toggle('active', !isSignIn);
  document.getElementById('formSignIn').classList.toggle('active', isSignIn);
  document.getElementById('formSignUp').classList.toggle('active', !isSignIn);
  hideBanner();
}

function showBanner(msg, type = 'error') {
  const el = document.getElementById('authBanner');
  if (!el) return;
  el.textContent = msg;
  el.className = `auth-banner ${type}`;
}
function hideBanner() {
  const el = document.getElementById('authBanner');
  if (el) el.className = 'auth-banner';
}

function setLoading(btnId, loading) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.disabled = loading;
  btn.classList.toggle('loading', loading);
}

function togglePw(inputId, btn) {
  const inp = document.getElementById(inputId);
  const isHidden = inp.type === 'password';
  inp.type = isHidden ? 'text' : 'password';
  btn.textContent = isHidden ? '🙈' : '👁';
}

function markError(inputId, errId, show) {
  const inp = document.getElementById(inputId);
  const err = document.getElementById(errId);
  if (inp) inp.classList.toggle('error', show);
  if (err) err.classList.toggle('visible', show);
}

function getRedirectUrl() {
  const params = new URLSearchParams(window.location.search);
  return params.get('redirect') || 'dashboard.html';
}

/* ── Sign In ─────────────────────────────────────────────── */
async function handleSignIn() {
  hideBanner();
  const email    = document.getElementById('siEmail').value.trim();
  const password = document.getElementById('siPassword').value;

  let valid = true;
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  markError('siEmail', 'siEmailErr', !emailOk);
  if (!emailOk) valid = false;

  markError('siPassword', 'siPasswordErr', !password);
  if (!password) valid = false;

  if (!valid) return;

  setLoading('btnSignIn', true);
  try {
    const { data, error } = await window.sb.auth.signInWithPassword({ email, password });
    if (error) throw error;
    // Success — redirect
    window.location.href = getRedirectUrl();
  } catch (err) {
    showBanner(friendlyAuthError(err.message));
  } finally {
    setLoading('btnSignIn', false);
  }
}

/* ── Sign Up ─────────────────────────────────────────────── */
async function handleSignUp() {
  hideBanner();
  const name     = document.getElementById('suName').value.trim();
  const email    = document.getElementById('suEmail').value.trim();
  const password = document.getElementById('suPassword').value;

  let valid = true;
  markError('suName', 'suNameErr', !name);
  if (!name) valid = false;

  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  markError('suEmail', 'suEmailErr', !emailOk);
  if (!emailOk) valid = false;

  const pwOk = password.length >= 8;
  markError('suPassword', 'suPasswordErr', !pwOk);
  if (!pwOk) valid = false;

  if (!valid) return;

  setLoading('btnSignUp', true);
  try {
    const { data, error } = await window.sb.auth.signUp({
      email,
      password,
      options: {
        data: { display_name: name },
        emailRedirectTo: `${location.origin}/dashboard.html`,
      },
    });
    if (error) throw error;

    // Show success state
    document.getElementById('signupFields').style.display = 'none';
    document.getElementById('signupNote').style.display = 'none';
    document.getElementById('signupEmail').textContent = email;
    document.getElementById('signupSuccess').classList.add('visible');
  } catch (err) {
    showBanner(friendlyAuthError(err.message));
  } finally {
    setLoading('btnSignUp', false);
  }
}

/* ── Google OAuth ────────────────────────────────────────── */
async function handleGoogleAuth() {
  hideBanner();
  try {
    const { error } = await window.sb.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${location.origin}/${getRedirectUrl()}`,
        queryParams: { access_type: 'offline', prompt: 'consent' },
      },
    });
    if (error) throw error;
  } catch (err) {
    showBanner(friendlyAuthError(err.message));
  }
}

/* ── Sign Out ────────────────────────────────────────────── */
async function handleSignOut() {
  await window.sb.auth.signOut();
  window.location.href = 'index.html';
}

/* ── Friendly error messages ─────────────────────────────── */
function friendlyAuthError(msg) {
  if (!msg) return 'Something went wrong. Please try again.';
  const m = msg.toLowerCase();
  if (m.includes('invalid login credentials') || m.includes('invalid credentials'))
    return 'Incorrect email or password. Please try again.';
  if (m.includes('user already registered') || m.includes('already been registered'))
    return 'An account with this email already exists. Try signing in!';
  if (m.includes('email not confirmed'))
    return 'Please check your email and click the confirmation link first.';
  if (m.includes('rate limit') || m.includes('too many'))
    return 'Too many attempts. Please wait a moment and try again.';
  if (m.includes('password') && m.includes('short'))
    return 'Password is too short. Use at least 8 characters.';
  return msg;
}

/* ── Auth State Observer (updates navbar across all pages) ── */
async function initAuthObserver() {
  if (!window.sb) return;

  const updateNav = async (session) => {
    const navCta = document.getElementById('navCta');
    if (!navCta) return;

    if (session?.user) {
      // Logged in
      const name = session.user.user_metadata?.display_name || session.user.email?.split('@')[0] || 'Account';
      navCta.textContent = `👤 ${name}`;
      navCta.href = 'dashboard.html';
      navCta.style.background = 'rgba(75,174,79,0.15)';
      navCta.style.borderColor = 'rgba(75,174,79,0.4)';
    } else {
      // Logged out
      navCta.textContent = 'Sign In';
      navCta.href = 'login.html';
      navCta.style.background = '';
      navCta.style.borderColor = '';
    }
  };

  // Initial state
  const { data: { session } } = await window.sb.auth.getSession();
  updateNav(session);

  // Listen for changes
  window.sb.auth.onAuthStateChange((event, session) => {
    updateNav(session);

    // Update pricing page buttons if on that page
    if (document.getElementById('pricingCtas')) {
      updatePricingButtons(session);
    }
  });
}

/* ── Pricing page — swap "SELECT PLAN" to auth-aware buttons ─ */
async function updatePricingButtons(session) {
  const btns = document.querySelectorAll('[data-plan-cta]');
  btns.forEach(btn => {
    const plan = btn.dataset.planCta;
    if (plan === 'free') {
      if (session) {
        btn.textContent = 'MY PLAN ✓';
        btn.classList.add('active');
      } else {
        btn.textContent = 'START FREE';
        btn.href = 'login.html?tab=signup';
      }
    } else {
      if (session) {
        btn.textContent = 'UPGRADE NOW →';
        btn.href = '#';
        btn.onclick = (e) => { e.preventDefault(); startCheckout(plan); };
      } else {
        btn.textContent = 'GET STARTED';
        btn.href = `login.html?tab=signup&redirect=pricing.html&plan=${plan}`;
        btn.onclick = null;
      }
    }
  });
}

/* ── Payment Config (Geo-Detect) ────────────────────────── */
async function fetchPaymentConfig() {
  try {
    const { data, error } = await window.sb.functions.invoke('payment-config', {});
    if (error) throw error;
    return data;
  } catch (err) {
    console.warn('Geo-detect failed:', err);
    return { primary_provider: 'lemonsqueezy', local_provider: null };
  }
}

/* ── Checkout (Lemon Squeezy) ────────────────────────────── */
async function startCheckout(planId) {
  const { data: { session } } = await window.sb.auth.getSession();
  if (!session) {
    window.location.href = `login.html?redirect=pricing.html&plan=${planId}`;
    return;
  }

  const btn = document.querySelector(`[data-plan-cta="${planId}"]`);
  if (btn) { btn.textContent = 'Opening checkout…'; btn.disabled = true; }

  try {
    const { data, error } = await window.sb.functions.invoke('lemon-checkout', {
      body: { plan_id: planId },
    });
    if (error) throw error;
    if (data?.url) {
      window.location.href = data.url;
    } else {
      throw new Error('No checkout URL.');
    }
  } catch (err) {
    console.error('Checkout error:', err);
    alert('Could not open checkout. Please try again.');
    if (btn) { btn.textContent = 'UPGRADE NOW →'; btn.disabled = false; }
  }
}

/* ── Checkout (Flutterwave / Mobile Money) ───────────────── */
async function startFlutterwaveCheckout(planId) {
  const { data: { session } } = await window.sb.auth.getSession();
  if (!session) {
    window.location.href = `login.html?redirect=pricing.html&plan=${planId}`;
    return;
  }

  const btn = document.querySelector(`[data-flut-cta="${planId}"]`);
  const originalText = btn?.textContent;
  if (btn) { btn.textContent = 'Preparing M-Pesa…'; btn.disabled = true; }

  try {
    const { data, error } = await window.sb.functions.invoke('flutterwave-checkout', {
      body: { plan_id: planId },
    });
    if (error) throw error;
    if (data?.url) {
      window.location.href = data.url;
    } else {
      throw new Error('No checkout URL.');
    }
  } catch (err) {
    console.error('Flutterwave error:', err);
    alert('Local payment service unavailable.');
    if (btn) { btn.textContent = originalText; btn.disabled = false; }
  }
}

/* ── Checkout (dLocal / Local Methods) ───────────────────── */
async function startDLocalCheckout(planId) {
  const { data: { session } } = await window.sb.auth.getSession();
  if (!session) {
    window.location.href = `login.html?redirect=pricing.html&plan=${planId}`;
    return;
  }

  const btn = document.querySelector(`[data-flut-cta="${planId}"]`); // Same selector for local
  const originalText = btn?.textContent;
  if (btn) { btn.textContent = 'Preparing Local Pay…'; btn.disabled = true; }

  try {
    const { data, error } = await window.sb.functions.invoke('dlocal-checkout', {
      body: { plan_id: planId },
    });
    if (error) throw error;
    if (data?.url) {
      window.location.href = data.url;
    } else {
      throw new Error('No checkout URL.');
    }
  } catch (err) {
    console.error('dLocal error:', err);
    alert('Local payment service unavailable.');
    if (btn) { btn.textContent = originalText; btn.disabled = false; }
  }
}

// Initialize on every page load
document.addEventListener('DOMContentLoaded', () => {
  initAuthObserver();
});

/* ── Customer portal (manage subscription) ────────────── */
async function openPortal() {
  const btn = document.getElementById('subManageBtn');
  if (btn) { btn.textContent = 'Opening…'; btn.disabled = true; }

  try {
    const { data, error } = await window.sb.functions.invoke('lemon-portal', { body: {} });
    if (error) throw error;
    if (data?.url) {
      window.open(data.url, '_blank');
    } else {
      throw new Error('No portal URL.');
    }
  } catch (err) {
    console.error('Portal error:', err);
    alert('Subscription portal unavailable. Please contact support@seedling.app');
  } finally {
    if (btn) { btn.textContent = 'Manage Plan'; btn.disabled = false; }
  }
}

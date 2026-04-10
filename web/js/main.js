/* ═══════════════════════════════════════════════════════════
   SEEDLING MARKETING — MAIN JAVASCRIPT
   Navbar, Scroll Reveals, Hero Canvas, Counters, Language
   Switcher, FAQ, Parallax Particles
═══════════════════════════════════════════════════════════ */

// ─── NAVBAR SCROLL EFFECT ────────────────────────────────
const navbar = document.getElementById('navbar');
const hamburger = document.getElementById('hamburger');
const navLinks = document.getElementById('navLinks');

window.addEventListener('scroll', () => {
  if (window.scrollY > 40) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
}, { passive: true });

hamburger.addEventListener('click', () => {
  navLinks.classList.toggle('open');
});

// Close menu when link clicked
navLinks.querySelectorAll('a').forEach(a => {
  a.addEventListener('click', () => navLinks.classList.remove('open'));
});

// ─── SCROLL REVEAL ────────────────────────────────────────
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry, i) => {
    if (entry.isIntersecting) {
      setTimeout(() => {
        entry.target.classList.add('visible');
      }, (entry.target.dataset.delay || 0));
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

// Stagger child reveals in grid containers
const grids = document.querySelectorAll(
  '.features-grid, .proof-grid, .testimonials, .pricing-grid, .footer-links'
);
grids.forEach(grid => {
  grid.querySelectorAll('.reveal').forEach((el, i) => {
    el.dataset.delay = i * 80;
  });
});

document.querySelectorAll('.reveal').forEach(el => revealObserver.observe(el));

// ─── ANIMATED COUNTERS ────────────────────────────────────
function animateCounter(el, target, suffix = '') {
  const duration = 2000;
  const start = performance.now();
  const isDecimal = target < 10;
  el.textContent = '0';

  function update(now) {
    const progress = Math.min((now - start) / duration, 1);
    const ease = 1 - Math.pow(1 - progress, 3); // ease-out cubic
    const current = Math.floor(ease * target);
    el.textContent = isDecimal ? (ease * target).toFixed(1) : current.toLocaleString();
    if (progress < 1) requestAnimationFrame(update);
    else el.textContent = isDecimal ? target.toFixed(1) : target.toLocaleString();
  }
  requestAnimationFrame(update);
}

const counterObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const el = entry.target;
      const target = parseFloat(el.dataset.target);
      animateCounter(el, target);
      counterObserver.unobserve(el);
    }
  });
}, { threshold: 0.5 });

document.querySelectorAll('[data-target]').forEach(el => counterObserver.observe(el));

// ─── HERO CANVAS — FLOATING PARTICLES ─────────────────────
const heroCanvas = document.getElementById('heroCanvas');
if (heroCanvas) {
  const hCtx = heroCanvas.getContext('2d');
  let hW, hH, hParticles = [];

  function resizeHeroCanvas() {
    hW = heroCanvas.width = heroCanvas.offsetWidth;
    hH = heroCanvas.height = heroCanvas.offsetHeight;
  }

  function createParticle() {
    return {
      x: Math.random() * hW,
      y: Math.random() * hH,
      r: Math.random() * 3 + 1,
      vx: (Math.random() - 0.5) * 0.4,
      vy: -Math.random() * 0.6 - 0.2,
      alpha: Math.random() * 0.6 + 0.1,
      hue: Math.random() > 0.5 ? '#4BAE4F' : '#4FC3F7',
      life: 1,
      decay: Math.random() * 0.003 + 0.001
    };
  }

  function initParticles() {
    hParticles = [];
    for (let i = 0; i < 80; i++) {
      const p = createParticle();
      p.life = Math.random();
      hParticles.push(p);
    }
  }

  function animateHero() {
    hCtx.clearRect(0, 0, hW, hH);
    hParticles.forEach((p, i) => {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= p.decay;
      if (p.life <= 0 || p.y < -20) {
        hParticles[i] = createParticle();
        hParticles[i].y = hH + 10;
      }
      hCtx.beginPath();
      hCtx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      hCtx.fillStyle = p.hue;
      hCtx.globalAlpha = p.life * p.alpha;
      hCtx.fill();
    });
    hCtx.globalAlpha = 1;
    requestAnimationFrame(animateHero);
  }

  resizeHeroCanvas();
  initParticles();
  animateHero();
  window.addEventListener('resize', () => { resizeHeroCanvas(); initParticles(); });
}

// ─── MASCOT PARALLAX ON MOUSE MOVE ────────────────────────
const mascot = document.getElementById('mascotImg');
if (mascot) {
  document.addEventListener('mousemove', (e) => {
    const { innerWidth, innerHeight } = window;
    const x = (e.clientX / innerWidth - 0.5) * 20;
    const y = (e.clientY / innerHeight - 0.5) * 12;
    mascot.style.transform = `translateY(calc(-${Math.abs(Math.sin(Date.now()/3000)) * 16}px + ${y}px)) rotateY(${x}deg)`;
  });
}

// ─── FAQ ACCORDION ────────────────────────────────────────
function toggleFaq(btn) {
  const item = btn.closest('.faq-item');
  const isOpen = item.classList.contains('open');
  // Close all
  document.querySelectorAll('.faq-item.open').forEach(el => el.classList.remove('open'));
  // Open clicked if it was closed
  if (!isOpen) item.classList.add('open');
}
window.toggleFaq = toggleFaq;



function updateLangShowcase(word) {
  const langCenterWord = document.getElementById('langCenterWord');
  if (!langCenterWord) return;

  langCenterWord.style.opacity = '0';
  langCenterWord.style.transform = 'scale(0.8)';
  setTimeout(() => {
    langCenterWord.textContent = word;
    langCenterWord.style.opacity = '1';
    langCenterWord.style.transform = 'scale(1)';
  }, 300);
}

// ─── SMOOTH SCROLL FOR ANCHOR LINKS ──────────────────────
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', (e) => {
    const target = document.querySelector(a.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

// ─── SRS FILL ANIMATION TRIGGER ──────────────────────────
const srsFills = document.querySelectorAll('.srs-fill');
const srsObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.style.animationPlayState = 'running';
      srsObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.5 });
srsFills.forEach(fill => {
  fill.style.animationPlayState = 'paused';
  srsObserver.observe(fill);
});

console.log('🌱 Seedling Marketing Site loaded');

// ─── 121 LANGUAGE CHIP LIST ───────────────────────────────
const ALL_LANGUAGES = [
  {code:'om',  name:'Afaan Oromo',           country:'et', hello:'Akkam'},
  {code:'af',  name:'Afrikaans',             country:'za', hello:'Hallo'},
  {code:'ak',  name:'Akan / Twi',            country:'gh', hello:'Akwaaba'},
  {code:'sq',  name:'Albanian',              country:'al', hello:'Përshëndetje'},
  {code:'am',  name:'Amharic',               country:'et', hello:'ሰላም'},
  {code:'ar',  name:'Arabic',                country:'sa', hello:'مرحبا'},
  {code:'hy',  name:'Armenian',              country:'am', hello:'Բարեւ'},
  {code:'as',  name:'Assamese',              country:'in', hello:'নমস্কাৰ'},
  {code:'az',  name:'Azerbaijani',           country:'az', hello:'Salam'},
  {code:'eu',  name:'Basque',                country:'es', hello:'Kaixo'},
  {code:'be',  name:'Belarusian',            country:'by', hello:'Прывітанне'},
  {code:'bn',  name:'Bengali',               country:'bd', hello:'হ্যালো'},
  {code:'bho', name:'Bhojpuri',              country:'in', hello:'प्रनाम'},
  {code:'bs',  name:'Bosnian',               country:'ba', hello:'Zdravo'},
  {code:'bg',  name:'Bulgarian',             country:'bg', hello:'Здравейте'},
  {code:'my',  name:'Burmese',               country:'mm', hello:'မင်္ဂလာပါ'},
  {code:'yue', name:'Cantonese',             country:'hk', hello:'你好'},
  {code:'ca',  name:'Catalan',               country:'es', hello:'Hola'},
  {code:'ceb', name:'Cebuano',               country:'ph', hello:'Kumusta'},
  {code:'ny',  name:'Chichewa',              country:'mw', hello:'Moni'},
  {code:'zh-CN',name:'Chinese (Simplified)', country:'cn', hello:'你好'},
  {code:'zh-TW',name:'Chinese (Traditional)',country:'tw', hello:'你好'},
  {code:'hr',  name:'Croatian',              country:'hr', hello:'Zdravo'},
  {code:'cs',  name:'Czech',                 country:'cz', hello:'Ahoj'},
  {code:'da',  name:'Danish',                country:'dk', hello:'Hej'},
  {code:'nl',  name:'Dutch',                 country:'nl', hello:'Hallo'},
  {code:'en-GB',name:'English (UK)',         country:'gb', hello:'Hello'},
  {code:'en-US',name:'English (US)',         country:'us', hello:'Hello'},
  {code:'et',  name:'Estonian',              country:'ee', hello:'Tere'},
  {code:'fil', name:'Filipino',              country:'ph', hello:'Kamusta'},
  {code:'fi',  name:'Finnish',               country:'fi', hello:'Hei'},
  {code:'fr',  name:'French',                country:'fr', hello:'Bonjour'},
  {code:'fr-CA',name:'French (Canada)',      country:'ca', hello:'Bonjour'},
  {code:'ff',  name:'Fulani',                country:'sn', hello:'Jam waali'},
  {code:'gl',  name:'Galician',              country:'es', hello:'Ola'},
  {code:'ka',  name:'Georgian',              country:'ge', hello:'გამარჯობა'},
  {code:'de',  name:'German',                country:'de', hello:'Hallo'},
  {code:'el',  name:'Greek',                 country:'gr', hello:'Γεια σας'},
  {code:'gn',  name:'Guarani',               country:'py', hello:"Mba'eichapa"},
  {code:'gu',  name:'Gujarati',              country:'in', hello:'આવજો'},
  {code:'ht',  name:'Haitian Creole',        country:'ht', hello:'Bonjou'},
  {code:'ha',  name:'Hausa',                 country:'ng', hello:'Sannu'},
  {code:'he',  name:'Hebrew',                country:'il', hello:'שלום'},
  {code:'hi',  name:'Hindi',                 country:'in', hello:'नमस्ते'},
  {code:'hmn', name:'Hmong',                 country:'la', hello:'Nyob zoo'},
  {code:'hu',  name:'Hungarian',             country:'hu', hello:'Helló'},
  {code:'is',  name:'Icelandic',             country:'is', hello:'Halló'},
  {code:'ig',  name:'Igbo',                  country:'ng', hello:'Nnọọ'},
  {code:'id',  name:'Indonesian',            country:'id', hello:'Halo'},
  {code:'ga',  name:'Irish',                 country:'ie', hello:'Dia duit'},
  {code:'xh',  name:'isiXhosa',              country:'za', hello:'Molo'},
  {code:'it',  name:'Italian',               country:'it', hello:'Ciao'},
  {code:'ja',  name:'Japanese',              country:'jp', hello:'こんにちは'},
  {code:'jv',  name:'Javanese',              country:'id', hello:'Halo'},
  {code:'kn',  name:'Kannada',               country:'in', hello:'ಹೆಳ್ಳೆ'},
  {code:'ks',  name:'Kashmiri',              country:'in', hello:'سلام'},
  {code:'kk',  name:'Kazakh',                country:'kz', hello:'Сәлеметсіз'},
  {code:'km',  name:'Khmer',                 country:'kh', hello:'សួស្ដី'},
  {code:'rw',  name:'Kinyarwanda',           country:'rw', hello:'Muraho'},
  {code:'ko',  name:'Korean',                country:'kr', hello:'안녕하세요'},
  {code:'ku',  name:'Kurdish',               country:'iq', hello:'Silav'},
  {code:'ky',  name:'Kyrgyz',                country:'kg', hello:'Салам'},
  {code:'lo',  name:'Lao',                   country:'la', hello:'ສະບາຍດີ'},
  {code:'lv',  name:'Latvian',               country:'lv', hello:'Sveiki'},
  {code:'ln',  name:'Lingala',               country:'cd', hello:'Mbote'},
  {code:'lt',  name:'Lithuanian',            country:'lt', hello:'Labas'},
  {code:'lg',  name:'Luganda',               country:'ug', hello:'Oli otya'},
  {code:'lb',  name:'Luxembourgish',         country:'lu', hello:'Moien'},
  {code:'mk',  name:'Macedonian',            country:'mk', hello:'Здраво'},
  {code:'mad', name:'Madurese',              country:'id', hello:'Sallem'},
  {code:'mg',  name:'Malagasy',              country:'mg', hello:'Manao ahoana'},
  {code:'ms',  name:'Malay',                 country:'my', hello:'Hai'},
  {code:'ml',  name:'Malayalam',             country:'in', hello:'ഹലോ'},
  {code:'mt',  name:'Maltese',               country:'mt', hello:'Bonġu'},
  {code:'mr',  name:'Marathi',               country:'in', hello:'नमस्कार'},
  {code:'mi',  name:'Māori',                 country:'nz', hello:'Kia ora'},
  {code:'mn',  name:'Mongolian',             country:'mn', hello:'Сайн байна'},
  {code:'ne',  name:'Nepali',                country:'np', hello:'नमस्कार'},
  {code:'pcm', name:'Nigerian Pidgin',       country:'ng', hello:'How far'},
  {code:'nb-NO',name:'Norwegian',            country:'no', hello:'Hei'},
  {code:'or',  name:'Odia',                  country:'in', hello:'ନମସ୍କାର'},
  {code:'ps',  name:'Pashto',                country:'af', hello:'سلام'},
  {code:'fa',  name:'Persian',               country:'ir', hello:'سلام'},
  {code:'pl',  name:'Polish',                country:'pl', hello:'Cześć'},
  {code:'pt-BR',name:'Portuguese (Brazil)',  country:'br', hello:'Olá'},
  {code:'pt-PT',name:'Portuguese (Portugal)',country:'pt', hello:'Olá'},
  {code:'pa',  name:'Punjabi',               country:'in', hello:'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ'},
  {code:'qu',  name:'Quechua',               country:'pe', hello:'Rimaykullayki'},
  {code:'ro',  name:'Romanian',              country:'ro', hello:'Bună ziua'},
  {code:'ru',  name:'Russian',               country:'ru', hello:'Привет'},
  {code:'skr', name:'Saraiki',               country:'pk', hello:'سلام'},
  {code:'sr',  name:'Serbian',               country:'rs', hello:'Zdravo'},
  {code:'st',  name:'Sesotho',               country:'ls', hello:'Dumela'},
  {code:'sn',  name:'Shona',                 country:'zw', hello:'Mhoro'},
  {code:'sd',  name:'Sindhi',                country:'pk', hello:'جي آئاڪ'},
  {code:'si',  name:'Sinhala',               country:'lk', hello:'ආයුබෝවන්'},
  {code:'sk',  name:'Slovak',                country:'sk', hello:'Ahoj'},
  {code:'sl',  name:'Slovenian',             country:'si', hello:'Živijo'},
  {code:'so',  name:'Somali',                country:'so', hello:'Salaan'},
  {code:'es-MX',name:'Spanish (LatAm)',      country:'mx', hello:'Hola'},
  {code:'es-ES',name:'Spanish (Spain)',      country:'es', hello:'Hola'},
  {code:'su',  name:'Sundanese',             country:'id', hello:'Halo'},
  {code:'sw',  name:'Swahili',               country:'tz', hello:'Jambo'},
  {code:'sv',  name:'Swedish',               country:'se', hello:'Hej'},
  {code:'tg',  name:'Tajik',                 country:'tj', hello:'Салом'},
  {code:'ta',  name:'Tamil',                 country:'in', hello:'வணக்கம்'},
  {code:'tt',  name:'Tatar',                 country:'ru', hello:'Сәлам'},
  {code:'te',  name:'Telugu',                country:'in', hello:'నమస్కారం'},
  {code:'th',  name:'Thai',                  country:'th', hello:'สวัสดี'},
  {code:'ti',  name:'Tigrinya',              country:'er', hello:'ሰላም'},
  {code:'tr',  name:'Turkish',               country:'tr', hello:'Merhaba'},
  {code:'tk',  name:'Turkmen',               country:'tm', hello:'Salam'},
  {code:'uk',  name:'Ukrainian',             country:'ua', hello:'Привіт'},
  {code:'ur',  name:'Urdu',                  country:'pk', hello:'سلام'},
  {code:'ug',  name:'Uyghur',                country:'cn', hello:'ھەل'},
  {code:'uz',  name:'Uzbek',                 country:'uz', hello:'Salom'},
  {code:'vi',  name:'Vietnamese',            country:'vn', hello:'Xin chào'},
  {code:'cy',  name:'Welsh',                 country:'gb', hello:'Helo'},
  {code:'wo',  name:'Wolof',                 country:'sn', hello:'Mangi dem'},
  {code:'yo',  name:'Yoruba',                country:'ng', hello:'Ẹ káàbọ̀'},
  {code:'zu',  name:'Zulu',                  country:'za', hello:'Sawubona'},
];

let showcaseTimer = null;
let currentLangIdx = 0;
let isCurrentlyVisible = false;

function buildLangChips() {
  const list = document.getElementById('langList');
  const section = document.getElementById('languages');
  if (!list || !section) return;

  // Build the chips grid
  list.innerHTML = '';
  const chips = ALL_LANGUAGES.map(lang => {
    const chip = document.createElement('div');
    chip.className = 'lang-chip';
    chip.dataset.word = lang.hello;
    chip.innerHTML = `<img src="https://flagcdn.com/w40/${lang.country}.png" alt="${lang.name}"> ${lang.name}`;
    list.appendChild(chip);
    return chip;
  });

  let scrollTarget = 0;

  // Strictly horizontal damping loop - bypasses all native smooth-scroll bugs
  function scrollLoop() {
    if (isCurrentlyVisible) {
      const diff = scrollTarget - list.scrollLeft;
      if (Math.abs(diff) > 0.5) {
        list.scrollLeft += diff * 0.1; 
      }
    }
    requestAnimationFrame(scrollLoop);
  }
  requestAnimationFrame(scrollLoop);

  const updateActive = (idx) => {
    if (!isCurrentlyVisible) return;
    currentLangIdx = idx;
    chips.forEach(c => c.classList.remove('active'));
    const target = chips[idx];
    if (target) {
      target.classList.add('active');
      updateLangShowcase(target.dataset.word);
      scrollTarget = target.offsetLeft - (list.clientWidth / 2) + (target.clientWidth / 2);
    }
  };

  const stopCycle = () => { if (showcaseTimer) { clearInterval(showcaseTimer); showcaseTimer = null; } };
  const startCycle = () => {
    stopCycle();
    showcaseTimer = setInterval(() => {
      updateActive((currentLangIdx + 1) % chips.length);
    }, 4000);
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      isCurrentlyVisible = entry.isIntersecting && entry.intersectionRatio >= 0.4;
      if (isCurrentlyVisible) startCycle();
      else stopCycle();
    });
  }, { threshold: [0, 0.4] });
  observer.observe(section);

  chips.forEach((chip, i) => {
    chip.addEventListener('click', () => {
      updateActive(i);
      startCycle();
    });
  });

  // Small delay to ensure layout is ready before first update
  setTimeout(() => { if (isCurrentlyVisible) updateActive(0); }, 500);
}

// ─── LANGUAGE SHOWCASE — REAL DATA ──────────────────────
async function loadShowcaseData() {
  if (!window.supabaseClient) return;

  // For now simple select of a few words
  const { data: words } = await window.supabaseClient
    .from('vocabulary')
    .select('word, lang_code')
    .in('concept_id', ['1', '4', '8'])
    .limit(10);

  if (words) {
    // We could dynamically update the language switcher or a showcase grid
    console.log('Seedling dynamic vocabulary loaded:', words.length);
  }
}

// ─── ACHIEVEMENT SOCIAL PROOF ───────────────────────────
async function fetchAchievementStats() {
  if (!window.supabaseClient) return;
  try {
    // 1. First Steps (10 words)
    const { count: firstSteps } = await window.supabaseClient
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('total_words_learned', 10);

    // 2. Week Warrior (7 day streak)
    const { count: weekWarrior } = await window.supabaseClient
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('current_streak', 7);

    // 3. Polyglot (5000 XP)
    const { count: polyglots } = await window.supabaseClient
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('total_xp', 5000);

    // 4. Ancient Oak (Level 10 / 9000 XP)
    const { count: ancientOaks } = await window.supabaseClient
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('total_xp', 9000);

    const badgeShowcase = document.querySelector('.achievement-showcase');
    if (!badgeShowcase) return;

    const badgeCards = badgeShowcase.querySelectorAll('.badge-card');
    const counts = [firstSteps, weekWarrior, polyglots, ancientOaks];
    
    badgeCards.forEach((card, i) => {
      if (counts[i] !== undefined && counts[i] !== null) {
        const countSpan = document.createElement('div');
        countSpan.className = 'badge-proof';
        countSpan.style.marginTop = '12px';
        countSpan.style.fontSize = '0.75rem';
        countSpan.style.color = 'var(--water)';
        countSpan.style.fontWeight = '600';
        countSpan.innerHTML = `✨ <b>${counts[i].toLocaleString()}</b> gardeners have earned this!`;
        card.appendChild(countSpan);
      }
    });
  } catch (err) {
    console.error('Failed to fetch achievement stats:', err);
  }
}

// ─── TOP GARDENERS RANKINGS ─────────────────────────────
async function fetchTopGardeners() {
  if (!window.supabaseClient) return;
  const tableEl = document.getElementById('rankingsTable');
  if (!tableEl) return;

  try {
    const { data: topUsers, error } = await window.supabaseClient
      .from('user_stats')
      .select('total_xp, profiles(display_name)')
      .order('total_xp', { ascending: false })
      .limit(5);

    if (error) throw error;

    tableEl.innerHTML = '';
    topUsers.forEach((user, index) => {
      const row = document.createElement('div');
      row.className = `rank-row rank-${index + 1}`;
      
      const initials = user.display_name ? user.display_name.substring(0, 2).toUpperCase() : 'GS';
      
      row.innerHTML = `
        <div class="rank-num">#${index + 1}</div>
        <div class="rank-info">
          <div class="rank-avatar">${initials}</div>
          <div class="rank-name">${(user.profiles && user.profiles.display_name) || 'Master Gardener'}</div>
        </div>
        <div class="rank-xp">${user.total_xp.toLocaleString()} Growth Points</div>
      `;
      tableEl.appendChild(row);
    });
  } catch (err) {
    console.error('Failed to fetch rankings:', err);
  }
}

// ─── MASCOT VOICE (LIVE MILESTONES) ──────────────────────
const milestones = [
    "A new gardener just joined the Spanish ecosystem! 🇪🇸",
    "The community just reached 50,000 words planted! 🌱",
    "Someone just earned the 'Ancient Oak' badge! 🏆",
    "Did you know? Learning for 5 mins a day keeps the garden blooming! ✨",
    "Multiple gardeners are currently blooming in the Japanese grove! 🇯🇵"
];

function showMascotBubble() {
    const bubble = document.getElementById('mascotBubble');
    const content = bubble?.querySelector('.bubble-content');
    if (!bubble || !content) return;

    // Show random milestone
    content.innerText = milestones[Math.floor(Math.random() * milestones.length)];
    bubble.classList.add('visible');

    // Hide after 6 seconds
    setTimeout(() => {
        bubble.classList.remove('visible');
    }, 6000);
}

// ─── LIVE GROWING COUNTER ───────────────────────────────
function updateLiveCounter() {
    const el = document.getElementById('liveGrowing');
    if (!el) return;
    
    // Realistic drift based on community size
    let current = parseInt(el.innerText) || 124;
    const drift = Math.floor(Math.random() * 7) - 3; // -3 to +3
    current = Math.max(80, current + drift);
    
    el.innerText = current;
}

// ─── REAL-TIME STATS FROM SUPABASE ───────────────────────
async function fetchGlobalStats() {
  if (!window.supabaseClient) return;

  try {
    // 1. Total Learners (Profiles)
    const { count: userCount } = await window.supabaseClient
      .from('profiles')
      .select('*', { count: 'exact', head: true });

    // 2. Total Words Planted (All user_words)
    const { count: wordCount } = await window.supabaseClient
      .from('user_words')
      .select('*', { count: 'exact', head: true });

    // 3. Languages Supported
    const { data: langData } = await window.supabaseClient
      .from('vocabulary')
      .select('lang_code');
    const uniqueLangs = new Set(langData.map(l => l.lang_code)).size;

    // Update the DOM data-target attributes
    const usersEl = document.querySelector('[data-stat="users"]');
    const wordsEl = document.querySelector('[data-stat="words"]');
    const langsEl = document.querySelector('[data-stat="langs"]');

    if (usersEl) usersEl.dataset.target = userCount || 1000;
    if (wordsEl) wordsEl.dataset.target = wordCount || 50000;
    if (langsEl) langsEl.dataset.target = uniqueLangs || 40;

    // Trigger counters manually if they haven't been observed yet
    // Or just let the IntersectionObserver handle it if they aren't visible yet
  } catch (err) {
    console.error('Failed to fetch global seedling stats:', err);
  }
}

// ─── HERO WATERING MECHANIC ─────────────────────────────
if (heroCanvas) {
  heroCanvas.addEventListener('mousedown', (e) => {
    const rect = heroCanvas.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const clickY = e.clientY - rect.top;
    
    // Spawn a burst of "Water/Glow" particles
    for (let i = 0; i < 15; i++) {
        const p = createParticle();
        p.x = clickX;
        p.y = clickY;
        p.vx = (Math.random() - 0.5) * 4;
        p.vy = (Math.random() - 0.5) * 4;
        p.hue = '#4FC3F7'; // Water blue
        p.life = 1;
        hParticles.push(p);
    }
  });
}

// ─── GARDEN PROGRESSION LOGIC ────────────────────────────
async function updateGardenProgression() {
  if (!window.supabaseClient) return;
  const { count } = await window.supabaseClient
    .from('user_words')
    .select('*', { count: 'exact', head: true });
    
  const total = count || 0;
  const fill = document.getElementById('gardenFill');
  const stageDesc = document.getElementById('gardenStage');
  const stages = document.querySelectorAll('.gp-stages span');
  
  // Stages based on words mastered
  const milestones = [1000, 10000, 50000, 100000, 250000];
  let activeIdx = 0;
  milestones.forEach((m, i) => { if (total >= m) activeIdx = i; });
  
  const stageNames = ["Seedling Sprout", "Growing Glade", "Blooming Garden", "Ancient Canopy", "Universal Garden"];
  const progressPercent = Math.min((total / milestones[ milestones.length - 1]) * 100, 100);
  
  if (fill) fill.style.width = `${progressPercent}%`;
  if (stageDesc) stageDesc.textContent = `Community Status: ${stageNames[activeIdx]}`;
  
  stages.forEach((s, i) => {
    s.classList.toggle('active', i === activeIdx);
  });
}

// ─── LIVE BLOOMINGS TICKER ──────────────────────────────
async function initLiveTicker() {
  const ticker = document.getElementById('liveTicker');
  if (!ticker || !window.supabaseClient) return;

  // Fetch recent words mastered
  const { data: recent } = await window.supabaseClient
    .from('user_words')
    .select('created_at, vocabulary!inner(word, lang_code)')
    .order('created_at', { ascending: false })
    .limit(10);

  if (recent && recent.length > 0) {
    ticker.innerHTML = recent.map(r => `
      <span>🌸 <b>${r.vocabulary.word}</b> was just planted in <b>${r.vocabulary.lang_code.toUpperCase()}</b> ecosystem!</span>
    `).join('') + ticker.innerHTML; // Keep loading message at end for loop
  }
}

// Initialize all deep sync features
window.addEventListener('DOMContentLoaded', () => {
  buildLangChips();         // Build the 121 language chip list
  fetchGlobalStats();
  loadShowcaseData();
  updateGardenProgression();
  initLiveTicker();
  fetchAchievementStats();
  fetchTopGardeners();
  
  // Start periodic mascot voice
  setInterval(showMascotBubble, 15000);
  setTimeout(showMascotBubble, 2000); // Initial welcome
  
  // Live pulse
  setInterval(updateLiveCounter, 3000);
});

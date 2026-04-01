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
      hue: Math.random() > 0.5 ? '#4BAE4F' : '#FFD54F',
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

// ─── LANGUAGE SHOWCASE ────────────────────────────────────
const translations = {
  'Hello':      [['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇮🇹 Italian','Ciao'],['🇩🇪 German','Hallo'],['🇯🇵 Japanese','こんにちは'],['🇧🇷 Portuguese','Olá']],
  'Bonjour':    [['🇬🇧 English','Hello'],['🇪🇸 Spanish','Hola'],['🇮🇹 Italian','Ciao'],['🇩🇪 German','Hallo'],['🇯🇵 Japanese','こんにちは'],['🇨🇳 Chinese','你好']],
  'Hola':       [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇮🇹 Italian','Ciao'],['🇩🇪 German','Hallo'],['🇵🇹 Portuguese','Olá'],['🇧🇷 Brazilian','Oi']],
  'Ciao':       [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇩🇪 German','Hallo'],['🇯🇵 Japanese','こんにちは'],['🇰🇷 Korean','안녕하세요']],
  'Hallo':      [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇮🇹 Italian','Ciao'],['🇯🇵 Japanese','こんにちは'],['🇰🇷 Korean','안녕하세요']],
  'Olá':        [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇮🇹 Italian','Ciao'],['🇩🇪 German','Hallo'],['🇯🇵 Japanese','こんにちは']],
  'こんにちは':  [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇨🇳 Chinese','你好'],['🇰🇷 Korean','안녕하세요'],['🇩🇪 German','Hallo']],
  '안녕하세요':  [['🇬🇧 English','Hello'],['🇯🇵 Japanese','こんにちは'],['🇨🇳 Chinese','你好'],['🇪🇸 Spanish','Hola'],['🇫🇷 French','Bonjour'],['🇩🇪 German','Hallo']],
  'Merhaba':    [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇩🇪 German','Hallo'],['🇦🇿 Azerbaijani','Salam'],['🇯🇵 Japanese','こんにちは']],
  'Привет':     [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇺🇦 Ukrainian','Привіт'],['🇧🇬 Bulgarian','Здравей'],['🇩🇪 German','Hallo'],['🇪🇸 Spanish','Hola']],
  '你好':        [['🇬🇧 English','Hello'],['🇯🇵 Japanese','こんにちは'],['🇰🇷 Korean','안녕하세요'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇩🇪 German','Hallo']],
  'مرحبا':      [['🇬🇧 English','Hello'],['🇫🇷 French','Bonjour'],['🇪🇸 Spanish','Hola'],['🇩🇪 German','Hallo'],['🇹🇷 Turkish','Merhaba'],['🇮🇹 Italian','Ciao']],
};

const langChips = document.querySelectorAll('.lang-chip');
const langCenterWord = document.getElementById('langCenterWord');
const langTrack = document.getElementById('langTrack');

function updateLangShowcase(word) {
  // Animate out
  langCenterWord.style.opacity = '0';
  langCenterWord.style.transform = 'scale(0.8)';
  setTimeout(() => {
    langCenterWord.textContent = word;
    langCenterWord.style.opacity = '1';
    langCenterWord.style.transform = 'scale(1)';
  }, 300);

  // Update translation cards
  const trans = translations[word] || [];
  langTrack.innerHTML = trans.map(([lang, t]) => `
    <div class="lang-translation-card">${lang} → <strong>${t}</strong></div>
  `).join('');
}

langChips.forEach(chip => {
  chip.addEventListener('click', () => {
    langChips.forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    updateLangShowcase(chip.dataset.word);
  });
});

// Init with Hello
updateLangShowcase('Hello');

// Auto-cycle every 4 seconds
let langIdx = 0;
const langWords = [...langChips].map(c => c.dataset.word);
setInterval(() => {
  langIdx = (langIdx + 1) % langWords.length;
  langChips.forEach(c => c.classList.remove('active'));
  langChips[langIdx].classList.add('active');
  updateLangShowcase(langWords[langIdx]);
}, 4000);

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

console.log('🌱 Seedling Marketing Site — Living Forest Edition loaded');

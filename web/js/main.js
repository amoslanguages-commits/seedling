/* ═══════════════════════════════════════════════════════════
   SEEDLING MARKETING — MAIN JAVASCRIPT
   Navbar, Scroll Reveals, Hero Canvas, Counters, Language
   Switcher, FAQ, Parallax Particles
═══════════════════════════════════════════════════════════ */

document.addEventListener('DOMContentLoaded', () => {
  // ─── NAVBAR SCROLL EFFECT ────────────────────────────────
  const navbar = document.getElementById('navbar');
  const hamburger = document.getElementById('hamburger');
  const navLinks = document.getElementById('navLinks');

  if (navbar) {
    window.addEventListener('scroll', () => {
      if (window.scrollY > 40) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    }, { passive: true });
  }

  if (hamburger && navLinks) {
    hamburger.addEventListener('click', () => {
      navLinks.classList.toggle('open');
    });

    // Close menu when link clicked
    navLinks.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', () => navLinks.classList.remove('open'));
    });
  }

  // ─── SCROLL REVEAL ────────────────────────────────────────
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
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
    '.features-grid, .testimonials, .pricing-grid-app, .footer-links, .snapshot-grid, .languages-full-grid'
  );
  grids.forEach(grid => {
    grid.querySelectorAll('.reveal').forEach((el, i) => {
      el.dataset.delay = i * 80;
    });
  });

  document.querySelectorAll('.reveal').forEach(el => revealObserver.observe(el));

  // ─── HERO CANVAS — FLOATING PARTICLES ─────────────────────
  const heroCanvas = document.getElementById('heroCanvas');
  const createParticle = (hW, hH) => {
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
  };

  if (heroCanvas) {
    const hCtx = heroCanvas.getContext('2d');
    let hW, hH, hParticles = [];

    const resizeHeroCanvas = () => {
      hW = heroCanvas.width = heroCanvas.offsetWidth;
      hH = heroCanvas.height = heroCanvas.offsetHeight;
    };

    const initParticles = () => {
      hParticles = [];
      for (let i = 0; i < 80; i++) {
        const p = createParticle(hW, hH);
        p.life = Math.random();
        hParticles.push(p);
      }
    };

    const animateHero = () => {
      hCtx.clearRect(0, 0, hW, hH);
      hParticles.forEach((p, i) => {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= p.decay;
        if (p.life <= 0 || p.y < -20) {
          hParticles[i] = createParticle(hW, hH);
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
    };

    resizeHeroCanvas();
    initParticles();
    animateHero();
    window.addEventListener('resize', () => { resizeHeroCanvas(); initParticles(); });

    heroCanvas.addEventListener('mousedown', (e) => {
      const rect = heroCanvas.getBoundingClientRect();
      const clickX = e.clientX - rect.left;
      const clickY = e.clientY - rect.top;
      for (let i = 0; i < 15; i++) {
        const p = createParticle(hW, hH);
        p.x = clickX;
        p.y = clickY;
        p.vx = (Math.random() - 0.5) * 4;
        p.vy = (Math.random() - 0.5) * 4;
        p.hue = '#4FC3F7';
        p.life = 1;
        hParticles.push(p);
      }
    });
  }

  // ─── FAQ ACCORDION ────────────────────────────────────────
  window.toggleFaq = (btn) => {
    const item = btn.closest('.faq-item');
    const isOpen = item.classList.contains('open');
    document.querySelectorAll('.faq-item.open').forEach(el => el.classList.remove('open'));
    if (!isOpen) item.classList.add('open');
  };

  // ─── SMOOTH SCROLL FOR ANCHOR LINKS ──────────────────────
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', (e) => {
      const href = a.getAttribute('href');
      if (href === '#') return;
      const target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // ─── SRS FILL ANIMATION TRIGGER ──────────────────────────
  const srsFills = document.querySelectorAll('.srs-fill');
  if (srsFills.length > 0) {
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
  }

  // ─── LANGUAGES LIST & CAROUSEL ─────────────────────────────
  const ALL_LANGUAGES = [
    {code:'om',  name:'Afaan Oromo', country:'et', hello:'Akkam'},
    {code:'af',  name:'Afrikaans', country:'za', hello:'Hallo'},
    {code:'ar',  name:'Arabic', country:'sa', hello:'مرحبا'},
    {code:'ca',  name:'Catalan', country:'es', hello:'Hola'},
    {code:'zh-CN',name:'Chinese', country:'cn', hello:'你好'},
    {code:'hr',  name:'Croatian', country:'hr', hello:'Zdravo'},
    {code:'cs',  name:'Czech', country:'cz', hello:'Ahoj'},
    {code:'da',  name:'Danish', country:'dk', hello:'Hej'},
    {code:'nl',  name:'Dutch', country:'nl', hello:'Hallo'},
    {code:'en-US',name:'English', country:'us', hello:'Hello'},
    {code:'fi',  name:'Finnish', country:'fi', hello:'Hei'},
    {code:'fr',  name:'French', country:'fr', hello:'Bonjour'},
    {code:'de',  name:'German', country:'de', hello:'Hallo'},
    {code:'el',  name:'Greek', country:'gr', hello:'Γεια σας'},
    {code:'he',  name:'Hebrew', country:'il', hello:'שלום'},
    {code:'hi',  name:'Hindi', country:'in', hello:'नमस्ते'},
    {code:'hu',  name:'Hungarian', country:'hu', hello:'Helló'},
    {code:'id',  name:'Indonesian', country:'id', hello:'Halo'},
    {code:'it',  name:'Italian', country:'it', hello:'Ciao'},
    {code:'ja',  name:'Japanese', country:'jp', hello:'こんにちは'},
    {code:'ko',  name:'Korean', country:'kr', hello:'안녕하세요'},
    {code:'no',  name:'Norwegian', country:'no', hello:'Hei'},
    {code:'pl',  name:'Polish', country:'pl', hello:'Cześć'},
    {code:'pt-BR',name:'Portuguese', country:'br', hello:'Olá'},
    {code:'ru',  name:'Russian', country:'ru', hello:'Привет'},
    {code:'es-ES',name:'Spanish', country:'es', hello:'Hola'},
    {code:'sw',  name:'Swahili', country:'tz', hello:'Jambo'},
    {code:'sv',  name:'Swedish', country:'se', hello:'Hej'},
    {code:'th',  name:'Thai', country:'th', hello:'สวัสดี'},
    {code:'tr',  name:'Turkish', country:'tr', hello:'Merhaba'},
    {code:'uk',  name:'Ukrainian', country:'ua', hello:'Привіт'},
    {code:'vi',  name:'Vietnamese', country:'vn', hello:'Xin chào'}
  ];

  const carouselTrack = document.getElementById('carouselTrack');
  const languagesGrid = document.getElementById('languagesGrid');
  const centerWord = document.getElementById('centerWord');
  const centerLang = document.getElementById('centerLang');

  if (carouselTrack) {
    // Populate Carousel
    carouselTrack.innerHTML = '';
    ALL_LANGUAGES.forEach(lang => {
      const chip = document.createElement('div');
      chip.className = 'carousel-item';
      chip.innerHTML = `<img src="https://flagcdn.com/w40/${lang.country}.png" alt="${lang.name}"> ${lang.name}`;
      chip.addEventListener('click', () => updateCenter(lang));
      carouselTrack.appendChild(chip);
    });

    let currentIdx = 0;
    const updateCenter = (lang) => {
      if (centerWord) {
        centerWord.style.opacity = '0';
        centerWord.style.transform = 'translateY(10px)';
        setTimeout(() => {
          centerWord.textContent = lang.hello;
          centerLang.textContent = `${lang.name} — ${lang.country.toUpperCase()}`;
          centerWord.style.opacity = '1';
          centerWord.style.transform = 'translateY(0)';
        }, 300);
      }
    };

    setInterval(() => {
      currentIdx = (currentIdx + 1) % ALL_LANGUAGES.length;
      updateCenter(ALL_LANGUAGES[currentIdx]);
      // Gentle scroll
      const activeItem = carouselTrack.children[currentIdx];
      carouselTrack.scrollTo({
        left: activeItem.offsetLeft - carouselTrack.offsetWidth/2 + activeItem.offsetWidth/2,
        behavior: 'smooth'
      });
    }, 4000);
  }

  if (languagesGrid) {
    languagesGrid.innerHTML = '';
    ALL_LANGUAGES.forEach(lang => {
      const card = document.createElement('div');
      card.className = 'lang-card reveal';
      card.innerHTML = `
        <div class="lang-flag-large"><img src="https://flagcdn.com/w80/${lang.country}.png"></div>
        <div class="lang-info">
          <h3>${lang.name}</h3>
          <p>"${lang.hello}"</p>
        </div>
      `;
      languagesGrid.appendChild(card);
    });
  }

  // ─── MASCOT LOADER ────────────────────────────────────────
  if (window.SproutMascot && document.getElementById('mascotCanvas')) {
    window.sprout = new SproutMascot('mascotCanvas');
  }

  console.log('🌱 Seedling Marketing Site — Page Loaded');
});

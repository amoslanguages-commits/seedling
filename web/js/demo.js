/* ═══════════════════════════════════════════════════════════
   SEEDLING MARKETING — INTERACTIVE DEMO QUIZ ENGINE
   Renders a real quiz experience directly in the browser
   using Canvas + vanilla JS. Mirrors the app's quiz style.
═══════════════════════════════════════════════════════════ */

const DEMO_WORDS = [
  { word: 'Bonjour', lang: 'French 🇫🇷', correct: 'Hello', options: ['Hello', 'Goodbye', 'Thank you', 'Please'] },
  { word: 'Hola', lang: 'Spanish 🇪🇸', correct: 'Hello', options: ['Run', 'Hello', 'Water', 'House'] },
  { word: 'Ciao', lang: 'Italian 🇮🇹', correct: 'Hello/Goodbye', options: ['Hello/Goodbye', 'Thank you', 'Hungry', 'Love'] },
  { word: 'Danke', lang: 'German 🇩🇪', correct: 'Thank you', options: ['Sorry', 'Thank you', 'Hello', 'Bread'] },
  { word: 'Merci', lang: 'French 🇫🇷', correct: 'Thank you', options: ['Sorry', 'Yes', 'Thank you', 'Beautiful'] },
  { word: 'Arigato', lang: 'Japanese 🇯🇵', correct: 'Thank you', options: ['Thank you', 'Goodbye', 'Please', 'Water'] },
  { word: 'Agua', lang: 'Spanish 🇪🇸', correct: 'Water', options: ['Fire', 'Tree', 'Water', 'Sky'] },
  { word: 'Belle', lang: 'French 🇫🇷', correct: 'Beautiful', options: ['Beautiful', 'Flower', 'Night', 'Fast'] },
  { word: 'Amour', lang: 'French 🇫🇷', correct: 'Love', options: ['Fear', 'Sun', 'Love', 'Cold'] },
  { word: 'Gato', lang: 'Spanish 🇪🇸', correct: 'Cat', options: ['Dog', 'Cat', 'Bird', 'Fish'] },
];

let demoIdx = 0;
let demoShuffled = shuffleArr([...DEMO_WORDS]);
let demoAnswered = false;

function shuffleArr(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function renderDemoWord() {
  const item = demoShuffled[demoIdx % demoShuffled.length];
  demoAnswered = false;

  document.getElementById('demoWord').textContent = item.word;
  document.getElementById('demoWord').style.transform = 'scale(1)';
  document.getElementById('demoLang') && (document.getElementById('demoLang').textContent = item.lang);

  // Label
  const langEl = document.querySelector('.demo-lang');
  if (langEl) langEl.textContent = item.lang;

  // Options — shuffle them
  const shuffledOpts = shuffleArr([...item.options]);
  const container = document.getElementById('demoOptions');
  container.innerHTML = '';
  shuffledOpts.forEach(opt => {
    const btn = document.createElement('button');
    btn.className = 'demo-opt';
    btn.textContent = opt;
    btn.onclick = () => handleDemoAnswer(btn, opt, item.correct);
    container.appendChild(btn);
  });

  document.getElementById('demoFeedback').textContent = '';
  document.getElementById('demoFeedback').style.color = '';
  document.getElementById('demoNext').style.display = 'none';

  // Draw the canvas garden
  drawDemoGarden('idle');
}

function handleDemoAnswer(btn, chosen, correct) {
  if (demoAnswered) return;
  demoAnswered = true;

  // Disable all
  document.querySelectorAll('.demo-opt').forEach(b => {
    b.disabled = true;
    if (b.textContent === correct) b.classList.add('correct');
  });

  const isRight = chosen === correct;
  if (!isRight) btn.classList.add('wrong');

  const feedback = document.getElementById('demoFeedback');
  if (isRight) {
    feedback.textContent = '🌸 Correct! Your plant blooms!';
    feedback.style.color = '#66BB6A';
    drawDemoGarden('correct');
  } else {
    feedback.textContent = `🥀 The answer was: ${correct}`;
    feedback.style.color = '#E57373';
    drawDemoGarden('wrong');
  }

  // Bounce the word
  const wordEl = document.getElementById('demoWord');
  wordEl.style.transition = 'transform 0.2s';
  wordEl.style.transform = 'scale(1.12)';
  setTimeout(() => wordEl.style.transform = 'scale(1)', 300);

  document.getElementById('demoNext').style.display = 'block';
}

function nextDemoWord() {
  demoIdx++;
  renderDemoWord();
}
window.nextDemoWord = nextDemoWord;

// ─── DEMO CANVAS PAINTER ──────────────────────────────────
const demoCanvas = document.getElementById('demoCanvas');
let bloomAnim = null;
let bloomProg = 0;

function drawDemoGarden(state) {
  if (!demoCanvas) return;
  const ctx = demoCanvas.getContext('2d');
  const W = demoCanvas.width;
  const H = demoCanvas.height;

  if (bloomAnim) { cancelAnimationFrame(bloomAnim); bloomAnim = null; }

  if (state === 'correct') {
    bloomProg = 0;
    function animBloom() {
      bloomProg = Math.min(bloomProg + 0.025, 1);
      renderGarden(ctx, W, H, bloomProg, 'correct');
      if (bloomProg < 1) bloomAnim = requestAnimationFrame(animBloom);
    }
    animBloom();
  } else if (state === 'wrong') {
    bloomProg = 0;
    function animWilt() {
      bloomProg = Math.min(bloomProg + 0.03, 1);
      renderGarden(ctx, W, H, bloomProg, 'wrong');
      if (bloomProg < 1) bloomAnim = requestAnimationFrame(animWilt);
    }
    animWilt();
  } else {
    bloomProg = 0;
    let idleT = 0;
    function animIdle() {
      idleT += 0.015;
      renderGarden(ctx, W, H, Math.sin(idleT) * 0.15 + 0.5, 'idle');
      if (!demoAnswered || state === 'idle') bloomAnim = requestAnimationFrame(animIdle);
    }
    animIdle();
  }
}

function renderGarden(ctx, W, H, prog, state) {
  ctx.clearRect(0, 0, W, H);

  const groundY = H * 0.62;

  // Sky gradient
  const sky = ctx.createLinearGradient(0, 0, 0, groundY);
  sky.addColorStop(0, '#0B1910');
  sky.addColorStop(1, 'rgba(20,38,26,0.4)');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, W, groundY);

  // Ground  
  const ground = ctx.createLinearGradient(0, groundY, 0, H);
  ground.addColorStop(0, '#3E2723CC');
  ground.addColorStop(1, '#07140BE0');
  ctx.fillStyle = ground;

  // Wavy ground path
  ctx.beginPath();
  ctx.moveTo(0, groundY);
  for (let x = 0; x <= W; x += 20) {
    const y = groundY + Math.sin((x / W) * Math.PI * 4) * 4;
    ctx.lineTo(x, y);
  }
  ctx.lineTo(W, H);
  ctx.lineTo(0, H);
  ctx.closePath();
  ctx.fill();

  const cx = W / 2;
  const stemH = 40 + prog * 70;
  const stemTop = groundY - stemH;

  // Stem color based on state
  let stemColor = '#4BAE4F';
  if (state === 'wrong') stemColor = lerpColor('#4BAE4F', '#E57373', prog);
  if (state === 'correct') stemColor = lerpColor('#4BAE4F', '#FFD54F', prog * 0.5);

  // Stem
  ctx.strokeStyle = stemColor;
  ctx.lineWidth = 6;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(cx, groundY);
  ctx.lineTo(cx, stemTop);
  ctx.stroke();

  // Leaves
  if (prog > 0.2) {
    const leafProg = (prog - 0.2) / 0.8;
    const leafColor = state === 'wrong'
      ? lerpColor('#81C784', '#E57373', prog * 0.5)
      : '#81C784';
    drawLeaf(ctx, cx, stemTop + stemH * 0.4, -0.5, 22 * leafProg, leafColor);
    drawLeaf(ctx, cx, stemTop + stemH * 0.2, 0.5, 18 * leafProg, leafColor);
  }

  // Bloom / Wilt effect
  if (state === 'correct' && prog > 0.5) {
    const fp = (prog - 0.5) / 0.5;
    drawFlower(ctx, cx, stemTop, fp);
  }
  if (state === 'wrong' && prog > 0.4) {
    // Drooping leaves
    const dp = (prog - 0.4) / 0.6;
    drawWilt(ctx, cx, stemTop, dp);
  }

  // Particles
  if (state === 'correct' && prog > 0.3) {
    drawParticles(ctx, cx, stemTop, prog, '#FFD54F');
  }

  // Soil texture dots
  ctx.fillStyle = 'rgba(7,20,11,0.4)';
  const rng = mulberry32(42);
  for (let i = 0; i < 6; i++) {
    const rx = rng() * W;
    const ry = groundY + 8 + rng() * 16;
    ctx.beginPath();
    ctx.arc(rx, ry, 2 + rng() * 3, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawLeaf(ctx, x, y, angle, size, color) {
  if (size <= 0) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.quadraticCurveTo(-size / 2, -size / 3, 0, -size);
  ctx.quadraticCurveTo(size / 2, -size / 3, 0, 0);
  ctx.fill();
  ctx.restore();
}

function drawFlower(ctx, cx, cy, p) {
  const petals = 8;
  const pLen = 22 * p;
  ctx.fillStyle = `rgba(255,213,79,${p * 0.9})`;
  for (let i = 0; i < petals; i++) {
    const a = (i / petals) * Math.PI * 2;
    const ex = cx + Math.cos(a) * pLen;
    const ey = cy + Math.sin(a) * pLen;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.quadraticCurveTo(
      cx + Math.cos(a + 0.4) * pLen * 0.55,
      cy + Math.sin(a + 0.4) * pLen * 0.55,
      ex, ey
    );
    ctx.quadraticCurveTo(
      cx + Math.cos(a - 0.4) * pLen * 0.55,
      cy + Math.sin(a - 0.4) * pLen * 0.55,
      cx, cy
    );
    ctx.fill();
  }
  // Center
  ctx.fillStyle = '#07140B';
  ctx.beginPath();
  ctx.arc(cx, cy, 7 * p, 0, Math.PI * 2);
  ctx.fill();

  // Glow
  const grd = ctx.createRadialGradient(cx, cy, 0, cx, cy, pLen + 20);
  grd.addColorStop(0, `rgba(255,213,79,${0.3 * p})`);
  grd.addColorStop(1, 'rgba(255,213,79,0)');
  ctx.fillStyle = grd;
  ctx.beginPath();
  ctx.arc(cx, cy, pLen + 20, 0, Math.PI * 2);
  ctx.fill();
}

function drawWilt(ctx, cx, cy, p) {
  ctx.strokeStyle = `rgba(229,115,115,${p * 0.6})`;
  ctx.lineWidth = 3;
  ctx.setLineDash([4, 4]);
  ctx.beginPath();
  ctx.arc(cx, cy, 20 * p, 0, Math.PI);
  ctx.stroke();
  ctx.setLineDash([]);
}

const particlePool = [];
function drawParticles(ctx, cx, cy, prog, color) {
  if (particlePool.length < 12) {
    for (let i = 0; i < 12; i++) {
      particlePool.push({
        angle: (i / 12) * Math.PI * 2,
        speed: 1 + Math.random() * 2,
        size: 2 + Math.random() * 3,
        offset: Math.random() * Math.PI
      });
    }
  }
  particlePool.forEach(pt => {
    const dist = prog * 50;
    const px = cx + Math.cos(pt.angle + pt.offset) * dist;
    const py = cy + Math.sin(pt.angle + pt.offset) * dist;
    ctx.globalAlpha = (1 - prog) * 0.8;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(px, py, pt.size * (1 - prog * 0.5), 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.globalAlpha = 1;
}

// ─── UTILS ───────────────────────────────────────────────
function lerpColor(a, b, t) {
  const ah = parseInt(a.slice(1), 16);
  const bh = parseInt(b.slice(1), 16);
  const ar = (ah >> 16) & 0xff, ag = (ah >> 8) & 0xff, ab = ah & 0xff;
  const br = (bh >> 16) & 0xff, bg = (bh >> 8) & 0xff, bb = bh & 0xff;
  const rr = Math.round(ar + (br - ar) * t);
  const rg = Math.round(ag + (bg - ag) * t);
  const rb = Math.round(ab + (bb - ab) * t);
  return `rgb(${rr},${rg},${rb})`;
}

function mulberry32(seed) {
  return function () {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

// ─── INIT ─────────────────────────────────────────────────
if (document.getElementById('demoCanvas')) {
  // Wait for canvas to be in DOM
  setTimeout(() => {
    renderDemoWord();
  }, 200);
}

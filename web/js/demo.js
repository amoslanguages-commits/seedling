/* ═══════════════════════════════════════════════════════════
   SEEDLING MARKETING — INTERACTIVE DEMO QUIZ ENGINE
   Renders a real quiz experience directly in the browser
   using Canvas + vanilla JS. Mirrors the app's quiz style.
   Data: Fetches from Supabase get_random_quiz_pairs RPC,
   with a static fallback for offline/no-auth scenarios.
═══════════════════════════════════════════════════════════ */

// ─── STATIC FALLBACK DATA ─────────────────────────────────
const DEMO_WORDS_FALLBACK = [
  { word: 'Bonjour', lang: 'French 🇫🇷', correct: 'Hello', options: ['Hello', 'Goodbye', 'Thank you', 'Please'] },
  { word: 'Hola', lang: 'Spanish 🇪🇸', correct: 'Hello', options: ['Run', 'Hello', 'Water', 'House'] },
  { word: 'Ciao', lang: 'Italian 🇮🇹', correct: 'Hello / Goodbye', options: ['Hello / Goodbye', 'Thank you', 'Hungry', 'Love'] },
  { word: 'Danke', lang: 'German 🇩🇪', correct: 'Thank you', options: ['Sorry', 'Thank you', 'Hello', 'Bread'] },
  { word: 'Merci', lang: 'French 🇫🇷', correct: 'Thank you', options: ['Sorry', 'Yes', 'Thank you', 'Beautiful'] },
  { word: 'Arigatou', lang: 'Japanese 🇯🇵', correct: 'Thank you', options: ['Thank you', 'Goodbye', 'Please', 'Water'] },
  { word: 'Agua', lang: 'Spanish 🇪🇸', correct: 'Water', options: ['Fire', 'Tree', 'Water', 'Sky'] },
  { word: 'Belle', lang: 'French 🇫🇷', correct: 'Beautiful', options: ['Beautiful', 'Flower', 'Night', 'Fast'] },
  { word: 'Amour', lang: 'French 🇫🇷', correct: 'Love', options: ['Fear', 'Sun', 'Love', 'Cold'] },
  { word: 'Gato', lang: 'Spanish 🇪🇸', correct: 'Cat', options: ['Dog', 'Cat', 'Bird', 'Fish'] },
  { word: 'Libro', lang: 'Spanish 🇪🇸', correct: 'Book', options: ['Pen', 'Book', 'Table', 'Chair'] },
  { word: 'Haus', lang: 'German 🇩🇪', correct: 'House', options: ['Car', 'House', 'Street', 'River'] },
];

// ─── STATE ────────────────────────────────────────────────
let demoIdx = 0;
let demoShuffled = [];
let demoAnswered = false;

// ─── LANGUAGE CODE → DISPLAY LABEL ───────────────────────
const LANG_LABELS = {
  'om':    'Afaan Oromo 🇪🇹',
  'af':    'Afrikaans 🇿🇦',
  'ak':    'Akan / Twi 🇬🇭',
  'sq':    'Albanian 🇦🇱',
  'am':    'Amharic 🇪🇹',
  'ar':    'Arabic 🇸🇦',
  'hy':    'Armenian 🇦🇲',
  'as':    'Assamese 🇮🇳',
  'az':    'Azerbaijani 🇦🇿',
  'eu':    'Basque 🇪🇸',
  'be':    'Belarusian 🇧🇾',
  'bn':    'Bengali 🇧🇩',
  'bho':   'Bhojpuri 🇮🇳',
  'bs':    'Bosnian 🇧🇦',
  'bg':    'Bulgarian 🇧🇬',
  'my':    'Burmese 🇲🇲',
  'yue':   'Cantonese 🇭🇰',
  'ca':    'Catalan 🇪🇸',
  'ceb':   'Cebuano 🇵🇭',
  'ny':    'Chichewa / Chewa 🇲🇼',
  'zh-CN': 'Chinese (Simplified) 🇨🇳',
  'zh-TW': 'Chinese (Traditional) 🇹🇼',
  'hr':    'Croatian 🇭🇷',
  'cs':    'Czech 🇨🇿',
  'da':    'Danish 🇩🇰',
  'nl':    'Dutch 🇳🇱',
  'en-GB': 'English (UK) 🇬🇧',
  'en-US': 'English (US) 🇺🇸',
  'en':    'English 🇺🇸',
  'et':    'Estonian 🇪🇪',
  'fil':   'Filipino / Tagalog 🇵🇭',
  'fi':    'Finnish 🇫🇮',
  'fr':    'French 🇫🇷',
  'fr-CA': 'French (Canada) 🇨🇦',
  'ff':    'Fulani / Fula 🇸🇳',
  'gl':    'Galician 🇪🇸',
  'ka':    'Georgian 🇬🇪',
  'de':    'German 🇩🇪',
  'el':    'Greek 🇬🇷',
  'gn':    'Guarani 🇵🇾',
  'gu':    'Gujarati 🇮🇳',
  'ht':    'Haitian Creole 🇭🇹',
  'ha':    'Hausa 🇳🇬',
  'he':    'Hebrew 🇮🇱',
  'hi':    'Hindi 🇮🇳',
  'hmn':   'Hmong 🇱🇦',
  'hu':    'Hungarian 🇭🇺',
  'is':    'Icelandic 🇮🇸',
  'ig':    'Igbo 🇳🇬',
  'id':    'Indonesian 🇮🇩',
  'ga':    'Irish 🇮🇪',
  'xh':    'isiXhosa 🇿🇦',
  'it':    'Italian 🇮🇹',
  'ja':    'Japanese 🇯🇵',
  'jv':    'Javanese 🇮🇩',
  'kn':    'Kannada 🇮🇳',
  'ks':    'Kashmiri 🇮🇳',
  'kk':    'Kazakh 🇰🇿',
  'km':    'Khmer 🇰🇭',
  'rw':    'Kinyarwanda 🇷🇼',
  'ko':    'Korean 🇰🇷',
  'ku':    'Kurdish 🌍',
  'ky':    'Kyrgyz 🇰🇬',
  'lo':    'Lao 🇱🇦',
  'lv':    'Latvian 🇱🇻',
  'ln':    'Lingala 🇨🇩',
  'lt':    'Lithuanian 🇱🇹',
  'lg':    'Luganda 🇺🇬',
  'lb':    'Luxembourgish 🇱🇺',
  'mk':    'Macedonian 🇲🇰',
  'mad':   'Madurese 🇮🇩',
  'mg':    'Malagasy 🇲🇬',
  'ms':    'Malay 🇲🇾',
  'ml':    'Malayalam 🇮🇳',
  'mt':    'Maltese 🇲🇹',
  'mr':    'Marathi 🇮🇳',
  'mi':    'Māori 🇳🇿',
  'mn':    'Mongolian 🇲🇳',
  'ne':    'Nepali 🇳🇵',
  'pcm':   'Nigerian Pidgin 🇳🇬',
  'nb-NO': 'Norwegian Bokmål 🇳🇴',
  'or':    'Odia (Oriya) 🇮🇳',
  'ps':    'Pashto 🇦🇫',
  'fa':    'Persian / Farsi 🇮🇷',
  'pl':    'Polish 🇵🇱',
  'pt-BR': 'Portuguese (Brazil) 🇧🇷',
  'pt-PT': 'Portuguese (Portugal) 🇵🇹',
  'pt':    'Portuguese 🇵🇹',
  'pa':    'Punjabi 🇮🇳',
  'qu':    'Quechua 🇵🇪',
  'ro':    'Romanian 🇷🇴',
  'ru':    'Russian 🇷🇺',
  'skr':   'Saraiki 🇵🇰',
  'sr':    'Serbian 🇷🇸',
  'st':    'Sesotho 🇱🇸',
  'sn':    'Shona 🇿🇼',
  'sd':    'Sindhi 🇵🇰',
  'si':    'Sinhala 🇱🇰',
  'sk':    'Slovak 🇸🇰',
  'sl':    'Slovenian 🇸🇮',
  'so':    'Somali 🇸🇴',
  'es-MX': 'Spanish (LatAm) 🇲🇽',
  'es-ES': 'Spanish (Spain) 🇪🇸',
  'es':    'Spanish 🇪🇸',
  'su':    'Sundanese 🇮🇩',
  'sw':    'Swahili 🇹🇿',
  'sv':    'Swedish 🇸🇪',
  'tg':    'Tajik 🇹🇯',
  'ta':    'Tamil 🇮🇳',
  'tt':    'Tatar 🇷🇺',
  'te':    'Telugu 🇮🇳',
  'th':    'Thai 🇹🇭',
  'ti':    'Tigrinya 🇪🇷',
  'tr':    'Turkish 🇹🇷',
  'tk':    'Turkmen 🇹🇲',
  'uk':    'Ukrainian 🇺🇦',
  'ur':    'Urdu 🇵🇰',
  'ug':    'Uyghur 🇨🇳',
  'uz':    'Uzbek 🇺🇿',
  'vi':    'Vietnamese 🇻🇳',
  'cy':    'Welsh 🏴',
  'wo':    'Wolof 🇸🇳',
  'yo':    'Yoruba 🇳🇬',
  'zu':    'Zulu 🇿🇦',
};
function formatLang(code) {
  return LANG_LABELS[code] || code.toUpperCase();
}

// ─── SHUFFLE UTILITY ──────────────────────────────────────
function shuffleArr(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// ─── FETCH REAL DATA FROM SUPABASE ───────────────────────
async function refreshDemoWithRealData() {
  // Always draw the garden immediately so canvas is visible
  drawDemoGarden('idle');

  if (!window.supabaseClient) {
    console.log('[Demo] No Supabase client — using fallback data.');
    demoShuffled = shuffleArr([...DEMO_WORDS_FALLBACK]);
    renderDemoWord();
    return;
  }

  try {
    // 1. Try the dedicated RPC first
    const { data: pairs, error: rpcErr } = await window.supabaseClient
      .rpc('get_random_quiz_pairs', { limit_count: 10 });

    if (pairs && !rpcErr && pairs.length > 0) {
      // RPC returns objects with word, lang_code, correct_answer, options
      demoShuffled = shuffleArr(pairs.map(p => ({
        word: p.word,
        lang: formatLang(p.lang_code),
        correct: p.correct_answer,
        options: p.options,
      })));
      demoIdx = 0;
      renderDemoWord();
      console.log('[Demo] Loaded', pairs.length, 'real quiz pairs from RPC.');
      return;
    }

    if (rpcErr) console.warn('[Demo] RPC error:', rpcErr.message, '— falling back to manual query.');

    // 2. Manual fallback: fetch non-English vocab + English translations
    const { data: rawPairs, error: rawErr } = await window.supabaseClient
      .from('vocabulary')
      .select('word, lang_code, concept_id')
      .neq('lang_code', 'en-US')
      .neq('lang_code', 'en-GB')
      .neq('lang_code', 'en')
      .limit(12);

    if (rawErr || !rawPairs || rawPairs.length === 0) throw new Error('No vocabulary data found.');

    const conceptIds = rawPairs.map(p => p.concept_id);

    const [{ data: englishWords }, { data: distractors }] = await Promise.all([
      window.supabaseClient
        .from('vocabulary')
        .select('word, concept_id')
        .in('lang_code', ['en-US', 'en-GB', 'en'])
        .in('concept_id', conceptIds),
      window.supabaseClient
        .from('vocabulary')
        .select('word')
        .in('lang_code', ['en-US', 'en-GB', 'en'])
        .limit(40),
    ]);

    const finalWords = rawPairs.map(p => {
      const correct = (englishWords || []).find(e => e.concept_id === p.concept_id)?.word;
      if (!correct) return null;

      const options = [correct];
      const pool = (distractors || []).map(d => d.word).filter(w => w !== correct);
      const shuffledPool = shuffleArr([...pool]);
      while (options.length < 4 && shuffledPool.length > 0) {
        options.push(shuffledPool.pop());
      }
      // Pad if still not enough
      while (options.length < 4) options.push('—');

      return {
        word: p.word,
        lang: formatLang(p.lang_code),
        correct,
        options,
      };
    }).filter(Boolean);

    if (finalWords.length === 0) throw new Error('No complete quiz pairs could be built.');

    demoShuffled = shuffleArr(finalWords);
    demoIdx = 0;
    renderDemoWord();
    console.log('[Demo] Loaded', finalWords.length, 'quiz pairs via manual query.');

  } catch (err) {
    console.warn('[Demo] Falling back to static data:', err.message);
    demoShuffled = shuffleArr([...DEMO_WORDS_FALLBACK]);
    renderDemoWord();
  }
}

// ─── RENDER CURRENT QUESTION ──────────────────────────────
function renderDemoWord() {
  if (!demoShuffled.length) return;
  const item = demoShuffled[demoIdx % demoShuffled.length];
  demoAnswered = false;

  const wordEl = document.getElementById('demoWord');
  if (wordEl) {
    wordEl.textContent = item.word;
    wordEl.style.transform = 'scale(1)';
    wordEl.style.fontSize = item.word.length > 20 ? '1.3rem' : '';
    wordEl.style.lineHeight = item.word.length > 20 ? '1.4' : '';
  }

  const langEl = document.querySelector('.demo-lang');
  if (langEl) langEl.textContent = item.lang;
  const demoLangId = document.getElementById('demoLang');
  if (demoLangId) demoLangId.textContent = item.lang;

  // Render shuffled options
  const shuffledOpts = shuffleArr([...item.options]);
  const container = document.getElementById('demoOptions');
  if (container) {
    container.innerHTML = '';
    shuffledOpts.forEach(opt => {
      const btn = document.createElement('button');
      btn.className = 'demo-opt';
      btn.textContent = opt;
      btn.onclick = () => handleDemoAnswer(btn, opt, item.correct);
      container.appendChild(btn);
    });
  }

  const fb = document.getElementById('demoFeedback');
  if (fb) { fb.textContent = ''; fb.style.color = ''; }

  const nxt = document.getElementById('demoNext');
  if (nxt) nxt.style.display = 'none';

  drawDemoGarden('idle');
}

// ─── HANDLE ANSWER ────────────────────────────────────────
function handleDemoAnswer(btn, chosen, correct) {
  if (demoAnswered) return;
  demoAnswered = true;

  document.querySelectorAll('.demo-opt').forEach(b => {
    b.disabled = true;
    if (b.textContent === correct) b.classList.add('correct');
  });

  const isRight = chosen === correct;
  if (!isRight) btn.classList.add('wrong');

  const feedback = document.getElementById('demoFeedback');
  if (feedback) {
    feedback.textContent = isRight ? '🌸 Correct! Your plant blooms!' : `🥀 The answer was: ${correct}`;
    feedback.style.color = isRight ? '#66BB6A' : '#E57373';
  }

  drawDemoGarden(isRight ? 'correct' : 'wrong');

  const wordEl = document.getElementById('demoWord');
  if (wordEl) {
    wordEl.style.transition = 'transform 0.2s';
    wordEl.style.transform = 'scale(1.12)';
    setTimeout(() => wordEl.style.transform = 'scale(1)', 300);
  }

  const nxt = document.getElementById('demoNext');
  if (nxt) nxt.style.display = 'block';
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

  let stemColor = '#4BAE4F';
  if (state === 'wrong') stemColor = lerpColor('#4BAE4F', '#E57373', prog);
  if (state === 'correct') stemColor = lerpColor('#4BAE4F', '#4FC3F7', prog * 0.5);

  ctx.strokeStyle = stemColor;
  ctx.lineWidth = 6;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(cx, groundY);
  ctx.lineTo(cx, stemTop);
  ctx.stroke();

  if (prog > 0.2) {
    const leafProg = (prog - 0.2) / 0.8;
    const leafColor = state === 'wrong'
      ? lerpColor('#81C784', '#E57373', prog * 0.5)
      : '#81C784';
    drawLeaf(ctx, cx, stemTop + stemH * 0.4, -0.5, 22 * leafProg, leafColor);
    drawLeaf(ctx, cx, stemTop + stemH * 0.2, 0.5, 18 * leafProg, leafColor);
  }

  if (state === 'correct' && prog > 0.5) {
    const fp = (prog - 0.5) / 0.5;
    drawFlower(ctx, cx, stemTop, fp);
  }
  if (state === 'wrong' && prog > 0.4) {
    const dp = (prog - 0.4) / 0.6;
    drawWilt(ctx, cx, stemTop, dp);
  }

  if (state === 'correct' && prog > 0.3) {
    drawParticles(ctx, cx, stemTop, prog, '#4FC3F7');
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
  ctx.fillStyle = `rgba(129,199,132,${p * 0.9})`;  // botanical green petals, not gold
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
  grd.addColorStop(0, `rgba(75,174,79,${0.3 * p})`);
  grd.addColorStop(1, 'rgba(75,174,79,0)');
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
  return `rgb(${Math.round(ar+(br-ar)*t)},${Math.round(ag+(bg-ag)*t)},${Math.round(ab+(bb-ab)*t)})`;
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
window.addEventListener('DOMContentLoaded', () => {
  // Small delay ensures Supabase client has initialised
  setTimeout(refreshDemoWithRealData, 150);
});

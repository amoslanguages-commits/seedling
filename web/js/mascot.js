/**
 * SproutMascot — High-fidelity JavaScript Canvas implementation
 * Ported from Seedling Flutter (lib/widgets/mascot.dart)
 * 
 * Provides absolute visual parity and identical animation behavior.
 */

class SproutMascot {
    constructor(canvasId, size = 420) {
        this.canvas = document.getElementById(canvasId);
        if (!this.canvas) return;
        this.ctx = this.canvas.getContext('2d');
        this.size = size;
        this.state = 'idle'; // idle, happy, thinking, etc.
        
        // Animation states
        this.startTime = performance.now();
        this.blinkTime = 0;
        this.isBlinking = false;
        this.nextBlink = 2000;
        
        // Constants (from SeedlingColors)
        this.colors = {
            seedlingGreen: '#4BAE4F',
            deepRoot: '#07140B',
            freshSprout: '#81C784',
            morningDew: '#A5D6A7',
            leafBase: '#558B2F',
            leafTip: '#9CCC65',
            darkGreen: '#1B5E20',
            thinkingBase: '#4A148C',
            cheekPink: 'rgba(255, 138, 128, 0.4)'
        };

        this.init();
    }

    init() {
        this.resize();
        window.addEventListener('resize', () => this.resize());
        this.animate();
    }

    resize() {
        // High DPI support
        const dpr = window.devicePixelRatio || 1;
        const rect = this.canvas.parentElement.getBoundingClientRect();
        this.canvas.width = rect.width * dpr;
        this.canvas.height = (rect.width * 1.35) * dpr;
        this.ctx.scale(dpr, dpr);
        this.renderWidth = rect.width;
        this.renderHeight = rect.width * 1.35;
    }

    setState(newState) {
        this.state = newState;
    }

    animate() {
        const now = performance.now();
        const elapsed = now - this.startTime;

        this.updateBlink(now);
        this.draw(elapsed);
        requestAnimationFrame(() => this.animate());
    }

    updateBlink(now) {
        if (!this.isBlinking && now > this.blinkTime + this.nextBlink) {
            this.isBlinking = true;
            this.blinkTime = now;
        }
        if (this.isBlinking && now > this.blinkTime + 120) {
            this.isBlinking = false;
            this.nextBlink = 2000 + Math.random() * 3000;
        }
    }

    draw(t) {
        const ctx = this.ctx;
        const W = this.renderWidth;
        const H = this.renderHeight;
        ctx.clearRect(0, 0, W, H);

        if (W === 0) return;

        // Layout constants
        const cx = W / 2;
        const groundY = H * 0.78;

        // Rhythmic offsets (Sync with Flutter periods)
        const bob = Math.sin((t / 2600) * Math.PI * 2) * H * 0.022;
        const swayAngle = Math.sin((t / 3800) * Math.PI * 2) * 0.05;
        const blinkScale = this.isBlinking ? 0.1 : 1.0;

        ctx.save();
        ctx.translate(cx, groundY + bob);

        // Pivot sway at pot collar
        ctx.rotate(swayAngle);

        this._drawStem(W, H);
        this._drawLeafCanopy(W, H, t);
        this._drawFace(W, H, blinkScale, t);

        ctx.restore();
    }

    _drawStem(W, H) {
        const ctx = this.ctx;
        const stemHeight = H * 0.30;
        const stemCurve = W * 0.06;

        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(stemCurve, -stemHeight * 0.5, 0, -stemHeight);

        const grad = ctx.createLinearGradient(0, 0, 0, -stemHeight);
        grad.addColorStop(0, '#2E6B28');
        grad.addColorStop(0.5, '#4BAE4F');
        grad.addColorStop(1, '#81C784');

        ctx.strokeStyle = grad;
        ctx.lineWidth = W * 0.065;
        ctx.lineCap = 'round';
        ctx.stroke();

        // Highlight
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(stemCurve, -stemHeight * 0.5, 0, -stemHeight);
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.18)';
        ctx.lineWidth = W * 0.018;
        ctx.stroke();

        // Stem leaves
        this._drawStemLeaves(W, H, stemHeight, stemCurve);
    }

    _drawStemLeaves(W, H, stemH, curve) {
        const leafPositions = [0.38, 0.65];
        const leafSides = [-1.0, 1.0];
        const leafSizes = [W * 0.21, W * 0.18];

        for (let i = 0; i < 2; i++) {
            const t = leafPositions[i];
            const side = leafSides[i];
            const px = curve * 2 * t * (1 - t) * side * 0.3;
            const py = -stemH * t;
            const angle = side * (Math.PI * 0.35);

            this.ctx.save();
            this.ctx.translate(px, py);
            this.ctx.rotate(angle);
            this._drawRoundLeaf(side, leafSizes[i], i === 0);
            this.ctx.restore();
        }
    }

    _drawRoundLeaf(side, size, primary) {
        const ctx = this.ctx;
        const path = new Path2D();
        path.moveTo(0, 0);
        path.bezierCurveTo(-size * 0.55 * side, -size * 0.2, -size * 0.65 * side, -size * 0.75, 0, -size);
        path.bezierCurveTo(size * 0.65 * side, -size * 0.75, size * 0.55 * side, -size * 0.2, 0, 0);

        const grad = ctx.createLinearGradient(0, -size, 0, 0);
        if (primary) {
            grad.addColorStop(0, '#9CCC65');
            grad.addColorStop(1, '#558B2F');
        } else {
            grad.addColorStop(0, '#66BB6A');
            grad.addColorStop(1, '#388E3C');
        }

        ctx.fillStyle = grad;
        ctx.fill(path);

        // Vein
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(0, -size * 0.88);
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.22)';
        ctx.lineWidth = 1.2;
        ctx.stroke();
    }

    _drawLeafCanopy(W, H, t) {
        const ctx = this.ctx;
        const r = W * 0.36;
        const cy = -H * 0.30;

        const blob = this._buildCanopyBlob(cy, r);

        // Shadow
        ctx.shadowColor = 'rgba(0, 0, 0, 0.28)';
        ctx.shadowBlur = 12;
        ctx.shadowOffsetY = 6;

        const grad = ctx.createRadialGradient(0, cy - r * 0.1, 0, 0, cy - r * 0.1, r * 1.1);
        grad.addColorStop(0, '#C8E6C9');
        grad.addColorStop(0.5, '#66BB6A');
        grad.addColorStop(1, '#2E7D32');

        ctx.fillStyle = grad;
        ctx.fill(blob);
        
        // Reset shadow
        ctx.shadowBlur = 0;
        ctx.shadowOffsetY = 0;

        // Edge highlight
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = 2.5;
        ctx.stroke(blob);

        // Specular
        ctx.beginPath();
        ctx.ellipse(-r * 0.22, cy - r * 0.38, r * 0.17, r * 0.11, 0, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255, 255, 255, 0.18)';
        ctx.fill();
    }

    _buildCanopyBlob(cy, r) {
        const path = new Path2D();
        const bumps = 8;
        const bumpAmps = [0.10, 0.12, 0.09, 0.14, 0.10, 0.08, 0.12, 0.09];

        for (let i = 0; i <= bumps; i++) {
            const angle = (i / bumps) * Math.PI * 2 - Math.PI / 2;
            const prevAngle = ((i - 1) / bumps) * Math.PI * 2 - Math.PI / 2;
            const amp = 1.0 + bumpAmps[i % bumps];

            const x = Math.cos(angle) * r * amp;
            const y = cy + Math.sin(angle) * r * amp;

            if (i === 0) {
                path.moveTo(x, y);
            } else {
                const midAngle = (prevAngle + angle) / 2;
                path.quadraticCurveTo(
                    Math.cos(midAngle) * r * 0.94,
                    cy + Math.sin(midAngle) * r * 0.94,
                    x, y
                );
            }
        }
        return path;
    }

    _drawFace(W, H, blinkScale, t) {
        const ctx = this.ctx;
        const s = W * 0.36;
        const headCY = -H * 0.30;

        ctx.save();
        ctx.translate(0, headCY);

        const eyeR = s * 0.15;
        const eyeY = s * 0.04;
        const eyeX = s * 0.33;

        // Eyes
        for (const side of [-1, 1]) {
            const ex = side * eyeX;

            // White
            ctx.beginPath();
            ctx.ellipse(ex, eyeY, eyeR * 1.05, eyeR * 1.1 * blinkScale, 0, 0, Math.PI * 2);
            ctx.fillStyle = '#FFFFFF';
            ctx.fill();

            // Iris
            if (blinkScale > 0.3) {
                ctx.beginPath();
                ctx.ellipse(ex + side * 1.5, eyeY + 1.5, eyeR * 0.67, eyeR * 0.75 * blinkScale, 0, 0, Math.PI * 2);
                const irisGrad = ctx.createRadialGradient(ex + side * 1.5, eyeY, 0, ex + side * 1.5, eyeY, eyeR * 0.9);
                irisGrad.addColorStop(0, '#1B5E20');
                irisGrad.addColorStop(1, '#000000');
                ctx.fillStyle = irisGrad;
                ctx.fill();

                // Shine
                ctx.beginPath();
                ctx.arc(ex + side * 2 - 2, eyeY - 2, eyeR * 0.28, 0, Math.PI * 2);
                ctx.fillStyle = 'rgba(255, 255, 255, 0.95)';
                ctx.fill();
            }
        }

        // Cheeks
        ctx.beginPath();
        ctx.ellipse(-eyeX - s * 0.08, s * 0.26, s * 0.19, s * 0.10, 0, 0, Math.PI * 2);
        ctx.fillStyle = this.colors.cheekPink;
        ctx.fill();
        ctx.beginPath();
        ctx.ellipse(eyeX + s * 0.08, s * 0.26, s * 0.19, s * 0.10, 0, 0, Math.PI * 2);
        ctx.fillStyle = this.colors.cheekPink;
        ctx.fill();

        // Mouth
        const mouthW = s * 0.32;
        const curveH = s * 0.10;
        ctx.beginPath();
        ctx.moveTo(-mouthW / 2, s * 0.3);
        ctx.quadraticCurveTo(0, s * 0.3 + curveH, mouthW / 2, s * 0.3);
        ctx.strokeStyle = '#1B5E20';
        ctx.lineWidth = s * 0.07;
        ctx.lineCap = 'round';
        ctx.stroke();

        ctx.restore();
    }
}

// Export for main.js
window.SproutMascot = SproutMascot;

window.initPearl = function (el) {
  const THREE = window.THREE;
  if (!THREE || !el) return;

  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
  renderer.setClearColor(0x000000, 0);
  el.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 50);
  camera.position.set(0, 0, 7);

  const vertexShader = `
    uniform float uTime;
    varying vec3 vNormal;
    varying vec3 vView;
    varying float vWave;
    void main() {
      vec3 p = position;
      float t = uTime * 0.35;
      float w = sin(p.x * 1.7 + t) * sin(p.y * 1.9 + t * 1.3) * sin(p.z * 1.6 + t * 0.7);
      float w2 = sin(p.y * 3.1 - t * 0.9) * 0.35;
      float d = (w + w2 * 0.4) * 0.07;
      p += normal * d;
      p *= 1.0 + sin(uTime * 0.6) * 0.018;
      vWave = w;
      vec4 mv = modelViewMatrix * vec4(p, 1.0);
      vView = -mv.xyz;
      vNormal = normalize(normalMatrix * normalize(p));
      gl_Position = projectionMatrix * mv;
    }
  `;

  const fragmentShader = `
    uniform float uTime;
    varying vec3 vNormal;
    varying vec3 vView;
    varying float vWave;
    void main() {
      vec3 n = normalize(vNormal);
      vec3 v = normalize(vView);
      float ndv = max(dot(n, v), 0.0);
      float fres = pow(1.0 - ndv, 2.4);
      vec3 L = normalize(vec3(-0.45, 0.65, 0.7));
      float diff = max(dot(n, L), 0.0);
      float spec = pow(max(dot(reflect(-L, n), v), 0.0), 38.0);
      float hue = fres * 1.25 + vWave * 0.55 + uTime * 0.035 + n.y * 0.25;
      vec3 irid = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.3, 0.62) + hue));
      vec3 pastel = mix(irid, vec3(0.80, 0.94, 0.90), 0.5);
      vec3 pearl = vec3(0.965, 0.962, 0.95);
      vec3 col = mix(pearl, pastel, 0.28 + fres * 0.62);
      col *= 0.84 + diff * 0.2;
      col += spec * 0.42;
      col = mix(col, vec3(0.46, 0.74, 0.76), fres * 0.22);
      float alpha = smoothstep(0.0, 0.18, ndv) * 0.15 + 0.85;
      gl_FragColor = vec4(col, alpha);
    }
  `;

  const uniforms = { uTime: { value: 0 } };
  const material = new THREE.ShaderMaterial({ uniforms, vertexShader, fragmentShader, transparent: true });
  const geometry = new THREE.IcosahedronGeometry(1.35, 24);
  const pearl = new THREE.Mesh(geometry, material);
  const group = new THREE.Group();
  group.add(pearl);

  const satMat = new THREE.ShaderMaterial({ uniforms, vertexShader, fragmentShader, transparent: true });
  const sats = [
    { r: 0.16, d: 2.2, s: 0.22, o: 0.0, y: 0.5 },
    { r: 0.1, d: 2.6, s: -0.16, o: 2.2, y: -0.7 },
    { r: 0.07, d: 1.95, s: 0.3, o: 4.1, y: 0.15 }
  ].map((c) => {
    const m = new THREE.Mesh(new THREE.IcosahedronGeometry(c.r, 6), satMat);
    m.userData = c;
    group.add(m);
    return m;
  });
  scene.add(group);

  const size = () => {
    const w = el.clientWidth || 1;
    const h = el.clientHeight || 1;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  };
  size();
  if ("ResizeObserver" in window) new ResizeObserver(size).observe(el);
  else window.addEventListener("resize", size);

  let mx = 0, my = 0, rx = 0, ry = 0;
  window.addEventListener("mousemove", (e) => {
    mx = (e.clientX / window.innerWidth - 0.5) * 2;
    my = (e.clientY / window.innerHeight - 0.5) * 2;
  }, { passive: true });

  let visible = true;
  let running = false;
  let last = performance.now();
  let t = 0;
  const frame = (now) => {
    if (!visible || document.hidden) { running = false; return; }
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    t += dt;
    uniforms.uTime.value = t;
    rx += (my * 0.25 - rx) * 0.03;
    ry += (mx * 0.35 - ry) * 0.03;
    group.rotation.x = rx;
    group.rotation.y = ry + t * 0.05;
    pearl.rotation.y = t * 0.12;
    pearl.position.y = Math.sin(t * 0.55) * 0.08;
    sats.forEach((m) => {
      const c = m.userData;
      const a = t * c.s + c.o;
      m.position.set(Math.cos(a) * c.d, c.y + Math.sin(t * 0.5 + c.o) * 0.12, Math.sin(a) * c.d * 0.6);
    });
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  };
  const start = () => { if (running) return; running = true; last = performance.now(); requestAnimationFrame(frame); };

  if ("IntersectionObserver" in window) {
    new IntersectionObserver((en) => { visible = en[0].isIntersecting; if (visible) start(); }, { threshold: 0 }).observe(el);
  }
  document.addEventListener("visibilitychange", () => { if (!document.hidden && visible) start(); });
  start();
  requestAnimationFrame(() => el.classList.add("is-ready"));
};

import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js";

const clamp = v => Math.min(1, Math.max(0, v));
const seg = (p, a, b) => clamp((p - a) / (b - a));
const ease = t => 1 - Math.pow(1 - t, 3);

export function createHouse(host) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const bg = new THREE.Color(0x1b1d20);
  const bgWarm = new THREE.Color(0x221d19);
  scene.background = bg.clone();
  scene.fog = new THREE.Fog(0x1b1d20, 34, 70);

  const camera = new THREE.PerspectiveCamera(34, 1, 0.5, 120);
  const target = new THREE.Vector3(1, 3.1, 0.4);

  const hemi = new THREE.HemisphereLight(0xdfe8ff, 0x22211f, 0.9);
  const sun = new THREE.DirectionalLight(0xfff0dc, 2.2);
  sun.position.set(14, 20, 12);
  const warmA = new THREE.PointLight(0xffa24c, 0, 16, 1.6);
  warmA.position.set(-0.5, 1.7, 1.4);
  const warmB = new THREE.PointLight(0xffa24c, 0, 16, 1.6);
  warmB.position.set(1.5, 5, 1.6);
  scene.add(hemi, sun, warmA, warmB);

  const grid = new THREE.GridHelper(64, 32, 0x3a4250, 0x2a2f37);
  grid.material.transparent = true;
  grid.material.opacity = 0.7;
  scene.add(grid);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(64, 64), new THREE.MeshStandardMaterial({ color: 0x1e2024, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.01;
  scene.add(ground);

  const mats = {
    concrete: new THREE.MeshStandardMaterial({ color: 0x9a9c9f, roughness: 0.92 }),
    wall: new THREE.MeshStandardMaterial({ color: 0xece6dc, roughness: 0.85 }),
    glass: new THREE.MeshStandardMaterial({ color: 0x1b2530, roughness: 0.12, metalness: 0.35, emissive: 0xffa24c, emissiveIntensity: 0 }),
    wood: new THREE.MeshStandardMaterial({ color: 0x8a5a33, roughness: 0.7 })
  };

  const house = new THREE.Group();
  scene.add(house);
  const frame = [], fill = [];

  const box = (list, mat, w, h, d, x, y, z) => {
    const g = new THREE.BoxGeometry(w, h, d);
    g.translate(0, h / 2, 0);
    const m = new THREE.Mesh(g, mat);
    m.position.set(x, y, z);
    m.userData.y = y;
    house.add(m);
    list.push(m);
    return m;
  };

  box(frame, mats.concrete, 10.4, 0.45, 7.4, 0, 0, 0);
  [[-5, -3.5], [0, -3.5], [5, -3.5], [-5, 0], [5, 0], [-5, 3.5], [0, 3.5], [5, 3.5]].forEach(([x, z]) => box(frame, mats.concrete, 0.38, 2.8, 0.38, x, 0.45, z));
  box(frame, mats.concrete, 11.8, 0.28, 7.8, 0.75, 3.25, 0.25);
  [[-3.5, -3], [1.5, -3], [6.5, -3], [-3.5, 4], [1.5, 4], [6.5, 4]].forEach(([x, z]) => box(frame, mats.concrete, 0.36, 2.9, 0.36, x, 3.53, z));
  box(frame, mats.concrete, 11.4, 0.3, 8, 1.5, 6.43, 0.5);

  const T = 0.22;
  box(fill, mats.wall, 10, 2.8, T, 0, 0.45, -3.5);
  box(fill, mats.wall, T, 2.8, 7, -5, 0.45, 0);
  box(fill, mats.wall, T, 2.8, 7, 5, 0.45, 0);
  box(fill, mats.wall, 1.4, 2.8, T, -4.3, 0.45, 3.5);
  box(fill, mats.wall, 3.4, 2.8, T, 3.3, 0.45, 3.5);
  box(fill, mats.wall, 10, 2.9, T, 1.5, 3.53, -3);
  box(fill, mats.wall, T, 2.9, 7, -3.5, 3.53, 0.5);
  box(fill, mats.wall, T, 2.9, 7, 6.5, 3.53, 0.5);
  box(fill, mats.wall, 1, 2.9, T, -3, 3.53, 4);
  box(fill, mats.wall, 3, 2.9, T, 5, 3.53, 4);
  box(fill, mats.glass, 5, 2.3, 0.08, -1, 0.75, 3.62);
  box(fill, mats.glass, 1.3, 2.4, 0.08, 3.1, 0.45, 3.62);
  box(fill, mats.glass, 0.08, 1.6, 3, 5.13, 1.1, 0);
  box(fill, mats.glass, 6, 2.2, 0.08, 0.5, 3.85, 4.12);
  box(fill, mats.glass, 0.08, 1.6, 2.6, -3.62, 4.2, 0.5);
  box(fill, mats.wall, 12.2, 0.55, 0.2, 1.5, 6.73, 4.4);
  for (let i = 0; i < 9; i++) box(fill, mats.wood, 0.12, 2.75, 0.14, 3.75 + i * 0.32, 3.6, 4.3);

  const edgePos = [];
  const segs = [];
  house.updateMatrixWorld(true);
  [...frame, ...fill].forEach(m => {
    const e = new THREE.EdgesGeometry(m.geometry);
    e.applyMatrix4(m.matrixWorld);
    const a = e.attributes.position.array;
    for (let i = 0; i < a.length; i += 6) segs.push(a.slice(i, i + 6));
    e.dispose();
  });
  segs.sort((s1, s2) => Math.min(s1[1], s1[4]) - Math.min(s2[1], s2[4]));
  segs.forEach(s => edgePos.push(...s));
  const lineGeo = new THREE.BufferGeometry();
  lineGeo.setAttribute("position", new THREE.Float32BufferAttribute(edgePos, 3));
  const lineMat = new THREE.LineBasicMaterial({ color: 0x86c8ff, transparent: true, opacity: 0.95, depthWrite: false, blending: THREE.AdditiveBlending });
  const lines = new THREE.LineSegments(lineGeo, lineMat);
  lines.renderOrder = 2;
  scene.add(lines);
  const vertCount = edgePos.length / 3;

  const sortByY = list => list.map((m, i) => ({ m, k: m.userData.y + i * 0.001 })).sort((a, b) => a.k - b.k).map(o => o.m);
  const frameOrder = sortByY(frame);
  const fillOrder = sortByY(fill);
  [...frame, ...fill].forEach(m => { m.scale.y = 0.0001; m.visible = false; });

  let target_p = 0, p = 0, raf = 0, running = false, dirty = true, w = 1, h = 1;
  const warmGlass = new THREE.Color(0xffa24c);
  const dusk = new THREE.Color(0xffb27a);

  const apply = () => {
    const s1 = seg(p, 0.02, 0.24);
    const drawn = Math.floor(vertCount * ease(s1) / 2) * 2;
    lineGeo.setDrawRange(0, Math.max(2, drawn));
    lineMat.opacity = 0.95 - 0.78 * seg(p, 0.3, 0.6);

    const s2 = seg(p, 0.25, 0.5);
    frameOrder.forEach((m, i) => {
      const t = ease(seg(s2, (i / frameOrder.length) * 0.75, (i / frameOrder.length) * 0.75 + 0.25));
      m.scale.y = Math.max(0.0001, t);
      m.visible = t > 0.001;
    });

    const s3 = seg(p, 0.5, 0.75);
    fillOrder.forEach((m, i) => {
      const t = ease(seg(s3, (i / fillOrder.length) * 0.7, (i / fillOrder.length) * 0.7 + 0.3));
      m.scale.y = Math.max(0.0001, t);
      m.visible = t > 0.001;
    });

    const s4 = ease(seg(p, 0.76, 0.96));
    mats.glass.emissiveIntensity = 1.6 * s4;
    mats.glass.emissive.copy(warmGlass);
    warmA.intensity = 16 * s4;
    warmB.intensity = 14 * s4;
    hemi.intensity = 0.9 - 0.25 * s4;
    sun.intensity = 2.2 - 0.9 * s4;
    sun.color.setHex(0xfff0dc).lerp(dusk, s4 * 0.6);
    scene.background.copy(bg).lerp(bgWarm, s4);
    grid.material.opacity = 0.7 - 0.4 * seg(p, 0.4, 0.8);

    const ang = -0.95 + p * 0.85 + s4 * 0.75;
    const rad = 34 - p * 5;
    const hy = 17 - p * 7.5;
    camera.position.set(Math.sin(ang) * rad + target.x, hy, Math.cos(ang) * rad + target.z);
    camera.lookAt(target);
  };

  const resize = () => {
    w = host.clientWidth || innerWidth;
    h = host.clientHeight || innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    if (w / h > 1.25) camera.setViewOffset(w, h, -w * 0.2, 0, w, h);
    else camera.clearViewOffset();
    camera.updateProjectionMatrix();
    dirty = true;
  };
  const ro = new ResizeObserver(resize);
  ro.observe(host);
  resize();

  const tick = () => {
    raf = requestAnimationFrame(tick);
    const d = target_p - p;
    if (Math.abs(d) > 0.0002) { p += d * 0.12; dirty = true; }
    else if (p !== target_p) { p = target_p; dirty = true; }
    if (!dirty) return;
    apply();
    renderer.render(scene, camera);
    dirty = false;
  };

  return {
    setProgress(v) { target_p = clamp(v); },
    start() { if (running) return; running = true; dirty = true; tick(); },
    stop() { running = false; cancelAnimationFrame(raf); },
    dispose() {
      running = false;
      cancelAnimationFrame(raf);
      ro.disconnect();
      scene.traverse(o => { if (o.geometry) o.geometry.dispose(); });
      Object.values(mats).forEach(m => m.dispose());
      lineMat.dispose();
      grid.material.dispose();
      ground.material.dispose();
      renderer.dispose();
      renderer.forceContextLoss();
      renderer.domElement.remove();
    }
  };
}

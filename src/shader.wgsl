struct Uniforms {
  time: f32,
  angle: f32,
};

struct Resolution {
  width: f32,
  height: f32,
};

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<uniform> resolution: Resolution;

@vertex
fn vs_main(@builtin(vertex_index) VertexIndex : u32) -> @builtin(position) vec4f {
  var pos = array<vec2f, 6>(
    vec2f(-1.0, -1.0), vec2f(1.0, -1.0), vec2f(-1.0, 1.0),
    vec2f(-1.0, 1.0), vec2f(1.0, -1.0), vec2f(1.0, 1.0)
  );
  return vec4f(pos[VertexIndex], 0.0, 1.0);
}

fn mandelbulbDE(p: vec3f, time: f32) -> f32 {
  let morphFactor = clamp(time / 10.0, 0.0, 1.0);
  let sphereDE = length(p) - 1.0;

  var z = p;
  var dr = 1.0;
  var r = 0.0;
  let power = 8.0;

  for (var i = 0; i < 8; i++) {
    r = length(z);
    if (r > 4.0) { break; }

    let theta = acos(z.z / r);
    let phi = atan2(z.y, z.x);
    dr = pow(r, power - 1.0) * power * dr + 1.0;

    let zr = pow(r, power);
    let newTheta = theta * power;
    let newPhi = phi * power;

    z = zr * vec3f(
      sin(newTheta) * cos(newPhi),
      sin(newTheta) * sin(newPhi),
      cos(newTheta)
    ) + p;
  }

  let bulbDE = 0.5 * log(r) * r / dr;
  return mix(sphereDE, bulbDE, morphFactor);
}

// Approximate surface normal via central differences
fn estimateNormal(p: vec3f, time: f32) -> vec3f {
  let eps = 0.001;
  let x = vec3f(eps, 0.0, 0.0);
  let y = vec3f(0.0, eps, 0.0);
  let z = vec3f(0.0, 0.0, eps);

  return normalize(vec3f(
    mandelbulbDE(p + x, time) - mandelbulbDE(p - x, time),
    mandelbulbDE(p + y, time) - mandelbulbDE(p - y, time),
    mandelbulbDE(p + z, time) - mandelbulbDE(p - z, time)
  ));
}

@fragment
fn fs_main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
  let res = vec2f(resolution.width, resolution.height);
  let uv = (fragCoord.xy / res) * 2.0 - 1.0;

  // Camera
  let angle = uniforms.angle;
  let ro = vec3f(sin(angle) * 4.0, 0.0, cos(angle) * 4.0);
  let center = vec3f(0.0, 0.0, 0.0);
  let forward = normalize(center - ro);
  let right = normalize(cross(vec3f(0.0, 1.0, 0.0), forward));
  let up = cross(forward, right);
  let rd = normalize(uv.x * right + uv.y * up + 1.5 * forward);

  // Raymarch to surface
  var t = 0.0;
  var d = 0.0;
  var hit = false;

  for (var i = 0; i < 128; i++) {
    let p = ro + t * rd;
    d = mandelbulbDE(p, uniforms.time);
    if (d < 0.001) {
      hit = true;
      break;
    }
    if (t > 20.0) { break; }
    t += d;
  }

  if (!hit) {
    return vec4f(0.0, 0.0, 0.0, 1.0); // background
  }

  let p = ro + t * rd;
  let normal = estimateNormal(p, uniforms.time);
  let lightDir = normalize(vec3f(1.0, 1.0, 0.0));
  let diff = max(dot(normal, lightDir), 0.0);
  let col = vec3f(0.3, 0.6, 1.0) * diff + vec3f(0.1); // diffuse + ambient

  return vec4f(col, 1.0);
}

// Struct defining uniform variables passed to the shader
struct Uniforms {
  time: f32;   // Time variable for animation effects
  angle: f32;  // Camera rotation angle
};

// Struct defining resolution parameters
struct Resolution {
  width: f32;  // Screen width
  height: f32; // Screen height
};

// Binding uniform data to group 0, binding 0
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
// Binding resolution data to group 0, binding 1
@group(0) @binding(1) var<uniform> resolution: Resolution;

// Vertex shader entry point
@vertex
fn vs_main(@builtin(vertex_index) VertexIndex: u32) -> @builtin(position) vec4f {
    // Define a fullscreen triangle strip with six vertices
    var pos = array<vec2f, 6>(
        vec2f(-1.0, -1.0), vec2f(1.0, -1.0), vec2f(-1.0, 1.0),
        vec2f(-1.0, 1.0), vec2f(1.0, -1.0), vec2f(1.0, 1.0)
    );
    // Return the vertex position in clip space
    return vec4f(pos[VertexIndex], 0.0, 1.0);
}

// Function to compute the distance estimator for the Mandelbulb fractal
fn mandelbulbDE(p: vec3f, time: f32) -> f32 {
    let morphFactor = clamp(time / 10.0, 0.0, 1.0); // Morph factor based on time
    let sphereDE = length(p) - 1.0; // Distance from unit sphere

    var z = p;
    var dr = 1.0;
    var r = 0.0;
    let power = 8.0;

    for (var i = 0; i < 8; i++) {
        r = length(z);
        if r > 4.0 { break; } // Escape condition

        let theta = acos(z.z / r);
        let phi = atan2(z.y, z.x);
        dr = pow(r, power - 1.0) * power * dr + 1.0; // Update derivative

        let zr = pow(r, power);
        let newTheta = theta * power;
        let newPhi = phi * power;

        // Transform coordinates
        z = zr * vec3f(
            sin(newTheta) * cos(newPhi),
            sin(newTheta) * sin(newPhi),
            cos(newTheta)
        ) + p;
    }

    let bulbDE = 0.5 * log(r) * r / dr; // Mandelbulb distance estimation
    return mix(sphereDE, bulbDE, morphFactor); // Blend sphere and Mandelbulb
}

// Function to estimate surface normal using central differences
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

// Fragment shader entry point
@fragment
fn fs_main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let res = vec2f(resolution.width, resolution.height);
    let uv = (fragCoord.xy / res) * 2.0 - 1.0; // Normalize coordinates to [-1,1]

    // Camera setup
    let angle = uniforms.angle;
    let ro = vec3f(sin(angle) * 4.0, 0.0, cos(angle) * 4.0); // Camera position
    let center = vec3f(0.0, 0.0, 0.0); // Look-at point
    let forward = normalize(center - ro);
    let right = normalize(cross(vec3f(0.0, 1.0, 0.0), forward));
    let up = cross(forward, right);
    let rd = normalize(uv.x * right + uv.y * up + 1.5 * forward); // Ray direction

    // Ray marching loop
    var t = 0.0;
    var d = 0.0;
    var hit = false;

    for (var i = 0; i < 128; i++) {
        let p = ro + t * rd;
        d = mandelbulbDE(p, uniforms.time);
        if d < 0.001 { // Hit threshold
            hit = true;
            break;
        }
        if t > 20.0 { break; } // Max distance limit
        t += d; // Move along ray
    }

    if !hit {
        return vec4f(0.0, 0.0, 0.0, 1.0); // Return black if no hit (background)
    }

    // Compute shading
    let p = ro + t * rd;
    let normal = estimateNormal(p, uniforms.time);
    let lightDir = normalize(vec3f(1.0, 1.0, 0.0)); // Light direction
    let diff = max(dot(normal, lightDir), 0.0); // Diffuse lighting
    let col = vec3f(0.3, 0.6, 1.0) * diff + vec3f(0.1); // Color with ambient light

    return vec4f(col, 1.0); // Final color output
}

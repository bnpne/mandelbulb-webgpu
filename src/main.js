import { initWebGPU, createPipeline } from "./webgpu.js";
import shaderCode from "./shader.wgsl?raw";

(async () => {
  const canvas = document.getElementById("webgpu-canvas");

  if (!navigator.gpu) {
    console.error("❌ WebGPU not supported in this browser.");
    return;
  }

  let device, context, format, pipeline;

  try {
    const result = await initWebGPU(canvas);
    device = result.device;
    context = result.context;
    format = result.format;
    pipeline = createPipeline(device, format, shaderCode);
  } catch (err) {
    console.error("❌ WebGPU init failed:", err);
    return;
  }

  // Resize canvas for high DPI displays
  function resizeCanvasToDisplaySize() {
    const dpr = window.devicePixelRatio || 1;
    const width = Math.floor(canvas.clientWidth * dpr);
    const height = Math.floor(canvas.clientHeight * dpr);
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
  }

  // Uniform buffer for time and angle
  const uniformBuffer = device.createBuffer({
    size: 2 * 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  // Uniform buffer for resolution
  const resolutionBuffer = device.createBuffer({
    size: 2 * 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: uniformBuffer } },
      { binding: 1, resource: { buffer: resolutionBuffer } },
    ],
  });

  function frame(timeMs) {
    resizeCanvasToDisplaySize();

    context.configure({
      device,
      format,
      alphaMode: "opaque",
    });

    const time = timeMs / 1000;
    const angle = time * 0.3;

    device.queue.writeBuffer(uniformBuffer, 0, new Float32Array([time, angle]));
    device.queue.writeBuffer(
      resolutionBuffer,
      0,
      new Float32Array([canvas.width, canvas.height]),
    );

    const commandEncoder = device.createCommandEncoder();
    const textureView = context.getCurrentTexture().createView();

    const pass = commandEncoder.beginRenderPass({
      colorAttachments: [
        {
          view: textureView,
          loadOp: "clear",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
          storeOp: "store",
        },
      ],
    });

    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(6, 1, 0, 0);
    pass.end();

    device.queue.submit([commandEncoder.finish()]);
    requestAnimationFrame(frame);
  }

  requestAnimationFrame(frame);
})();

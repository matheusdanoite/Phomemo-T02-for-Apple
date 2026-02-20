export const processImage = (file, options = { algorithm: 'floyd-steinberg', threshold: 128 }) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        // T02 width is 384px (48mm * 8 dots/mm)
        const targetWidth = 384;
        let targetHeight;
        let scale;

        // Check orientation
        const isLandscape = img.width > img.height;

        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');

        if (isLandscape) {
          // Rotate 90 degrees
          scale = targetWidth / img.height;
          targetHeight = Math.floor(img.width * scale);

          canvas.width = targetWidth;
          canvas.height = targetHeight;

          // Fill white background
          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(0, 0, targetWidth, targetHeight);

          // Rotate context
          ctx.translate(targetWidth, 0);
          ctx.rotate(90 * Math.PI / 180);

          ctx.drawImage(img, 0, 0, targetHeight, targetWidth);
        } else {
          // Portrait or Square
          scale = targetWidth / img.width;
          targetHeight = Math.floor(img.height * scale);

          canvas.width = targetWidth;
          canvas.height = targetHeight;

          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(0, 0, targetWidth, targetHeight);

          ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
        }

        // Get image data
        const imageData = ctx.getImageData(0, 0, targetWidth, targetHeight);
        const data = imageData.data;

        const w = targetWidth;
        const h = targetHeight;
        const threshold = options.threshold || 128;

        if (options.algorithm === 'threshold') {
          for (let i = 0; i < data.length; i += 4) {
            const avg = (data[i] * 0.299) + (data[i + 1] * 0.587) + (data[i + 2] * 0.114);
            const val = avg < threshold ? 0 : 255;
            data[i] = val;
            data[i + 1] = val;
            data[i + 2] = val;
          }
        } else {
          // Dithering algorithms
          for (let y = 0; y < h; y++) {
            for (let x = 0; x < w; x++) {
              const i = (y * w + x) * 4;

              // Grayscale
              const oldPixel = (data[i] * 0.299) + (data[i + 1] * 0.587) + (data[i + 2] * 0.114);
              if (options.algorithm === 'halftone') {
                // Halftone (Ordered Dithering - Bayer Matrix 4x4)
                const bayerMatrix = [
                  [1, 9, 3, 11],
                  [13, 5, 15, 7],
                  [4, 12, 2, 10],
                  [16, 8, 14, 6]
                ];

                // Normalize matrix value (0-16) to 0-255 range relative to threshold
                // Standard Bayer: pixel > matrix_threshold ? 255 : 0

                const matrixValue = bayerMatrix[x % 4][y % 4];
                // Map 1-17 to roughly -128 to +128 range to adjust threshold?
                // Simpler: Effective Threshold = Threshold + (MatrixValue / 17 - 0.5) * 255

                const thresholdMod = (matrixValue / 17 - 0.5) * 255;
                const effectiveThreshold = threshold + thresholdMod;

                // Use original grayscale value for comparison, not error diffused one
                // But wait, the loop modifies 'data' in place with error diffusion results if we aren't careful.
                // For Ordered Dithering, we don't diffuse error. We just compare.
                // However, we calculated 'oldPixel' from 'data', which might have been modified by previous error diffusion?
                // No, ordered dithering is point-process. It shouldn't use error diffusion.
                // But the loop structure is shared.
                // Let's just set the pixel and NOT distribute error.

                const val = oldPixel < effectiveThreshold ? 0 : 255;
                data[i] = val;
                data[i + 1] = val;
                data[i + 2] = val;

                // NO error distribution for Halftone

              } else {
                // Floyd-Steinberg (Default)
                // This uses error diffusion
                const newPixel = oldPixel < threshold ? 0 : 255;
                const error = oldPixel - newPixel;

                data[i] = newPixel;
                data[i + 1] = newPixel;
                data[i + 2] = newPixel;

                distributeError(data, w, h, x + 1, y, error, 7 / 16);
                distributeError(data, w, h, x - 1, y + 1, error, 3 / 16);
                distributeError(data, w, h, x, y + 1, error, 5 / 16);
                distributeError(data, w, h, x + 1, y + 1, error, 1 / 16);
              }
            }
          }
        }

        ctx.putImageData(imageData, 0, 0);
        resolve({
          dataUrl: canvas.toDataURL('image/png'),
          isRotated: isLandscape
        });
      };
      img.onerror = reject;
      img.src = e.target.result;
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
};

function distributeError(data, w, h, x, y, error, factor) {
  if (x < 0 || x >= w || y < 0 || y >= h) return;
  const index = (y * w + x) * 4;
  const val = data[index] + (error * factor);
  data[index] = val;
  data[index + 1] = val;
  data[index + 2] = val;
}

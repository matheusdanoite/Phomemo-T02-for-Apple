import { useState, useEffect } from 'react'
import './App.css'
import { processImage } from './utils/imageProcessing'
import { db } from './firebaseConfig'
import { collection, addDoc, serverTimestamp } from 'firebase/firestore'

function App({ onBack, initialFile }) {
  const [image, setImage] = useState(null) // Base64 validation/preview
  const [isRotated, setIsRotated] = useState(false)
  const [status, setStatus] = useState('idle') // idle, processing, uploading, success, error
  const [file, setFile] = useState(initialFile || null)

  // Initialize with passed file if available
  useEffect(() => {
    if (initialFile) {
      setFile(initialFile);
    }
  }, [initialFile]);

  // Image Processing Options
  const [algorithm, setAlgorithm] = useState('floyd-steinberg')
  const [threshold, setThreshold] = useState(128)

  // Re-process when options change
  useEffect(() => {
    if (file) {
      processSelectedFile(file);
    }
  }, [algorithm, threshold, file])

  const processSelectedFile = async (currentFile) => {
    setStatus('processing');
    try {
      const result = await processImage(currentFile, { algorithm, threshold });
      setImage(result.dataUrl);
      setIsRotated(result.isRotated);
      setStatus('idle');
    } catch (err) {
      console.error(err);
      setStatus('error');
      alert("Error processing image");
    }
  }

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0]);
    }
  }

  const handlePrint = async () => {
    if (!image) return;
    setStatus('uploading');

    // Check for native iOS bridge
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.printHandler) {
      try {
        const base64Data = image.split(',')[1];
        window.webkit.messageHandlers.printHandler.postMessage({
          base64: base64Data,
          type: 'image_render'
        });
        setStatus('success');
        setTimeout(() => setStatus('idle'), 2000);
      } catch (err) {
        console.error(err);
        setStatus('error');
        alert("Error sending to iOS: " + err.message);
      }
      return;
    }

    try {
      // Remove data:image/png;base64, prefix if needed (though sending full string is often safer for generic handling, 
      // but usually we want just the data. Let's send full string and let iOS parse or strip.)
      // Actually standard is usually stripping.
      const base64Data = image.split(',')[1];

      await addDoc(collection(db, "print_jobs"), {
        data: base64Data,
        timestamp: serverTimestamp(),
        status: "pending" // Optional status field
      });
      setStatus('success');
      setTimeout(() => setStatus('idle'), 3000);
    } catch (err) {
      console.error(err);
      setStatus('error');
      alert("Error sending print job: " + err.message);
    }
  }

  return (
    <div className="container">
      <h1 style={{ fontSize: '2.6rem' }}>Imagens</h1>

      <div style={{ marginBottom: '20px' }}>
        <input
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          style={{ display: 'none' }}
          id="file-upload"
        />
        <label htmlFor="file-upload" className="print-button" style={{ display: 'inline-block', cursor: 'pointer', maxWidth: '200px', fontSize: '1rem', padding: '0.8rem' }}>
          Selecionar Imagem
        </label>
      </div>

      {file && (
        <div className="controls-section">
          <div className="control-group">
            <label>Algoritmo:</label>
            <select value={algorithm} onChange={(e) => setAlgorithm(e.target.value)}>
              <option value="floyd-steinberg">Floyd-Steinberg (Dithering)</option>
              <option value="halftone">Halftone</option>
              <option value="threshold">Preto e Branco</option>
            </select>
          </div>

          <div className="control-group">
            <label>Intensidade</label>
            <input
              type="range"
              min="0"
              max="255"
              value={threshold}
              onChange={(e) => setThreshold(parseInt(e.target.value))}
            />
          </div>
        </div>
      )}



      {image && (
        <div className="preview-section">
          <img
            src={image}
            alt="Preview"
            className="preview-image"
            style={isRotated ? {
              transform: 'rotate(-90deg)',
              maxHeight: '60vh',
              width: 'auto',
              border: '1px solid #ccc'
            } : {}}
          />

          <button
            onClick={handlePrint}
            disabled={status === 'uploading'}
            className="print-button"
          >
            {status === 'uploading' ? 'Enviando...' : 'Imprimir'}
          </button>
        </div>
      )}

      {status === 'success' && <div className="success-message">Arquivo enviado!</div>}
      {status === 'error' && <div className="error-message">Falha ao enviar arquivo.</div>}
    </div>
  )
}

export default App

import { useState, useRef, useEffect } from 'react'
import './TextApp.css'
import { db } from './firebaseConfig'
import { collection, addDoc, serverTimestamp } from 'firebase/firestore'

function TextApp({ onBack, initialTab }) {
    const [activeTab, setActiveTab] = useState(initialTab || 'text') // default to props or text
    const [text, setText] = useState('')
    const [fontSize, setFontSize] = useState(48)
    const [fontFamily, setFontFamily] = useState('sans-serif') // sans-serif, serif, monospace
    const [align, setAlign] = useState('center') // left, center, right
    const [status, setStatus] = useState('idle')

    const canvasRef = useRef(null)

    // Re-draw canvas whenever text or options change
    useEffect(() => {
        if (activeTab === 'text') {
            drawTextCanvas()
        } else {
            drawBannerCanvas()
        }
    }, [text, fontSize, fontFamily, align, activeTab])

    const handleTabChange = (tab) => {
        setActiveTab(tab)
        if (tab === 'banner') {
            if (fontSize < 150) setFontSize(150)
            if (fontSize > 300) setFontSize(300)
        } else {
            // Text tab range 20-100
            if (fontSize < 20) setFontSize(20)
            if (fontSize > 100) setFontSize(100)
        }
    }

    const drawTextCanvas = () => {
        const canvas = canvasRef.current
        if (!canvas) return
        const ctx = canvas.getContext('2d')

        // T02 width is roughly 48mm, commonly 384px width for standard density
        const width = 384
        const padding = 20
        const maxWidth = width - (padding * 2)

        ctx.font = `${fontSize}px ${fontFamily}`
        const lineHeight = fontSize * 1.2

        // Word wrapping logic
        const rawLines = text.split('\n')
        const wrappedLines = []

        // Helper to split a long word into chunks that fit
        const splitLongWord = (word) => {
            const chunks = []
            let remaining = word
            // While the remaining part doesn't fit in one line
            while (remaining.length > 0 && ctx.measureText(remaining).width > maxWidth) {
                let sub = ""
                let k = 0
                // Build a chunk that fits
                while (k < remaining.length && ctx.measureText(sub + remaining[k]).width <= maxWidth) {
                    sub += remaining[k]
                    k++
                }
                // Safety: ensure we take at least one char to avoid infinite loop if width is tiny
                if (k === 0) { sub = remaining[0]; k = 1; }

                chunks.push(sub)
                remaining = remaining.substring(k)
            }
            // Add the last piece
            if (remaining.length > 0) chunks.push(remaining)
            return chunks
        }

        rawLines.forEach(line => {
            if (line === '') {
                wrappedLines.push('')
                return
            }

            const words = line.split(' ')
            let currentLine = ""

            words.forEach(word => {
                const spacing = currentLine === "" ? "" : " "
                const testLine = currentLine + spacing + word

                if (ctx.measureText(testLine).width <= maxWidth) {
                    currentLine = testLine
                } else {
                    // Current line is full, push it
                    if (currentLine !== "") {
                        wrappedLines.push(currentLine)
                        currentLine = ""
                    }

                    // Check if this single word fits
                    if (ctx.measureText(word).width <= maxWidth) {
                        currentLine = word
                    } else {
                        // Word is massive, split it
                        const chunks = splitLongWord(word)
                        // All chunks except the last one are complete lines
                        for (let i = 0; i < chunks.length - 1; i++) {
                            wrappedLines.push(chunks[i])
                        }
                        // The last chunk starts the new line
                        currentLine = chunks[chunks.length - 1]
                    }
                }
            })
            if (currentLine !== "") wrappedLines.push(currentLine)
        })

        const totalHeight = wrappedLines.length * lineHeight + (padding * 2)

        // Resize canvas
        canvas.width = width
        canvas.height = totalHeight // exact height, no minimum

        // Clear and draw background
        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, canvas.width, canvas.height)

        // Draw text
        ctx.fillStyle = 'black'
        ctx.font = `${fontSize}px ${fontFamily}`
        ctx.textBaseline = 'top'

        wrappedLines.forEach((line, index) => {
            const y = padding + (index * lineHeight)
            let x = padding
            const lineWidth = ctx.measureText(line).width

            if (align === 'center') {
                x = (width - lineWidth) / 2
            } else if (align === 'right') {
                x = width - lineWidth - padding
            }
            // For left align, x is already padding

            ctx.fillText(line, x, y)
        })
    }

    const drawBannerCanvas = () => {
        const canvas = canvasRef.current
        if (!canvas) return
        const ctx = canvas.getContext('2d')

        const width = 384
        // Logic: Print letters rotated 90 degrees so they form a long banner
        // We will invoke the font size as the 'width' of the letter which in rotated space is height

        // Clean text (remove newlines for banner flow)
        const cleanText = text.replace(/\n/g, ' ')

        // Setup font to measure
        ctx.font = `${fontSize}px ${fontFamily}`

        // Calculate total height needed. Each character will be a block.
        // Block height (on paper) = character width + spacing
        // Block width (on paper) = fixed 384
        // But we are drawing rotated. So we are drawing 'sideways'.
        // Actually, easiest way is to draw normally on a VERY wide canvas, then rotate portions?
        // No, let's draw each character rotated.

        // Let's assume each char takes up vertical space equal to its width + padding
        let totalHeight = 0
        const charMetrics = []

        for (let char of cleanText) {
            const m = ctx.measureText(char)
            const w = m.width
            // Vertical space needed for this char
            const h = w + 10 // + spacing
            charMetrics.push({ char, h, w })
            totalHeight += h
        }

        canvas.width = width
        canvas.height = Math.max(totalHeight, 200)

        ctx.fillStyle = 'white'
        ctx.fillRect(0, 0, canvas.width, canvas.height)

        ctx.fillStyle = 'black'
        ctx.font = `${fontSize}px ${fontFamily}`
        ctx.textBaseline = 'middle'
        ctx.textAlign = 'center'

        // Draw loop
        let currentY = 0

        ctx.save()
        charMetrics.forEach(item => {
            const { char, h } = item

            // Center of the block
            const centerX = width / 2
            const centerY = currentY + (h / 2)

            ctx.save()
            ctx.translate(centerX, centerY)
            ctx.rotate(Math.PI / 2) // Rotate -90 deg
            ctx.fillText(char, 0, 0)
            ctx.restore()

            currentY += h
        })
        ctx.restore()
    }

    const handlePrint = async () => {
        setStatus('processing')
        try {
            const canvas = canvasRef.current
            // Convert to base64 (remove data:image/png;base64,)
            const dataUrl = canvas.toDataURL('image/png')
            const base64Data = dataUrl.split(',')[1]

            // Determine output method
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.printHandler) {
                window.webkit.messageHandlers.printHandler.postMessage({
                    base64: base64Data,
                    type: 'text_render'
                })
                setStatus('success')
                setTimeout(() => setStatus('idle'), 2000)
            } else {
                // Fallback to Firestore for non-native envs (dev) or if configured
                await addDoc(collection(db, "print_jobs"), {
                    data: base64Data,
                    timestamp: serverTimestamp(),
                    status: "pending",
                    type: "text_render"
                })
                setStatus('success')
                setTimeout(() => setStatus('idle'), 3000)
            }
        } catch (err) {
            console.error(err)
            setStatus('error')
            alert("Error generating print: " + err.message)
        }
    }

    return (
        <div className="text-app-container">
            <h1 style={{ fontSize: '2.6rem' }}>Faixa</h1>



            {activeTab && (
                <>
                    <div className="controls">
                        <div className="control-group">
                            <label>Tamanho da Fonte</label>
                            <input
                                type="range"
                                min={activeTab === 'banner' ? 150 : 20}
                                max={activeTab === 'banner' ? 300 : 100}
                                value={fontSize}
                                onChange={e => setFontSize(Number(e.target.value))}
                            />
                        </div>

                        <div className="control-group">
                            <label>Fonte</label>
                            <div className="button-group">
                                <button
                                    className={fontFamily === 'sans-serif' ? 'active' : ''}
                                    onClick={() => setFontFamily('sans-serif')}
                                >Sans</button>
                                <button
                                    className={fontFamily === 'serif' ? 'active' : ''}
                                    onClick={() => setFontFamily('serif')}
                                >Serif</button>
                                <button
                                    className={fontFamily === '"Comic Sans MS"' ? 'active' : ''}
                                    onClick={() => setFontFamily('"Comic Sans MS"')}
                                >Comic</button>
                            </div>
                        </div>

                        {activeTab === 'text' && (
                            <div className="control-group">
                                <label>Alinhamento</label>
                                <div className="button-group">
                                    <button
                                        className={align === 'left' ? 'active' : ''}
                                        onClick={() => setAlign('left')}
                                        title="Left Align"
                                    >
                                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                            <line x1="17" y1="10" x2="3" y2="10"></line>
                                            <line x1="21" y1="6" x2="3" y2="6"></line>
                                            <line x1="21" y1="14" x2="3" y2="14"></line>
                                            <line x1="17" y1="18" x2="3" y2="18"></line>
                                        </svg>
                                    </button>
                                    <button
                                        className={align === 'center' ? 'active' : ''}
                                        onClick={() => setAlign('center')}
                                        title="Center Align"
                                    >
                                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                            <line x1="21" y1="6" x2="3" y2="6"></line>
                                            <line x1="17" y1="10" x2="7" y2="10"></line>
                                            <line x1="19" y1="14" x2="5" y2="14"></line>
                                            <line x1="21" y1="18" x2="3" y2="18"></line>
                                        </svg>
                                    </button>
                                    <button
                                        className={align === 'right' ? 'active' : ''}
                                        onClick={() => setAlign('right')}
                                        title="Right Align"
                                    >
                                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                            <line x1="21" y1="10" x2="7" y2="10"></line>
                                            <line x1="21" y1="6" x2="3" y2="6"></line>
                                            <line x1="21" y1="14" x2="3" y2="14"></line>
                                            <line x1="21" y1="18" x2="7" y2="18"></line>
                                        </svg>
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>

                    <div className="input-area">
                        <textarea
                            value={text}
                            onChange={e => setText(e.target.value)}
                            placeholder={activeTab === 'banner' ? "Escreva aqui..." : "Escreva aqui..."}
                        />
                    </div>

                    <div className="preview-area">
                        <h3>Pré-visualização</h3>
                        <canvas
                            ref={canvasRef}
                            className="preview-canvas"
                        />
                    </div>

                    <button
                        className="print-button"
                        onClick={handlePrint}
                        disabled={status === 'processing'}
                    >
                        {status === 'processing' ? 'Processing...' : 'Imprimir'}
                    </button>

                    {status === 'success' && <div className="success-toast">Enviado!</div>}
                </>
            )}
        </div>
    )
}

export default TextApp

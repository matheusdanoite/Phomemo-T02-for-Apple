import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import TextApp from './faixa.jsx'

createRoot(document.getElementById('root')).render(
    <StrictMode>
        <TextApp initialTab="banner" />
    </StrictMode>,
)

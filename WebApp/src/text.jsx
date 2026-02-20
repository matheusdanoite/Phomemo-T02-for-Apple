import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import TextApp from './TextApp.jsx'

createRoot(document.getElementById('root')).render(
    <StrictMode>
        <TextApp />
    </StrictMode>,
)

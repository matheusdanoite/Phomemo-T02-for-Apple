import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

// Para obter esses dados, crie um projeto no Firebase Console (https://console.firebase.google.com/)
// e adicione um Web App ao seu projeto.
const firebaseConfig = {
    apiKey: "SUA_API_KEY_AQUI",
    authDomain: "SEU_AUTH_DOMAIN_AQUI",
    projectId: "SEU_PROJECT_ID_AQUI",
    storageBucket: "SEU_STORAGE_BUCKET_AQUI",
    messagingSenderId: "SEU_MESSAGING_SENDER_ID_AQUI",
    appId: "SEU_APP_ID_AQUI"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);

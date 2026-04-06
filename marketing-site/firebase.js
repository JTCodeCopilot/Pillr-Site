import { initializeApp } from "https://www.gstatic.com/firebasejs/12.11.0/firebase-app.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/12.11.0/firebase-analytics.js";

const firebaseConfig = {
  apiKey: "AIzaSyC6WQG-qcug5QrxrsRoxmxAaRljSIRtb1o",
  authDomain: "pillrapp.firebaseapp.com",
  projectId: "pillrapp",
  storageBucket: "pillrapp.firebasestorage.app",
  messagingSenderId: "1079937115053",
  appId: "1:1079937115053:web:72557dcbc1d16f0fd27724",
  measurementId: "G-KCNKZRGWNM",
};

const app = initializeApp(firebaseConfig);
getAnalytics(app);

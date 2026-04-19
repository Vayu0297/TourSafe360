# 🛡️ TourSafe360
## AI-Powered Tourism Safety Platform for Northeast India

### 📱 Apps
- **Tourist App** (`tourist-app/`) — Flutter Android app with fall detection, SOS, AI chat
- **Patrol App** (`patrol-app/`) — Flutter Android app for police officers
- **Police Dashboard** (`frontend/police-dashboard/`) — React web command center

### 🤖 Backend (`backend/`)
- FastAPI + LangGraph AI agents
- Mistral-7B safety triage
- Llama3.2 multilingual chat (20+ languages)
- 3 custom PyTorch ML models
- Socket.IO real-time alerts
- Geofencing with violation alerts

### 🚀 Features
- Real-time tourist tracking
- Gyroscope fall detection (2.5g police, 3.8g ambulance)
- Interactive geofence management
- SOS case management (active to responding to resolved)
- AI equipment recommendations
- 20+ language support
- Analytics dashboard

### Tech Stack
- Backend: FastAPI, LangGraph, PostgreSQL, Socket.IO
- AI: Mistral-7B, Llama3.2, qwen2.5-coder (all local via Ollama)
- ML: PyTorch (fall detection LSTM, zone risk transformer)
- Frontend: React, Leaflet maps
- Mobile: Flutter 3.41, Dart

### Quick Start
cd backend && uvicorn app.main:socket_app --host 0.0.0.0 --port 8000 --reload
cd frontend/police-dashboard && npm install && npm start
cd tourist-app && flutter run
cd patrol-app && flutter run

### Target Regions
Northeast India — Assam, Meghalaya, Manipur, Nagaland, Arunachal Pradesh, Mizoram, Tripura, Sikkim

### Developer
Built by SRH — Solo AI/ML Engineer and Entrepreneur, Bangalore

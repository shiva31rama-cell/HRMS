# Hostel Room Management System (HRMS)

> **One project for two subjects:** Flutter application development and Data Warehousing & Data Mining (DWDM).

HostelHub is a full-stack educational hostel management system. Students can view room information, submit maintenance requests, and read notices. Staff can manage rooms and students, review maintenance, and use machine-learning predictions with maintenance analytics.

## Table of contents

1. [Project goals](#project-goals)
2. [Features](#features)
3. [Technology stack](#technology-stack)
4. [Repository structure](#repository-structure)
5. [System architecture](#system-architecture)
6. [Run locally](#run-locally)
7. [Test and evaluate the ML module](#test-and-evaluate-the-ml-module)
8. [Deployment](#deployment)
9. [API endpoints](#api-endpoints)
10. [Testing](#testing)
11. [DWDM limitations](#dwdm-limitations)
12. [Documentation](#documentation)
13. [Security notes](#security-notes)

## Project goals

### Flutter subject
- Build a responsive Flutter application for desktop, tablet, and mobile-sized screens.
- Implement authentication, role-aware navigation, room management, maintenance requests, and notices.
- Connect Flutter to a REST API.

### DWDM subject
- Use TF-IDF and Multinomial Naive Bayes to classify maintenance text.
- Predict a suggested maintenance category and priority.
- Mine records to summarise category, priority, status, monthly request volume, and resolution time.
- Evaluate with a held-out test set, per-class precision/recall/F1, confusion matrices, and a majority-class baseline.

## Features

- Authentication with administrator, warden, and student roles.
- Room/bed capacity tracking and room allocation.
- Maintenance requests and status updates.
- Hostel announcements.
- Staff-only **ML Insights** screen.
- Maintenance category/priority prediction.
- Analytics derived from saved MongoDB records.
- Backend input validation, request throttling, and health endpoint.
- GitHub Actions checks for backend, Flutter Web, and ML service.

## Technology stack

| Layer | Technology | Responsibility |
|---|---|---|
| Frontend | Flutter, Dart | User interface |
| REST API | Node.js, Express | Authentication, permissions, business rules |
| Database | MongoDB / MongoDB Atlas | Users, rooms, maintenance, notices |
| ML API | Python, FastAPI | Predictions and analytics |
| Algorithms | scikit-learn, TF-IDF, Multinomial Naive Bayes | Text classification |
| Backend hosting | Render | Node API and Python ML service |
| Frontend hosting | GitHub Pages | Flutter Web |
| CI | GitHub Actions | Automated checks |

## Repository structure

```text
HRMS/
├── .github/workflows/
│   ├── backend-ci.yml                 # Node API tests and syntax checks
│   ├── flutter-build-ci.yml           # Compile Flutter Web
│   ├── deploy-flutter-web.yml         # Deploy Flutter Web to Pages
│   └── ml-service-ci.yml              # Python ML tests
├── app/                               # FLUTTER SUBJECT
│   ├── lib/
│   │   ├── main.dart                  # App entry point
│   │   ├── screens/
│   │   │   ├── login_screen.dart      # Sign-in / registration
│   │   │   └── home_shell.dart        # Dashboard and ML Insights
│   │   └── services/
│   │       └── api_service.dart       # Authenticated REST client
│   ├── web/                           # Flutter Web shell
│   └── pubspec.yaml                   # Flutter dependencies
├── backend/                           # NODE.JS REST API
│   ├── lib/validation.js              # Shared validation
│   ├── tests/validation.test.js       # Backend tests
│   ├── .env.example                   # Safe configuration template
│   ├── package.json                   # Node dependencies
│   └── server.js                      # Routes, auth, MongoDB, ML proxy
├── ml-service/                        # DWDM / MACHINE LEARNING
│   ├── data/maintenance_tickets.csv   # Synthetic labelled dataset
│   ├── reports/README.md              # Evaluation report instructions
│   ├── scripts/train_evaluate.py      # Held-out evaluation and metrics
│   ├── app.py                         # FastAPI and trained classifiers
│   ├── requirements.txt               # Python dependencies
│   ├── test_app.py                    # ML service tests
│   └── README.md                      # ML setup and usage
├── docs/
│   ├── PROJECT_DOCUMENTATION.md       # Project design and report
│   ├── USER_GUIDE.md                  # Application/deployment guide
│   └── DWDM_IMPLEMENTATION_GUIDE.md   # DWDM methodology and evaluation
├── .gitignore
├── README.md                          # This file
└── render.yaml                        # Node + Python hosting blueprint
```

## System architecture

```text
Flutter Web
    | HTTPS + bearer token
    v
Node.js / Express API -----------------> Python FastAPI ML service
    |                                    | TF-IDF text features
    v                                    | Multinomial Naive Bayes
MongoDB / Atlas                          | Maintenance analytics
                                         v
                                  Prediction + metrics
```

Node.js owns authentication and database access. The Python service does not connect directly to MongoDB; the authenticated Node API sends only selected maintenance fields for analytics. ML endpoints are staff-only.

## Run locally

### Prerequisites
- Flutter stable SDK
- Node.js 20 or newer
- Python 3.11 recommended
- MongoDB locally or MongoDB Atlas

### 1. Configure and start Node API

From the repository root, in PowerShell:

```powershell
Copy-Item backend/.env.example backend/.env
```

Edit `backend/.env` and set your own `MONGODB_URI`, `JWT_SECRET`, `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_PASSWORD`, and `ML_SERVICE_URL=http://localhost:8000`. Never commit `backend/.env`.

Start Terminal 1:

```powershell
cd backend
npm install
npm run dev
```

API health: `http://localhost:5000/api/health`.

### 2. Start Python ML service

Start Terminal 2 from the repository root:

```powershell
cd ml-service
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

- Health: `http://localhost:8000/health`
- Interactive docs: `http://localhost:8000/docs`

### 3. Start Flutter

Start Terminal 3 from the repository root:

```powershell
cd app
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:5000/api
```

Sign in with the administrator credentials configured in `backend/.env`. Use a staff account to see **ML Insights**.

## Test and evaluate the ML module

From PowerShell:

```powershell
cd ml-service
.venv\Scripts\Activate.ps1
python -m unittest discover -s . -p test_app.py
python scripts/train_evaluate.py
```

The evaluation script creates `ml-service/reports/evaluation_results.json` with train/test sizes, class distribution, held-out accuracy, majority-class baseline, per-class precision/recall/F1, and confusion matrices. The report is generated locally and is not committed automatically.

## Deployment

### Render: Node API and Python service
1. Create a MongoDB Atlas database and database user.
2. Create/update a Render Blueprint from `render.yaml`.
3. Provide `MONGODB_URI`, `BOOTSTRAP_ADMIN_EMAIL`, and `BOOTSTRAP_ADMIN_PASSWORD`.
4. Confirm both `hrms-api` and `hrms-ml` services are created and healthy.
5. The API uses `ML_SERVICE_URL=http://hrms-ml:10000` for Render private networking when both services share a region. Otherwise set the ML service's HTTPS URL.
6. Test `/api/health` on the API and `/health` on the ML service.

### GitHub Pages: Flutter Web

The deploy workflow stops unless the API URL is configured.

1. Open repository **Settings → Secrets and variables → Actions → Variables**.
2. Create a repository variable named `API_BASE_URL`.
3. Set its value to the deployed Node API HTTPS URL ending in `/api`, e.g. `https://your-api.onrender.com/api`.
4. Open **Actions → Deploy Flutter Web → Run workflow**, or push a change under `app/`.
5. Wait for the workflow to complete successfully.

GitHub Pages hosts only the Flutter Web frontend. It does not host the Node API, MongoDB, or Python ML service.

## API endpoints

| Endpoint | Access | Purpose |
|---|---|---|
| `GET /api/health` | Public | API and database health |
| `POST /api/auth/register` | Public | Register student |
| `POST /api/auth/login` | Public | Sign in |
| `GET /api/auth/me` | Signed-in user | Current account |
| `GET /api/rooms` | Signed-in user | List rooms |
| `GET /api/students` | Staff | List students |
| `GET /api/maintenance` | Signed-in user | Own requests or staff request list |
| `POST /api/maintenance` | Signed-in user | Create request |
| `GET /api/announcements` | Signed-in user | Read notices |
| `GET /api/dashboard` | Staff | Dashboard totals |
| `POST /api/ml/predict-maintenance` | Staff | Predict category and priority |
| `GET /api/ml/insights` | Staff | Maintenance analytics |

Routes not explicitly public require a valid bearer token. Staff-only routes verify the role on the server.

## Testing

Backend:

```powershell
cd backend
npm test
```

ML service:

```powershell
cd ml-service
python -m unittest discover -s . -p test_app.py
python scripts/train_evaluate.py
```

Flutter Web:

```powershell
cd app
flutter pub get
flutter analyze
flutter build web --release --base-href /HRMS/ --dart-define=API_BASE_URL=https://example.invalid/api
```

The example API URL is only for compilation checks. Use the real HTTPS API URL for a usable hosted build.

## DWDM limitations

The included 60-row CSV is **synthetic educational data**, not real hostel data. Metrics demonstrate a reproducible evaluation workflow; they do not prove real-world reliability.

For the final report:
1. Explain the dataset source and labelling rules.
2. Keep personal identifiers out of training data.
3. Use a held-out test set and compare against a majority-class baseline.
4. Report class-wise precision, recall, F1, and confusion matrices.
5. Explicitly discuss the small synthetic dataset limitation.
6. Replace or supplement demo data only with reviewed, de-identified, permitted records.

Do not present synthetic-data metrics as proof that the model is reliable for real safety or maintenance decisions.

## Documentation
- [Project documentation](docs/PROJECT_DOCUMENTATION.md)
- [User and deployment guide](docs/USER_GUIDE.md)
- [DWDM implementation guide](docs/DWDM_IMPLEMENTATION_GUIDE.md)
- [ML service guide](ml-service/README.md)
- [Evaluation report instructions](ml-service/reports/README.md)

## Security notes
- Never commit `.env` files, credentials, real student exports, or secrets.
- Use HTTPS for deployed frontend/API communication.
- Restrict CORS to the deployed frontend origin.
- Protect staff-only operations with server-side role checks.
- Treat ML predictions as suggestions and require staff review.

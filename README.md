# Hostel Room Management System (HRMS)

A full-stack educational project built with Flutter, Node.js, Express, and MongoDB. It is designed to support a hostel warden's daily work while giving students a simple way to view room availability, raise maintenance requests, and read notices.

## Features

- Secure login with role-based access for administrators, wardens, and students.
- Room and bed management with capacity checks and occupancy tracking.
- Student registration and room allocation by staff.
- Maintenance requests with open, in-progress, and resolved states.
- Hostel announcements.
- Dashboard totals, REST API health endpoint, validation, and basic request throttling.
- Responsive Flutter UI suitable for desktop, tablet, and mobile-sized browsers.
- Automated Flutter Web deployment to GitHub Pages and an example Render service blueprint.

## Project layout

- app/ — Flutter application and web entry point.
- backend/ — Express REST API, MongoDB models, auth middleware, and tests.
- .github/workflows/deploy-flutter-web.yml — GitHub Pages deployment workflow.
- render.yaml — Render backend blueprint.

## Run locally

Requirements: Flutter stable, Node.js 20 or newer, and a MongoDB database. A free MongoDB Atlas cluster can be used instead of installing MongoDB locally.

1. Copy backend/.env.example to backend/.env and edit the values. Use a unique JWT_SECRET and a strong BOOTSTRAP_ADMIN_PASSWORD. Never commit backend/.env.
2. Create an Atlas database and place its connection URI in MONGODB_URI. In Atlas, create a database user and allow connections from the backend host. Avoid exposing a database password in Flutter code.
3. In a terminal, run npm install inside the backend folder, then run npm run dev.
4. In a second terminal, run flutter pub get inside the app folder, then start the app with: flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:5000/api
5. Sign in with the administrator email and password configured in backend/.env. When SEED_DEMO_DATA=true, a few sample rooms and a welcome notice are created if the database is empty.

The API base URL is configured at Flutter build time. It is not a secret; the database URI and JWT signing key are secrets and must stay on the backend.

## Deploy the backend for free

1. Create a free MongoDB Atlas cluster and copy its connection string. Replace the username, password, and database name with your own values, and ensure the URI is URL-encoded where necessary.
2. Open Render and choose New Blueprint, then connect this repository and apply render.yaml. If Render asks for MONGODB_URI, BOOTSTRAP_ADMIN_EMAIL, or BOOTSTRAP_ADMIN_PASSWORD, provide your own values. Keep the administrator password private. The blueprint generates a JWT_SECRET.
3. Once deployed, open the service URL and check /api/health. The response should show status ok and database connected.
4. Copy the Render service's HTTPS URL; the Flutter API URL is that URL followed by /api.

Free Render services can sleep after inactivity, so the first API request after a quiet period may be slow. This project is suitable for a class prototype and demonstration, not a service with a production uptime guarantee.

## Deploy Flutter Web with GitHub Pages

1. In GitHub, open Settings → Pages and set the build and deployment source to GitHub Actions.
2. Open Settings → Secrets and variables → Actions → Variables. Add a repository variable named API_BASE_URL with the deployed Render API URL, including /api (for example, https://your-service.onrender.com/api).
3. Ensure the workflow file is on main, then run or re-run the Flutter Web deployment workflow from the Actions tab. New commits to app/ or the workflow file trigger it automatically.
4. After the workflow succeeds, the app will be available at https://shiva31rama-cell.github.io/HRMS/.

If the API URL is changed later, update the repository variable and run the deployment workflow again. GitHub Pages hosts the Flutter web client only; it does not host the Node server or database.

## API overview

- POST /api/auth/register — create a student account.
- POST /api/auth/login — sign in and receive a bearer token.
- GET /api/auth/me — current account.
- GET /api/rooms — list rooms; staff can also create, edit, and delete empty rooms.
- GET /api/students — staff-only student list.
- POST /api/students — staff creates a student account.
- PATCH /api/students/:id/room — staff allocates or unallocates a room.
- GET /api/maintenance — list own requests for students, or all requests for staff.
- POST /api/maintenance — create a maintenance request.
- PATCH /api/maintenance/:id — staff updates the request status.
- GET /api/announcements — read hostel notices.
- POST /api/announcements — staff publishes a notice.
- PATCH /api/announcements/:id and DELETE /api/announcements/:id — staff manages notices.
- GET /api/dashboard — staff dashboard totals.
- GET /api/health — service and database health.

All endpoints except register, login, and health require a valid bearer token. Staff-only operations check the user's role on the server, not merely in the Flutter interface.

## Tests

Run npm test inside backend/ to execute the API's input-validation unit tests.

## Important prototype notes

Before using real student information, add institution-approved privacy, retention, backup, and account-recovery procedures. Configure allowed origins for your deployed frontend rather than relying on wildcard CORS. Never upload a real .env file, student database export, or production credentials to GitHub.

## Project documentation

- [Project Documentation](docs/PROJECT_DOCUMENTATION.md) — abstract, problem statement, SDG relevance, roles, architecture, database design, API outline, security, test plan, and evaluation demo script.
- [User and Deployment Guide](docs/USER_GUIDE.md) — database setup, Render deployment, GitHub Pages configuration, local run steps, and troubleshooting.

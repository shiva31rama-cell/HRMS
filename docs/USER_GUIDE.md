# HRMS User and Deployment Guide

## A. What you need

- A GitHub account with access to this repository.
- Node.js 20 or newer for local backend development.
- Flutter stable SDK for local app development.
- A MongoDB database. Atlas offers a free cluster option subject to current limits.
- Accounts at Render and GitHub Pages/Actions for free hosting.

## B. Create the database

1. Create a MongoDB Atlas project and free database cluster.
2. Create a database user with a strong password.
3. Configure the Atlas network access list to allow the deployed backend to connect. Review Atlas security guidance before using real data.
4. Copy the driver connection string. Replace username, password, and database name; URL-encode special characters in credentials if necessary.
5. Never put this URI in Flutter source or commit it to GitHub.

## C. Deploy API to Render

1. Open Render and create a new Blueprint from shiva31rama-cell/HRMS.
2. Render reads render.yaml and prepares the hrms-api service.
3. Provide MONGODB_URI, BOOTSTRAP_ADMIN_EMAIL, and BOOTSTRAP_ADMIN_PASSWORD when prompted.
4. Choose an email you control for the admin account. Use a strong, unique password. Do not share it in project docs or screenshots.
5. The blueprint generates JWT_SECRET. Check that all environment variables are saved, then deploy.
6. Open https://YOUR-RENDER-SERVICE.onrender.com/api/health. A healthy result should include status: "ok" and database: "connected".
7. If the database is disconnected, check Atlas's connection string, database-user permissions, and network access list.

## D. Deploy Flutter Web to GitHub Pages

1. In the HRMS repository, open **Settings → Pages** and choose **GitHub Actions** as the build/deployment source.
2. Open **Settings → Secrets and variables → Actions → Variables**.
3. Create a repository variable named API_BASE_URL. Its value must be the Render HTTPS URL followed by /api, for example https://YOUR-RENDER-SERVICE.onrender.com/api.
4. Go to **Actions** and re-run **Deploy Flutter Web** (or push a change to app/).
5. Open https://shiva31rama-cell.github.io/HRMS/ after the deployment action succeeds.
6. If the workflow says API_BASE_URL is missing, add or correct the variable and re-run.

GitHub Pages hosts only the Flutter Web client. Render runs the server, and Atlas stores records. The deployment workflow cannot create your personal Render database or invent the Render service URL before you deploy the API.

## E. Run locally

From the repository root:

### Terminal 1 — backend

Windows PowerShell:

    cd backend
    Copy-Item .env.example .env
    notepad .env
    npm install
    npm run dev

Ubuntu/macOS:

    cd backend
    cp .env.example .env
    nano .env
    npm install
    npm run dev

Set MONGODB_URI, JWT_SECRET, BOOTSTRAP_ADMIN_EMAIL, and BOOTSTRAP_ADMIN_PASSWORD in backend/.env. For local testing, use a local MongoDB URI or an Atlas URI.

### Terminal 2 — Flutter Web

    cd app
    flutter pub get
    flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:5000/api

The fixed local port 3000 is included in the sample ALLOWED_ORIGINS setting. If you change that port, add the new browser origin to ALLOWED_ORIGINS and restart the backend.

## F. First sign-in and demo flow

- Sign in using the bootstrap admin email/password configured in the backend environment.
- If SEED_DEMO_DATA=true, the API creates example rooms and a welcome announcement when those collections are empty.
- Create student accounts from the Students page, then allocate rooms.
- For resident testing, create a separate student account and use it to open a maintenance request.
- Use the staff account to update request status and publish notices.
- Use sample data only during presentations.

## G. Common problems

**API says database disconnected:** the backend did not connect to MongoDB. Check MONGODB_URI, Atlas network access and database-user credentials, then review Render logs.

**Flutter displays a network or CORS error locally:** confirm the backend is running on port 5000, Flutter is on port 3000, and ALLOWED_ORIGINS contains http://localhost:3000.

**GitHub Pages workflow says API_BASE_URL is missing:** add the Actions repository variable exactly as documented in section D and use an HTTPS Render URL ending with /api.

**First request is slow:** a free Render service may have been sleeping. Wait for it to wake, then refresh.

**Admin cannot sign in:** check the configured bootstrap email/password, confirm Render deployed successfully, and inspect server logs. The bootstrap admin is created only if that email does not already exist; changing the environment password will not automatically reset an existing account password.

## H. Before using real hostel records

Do not treat this demo as a production service. Obtain institutional approval, review privacy requirements, lock down CORS, define backups and retention, use a dedicated admin account, and test restore/recovery. Never commit real student data, database exports, or secrets.

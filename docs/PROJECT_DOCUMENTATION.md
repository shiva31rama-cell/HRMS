# Hostel Room Management System (HRMS)

## 1. Abstract

The Hostel Room Management System (HRMS), presented as **HostelHub**, is a full-stack student project for managing hostel rooms, student accounts, bed allocation, maintenance requests, and notices through one application. It uses Flutter for the client, a Node.js/Express REST API for server-side rules, and MongoDB for persistent records.

This is an educational prototype. It supports the main workflows for a live demonstration, but it has not been institutionally approved for storing real resident data.

## 2. Problem statement

Many hostels maintain room availability, resident details, maintenance complaints, and notices through separate registers, spreadsheets, or informal messaging groups. These methods can make it difficult to find current occupancy, follow a complaint's status, and ensure that residents receive the right updates.

This project provides a shared interface backed by one database so hostel staff and residents can work with current information.

## 3. Objectives

- Keep a central record of rooms, blocks, floors, bed capacity, occupancy, and monthly fees.
- Provide student sign-in and student registration.
- Allow authorised staff to create rooms, create student accounts, and allocate rooms.
- Prevent allocating more students than a room's configured bed capacity.
- Let residents raise maintenance requests and follow their status.
- Let staff publish notices for everyone, students, or staff.
- Display dashboard totals such as registered students, rooms, free beds, occupancy, and unresolved requests.
- Demonstrate separation of the Flutter client, API server, and database.
- Use free hosting options for an academic prototype.

## 4. Sustainable Development Goal (SDG) relevance

The project has a practical, indirect connection to these UN Sustainable Development Goals:

- **SDG 11 — Sustainable Cities and Communities:** better organised accommodation operations can support safer, more orderly, and better managed shared living spaces.
- **SDG 9 — Industry, Innovation and Infrastructure:** the project applies a digital information system to a real administrative workflow.
- **SDG 12 — Responsible Consumption and Production:** moving room registers, issue logs, and notices online may reduce some paper use.

These are intended contributions, not measured outcomes. Do not claim reductions in paper use, complaint time, or resource usage until a pilot has collected evidence.

## 5. Intended users and permissions

| Function | Student | Warden | Admin |
|---|---:|---:|---:|
| Register own student account | Yes | No | No |
| Sign in and view own room | Yes | Yes | Yes |
| View room availability | Yes | Yes | Yes |
| Create or delete rooms | No | Yes | Yes |
| View all students | No | Yes | Yes |
| Create student account | No | Yes | Yes |
| Allocate or remove student room | No | Yes | Yes |
| Submit own maintenance request | Yes | Yes | Yes |
| View requests from all residents | No | Yes | Yes |
| Change maintenance status | No | Yes | Yes |
| Read notices for own audience | Yes | Yes | Yes |
| Publish/delete notices | No | Yes | Yes |
| View staff dashboard metrics | No | Yes | Yes |

Student registration always assigns the student role. Staff-only rules are enforced by the API, not just by hiding controls in the interface. An initial admin account is created from server environment variables during first startup.

## 6. System architecture

The request flow is:

**Student / Warden / Admin → Flutter Web client → HTTPS JSON REST API → MongoDB Atlas**

GitHub stores the source and runs Actions. GitHub Pages serves the Flutter web client, Render runs the Node API, and Atlas stores application data. The web client never contains the database connection string or JWT signing secret.

### Components

- **Flutter client (app/):** responsive dashboard and forms; calls the API and stores the session token in browser storage.
- **API (backend/server.js):** validates requests, verifies bearer tokens, enforces roles, applies business rules, and reads/writes database records.
- **MongoDB:** persists users, rooms, maintenance requests, and announcements.
- **GitHub Actions:** compiles Flutter Web and separately validates the build; backend CI checks Node syntax and validation tests.
- **Hosting:** GitHub Pages serves the web client; Render runs the API; Atlas stores data.

## 7. Main workflows

### Student registration and sign-in

1. The student enters a name, email, and password.
2. The API validates the data and hashes the password using bcrypt.
3. The API returns a signed JWT and a safe user object.
4. The app sends the token with protected API calls.

### Room allocation

1. A warden or admin opens the student list.
2. Staff selects a room for a student.
3. The API checks the selected room and reserves a bed only if capacity remains.
4. The database updates the room occupancy and the student's room reference.
5. A full room is rejected rather than exceeding capacity.

### Maintenance

1. A resident submits a title, description, category, and priority.
2. The API associates the request with the signed-in account and current room where available.
3. Staff review the request and change its status to Open, In progress, or Resolved.
4. Students see the requests they submitted and their current status.

### Notices

1. Staff publishes a title, message, and audience.
2. Students receive notices targeted to Everyone or Students.
3. Staff can delete notices that are no longer needed.

## 8. Database design

### User

| Field | Purpose |
|---|---|
| name | Display name |
| email | Unique sign-in email |
| password | bcrypt password hash; not returned by API |
| role | student, warden, or admin |
| phone | Optional contact number |
| room | Optional reference to the allocated Room |

### Room

| Field | Purpose |
|---|---|
| roomNumber, block | Room identity; unique within a block |
| floor | Floor number |
| type | Single, Double, Triple, or Dormitory |
| capacity | Configured number of beds |
| occupiedBeds | Number currently allocated |
| monthlyFee | Informational monthly hostel fee |

### MaintenanceRequest

Stores title, description, category, priority, status, creator reference, optional room reference, and timestamps. Status values are Open, In progress, and Resolved.

### Announcement

Stores title, message body, audience, creator reference, and timestamps. The audience can be Everyone, Students, or Staff.

## 9. API outline

All routes use the /api prefix. Except for registration, login, and health, requests require an Authorization: Bearer token header.

| Method | Route | Purpose |
|---|---|---|
| GET | /health | Service/database health |
| POST | /auth/register | Student self-registration |
| POST | /auth/login | Sign-in |
| GET | /auth/me | Current account |
| GET, POST | /rooms | List/create rooms |
| PATCH, DELETE | /rooms/:id | Edit/delete rooms |
| GET, POST | /students | Staff list/create students |
| PATCH | /students/:id/room | Allocate/remove room |
| GET, POST | /maintenance | List permitted requests/create request |
| PATCH | /maintenance/:id | Staff updates status |
| GET, POST | /announcements | Read/publish notices |
| PATCH, DELETE | /announcements/:id | Staff edits/deletes notices |
| GET | /dashboard | Staff summary metrics |

## 10. Security and privacy

Implemented in the prototype:
- Password hashing with bcrypt.
- Signed JWT authentication and server-side role checks.
- Unique user emails and room identity per block.
- Input size/range validation and Mongoose schema validation.
- Basic sign-in rate limiting and Helmet security headers.
- Database credentials and JWT signing key supplied through environment variables.
- Student endpoints return only the current student's maintenance requests.

Before using real resident records, the institution should review account recovery, privacy notices, retention rules, backups and restore, audit logs, administrative role management, session revocation, rate limiting, CORS origins, and incident response. Browser local storage is convenient for a demo but is not the strongest token-storage design for production.

## 11. Test plan

| Test | Action | Expected result |
|---|---|---|
| Valid student sign-up | Submit name, unique email, and password of at least 8 characters | Account created as student |
| Invalid sign-up | Use malformed email or short password | Request rejected with validation message |
| Login | Use correct credentials | Token and user returned |
| Incorrect login | Use wrong password | Generic unauthorised message |
| Staff-only route | Call student-list route as a student | API returns 403 |
| Add room | Enter valid capacity/type/fee | Room stored and shown in list |
| Allocation | Assign a student to a room with capacity | Student and occupancy updated |
| Full room | Attempt allocation after capacity is reached | API rejects allocation; capacity is not exceeded |
| Maintenance | Student submits an issue | Request saved with Open status |
| Status update | Staff marks request Resolved | Updated status visible after refresh |
| Notice | Staff publishes a Students notice | Student audience can read it |
| Persistence | Restart API and sign in again | Database records remain |
| Health | Open /api/health | Response shows service and database state |

Automated API tests run using npm test inside backend/. GitHub Actions also runs node --check server.js. A separate workflow compiles the Flutter Web application.

## 12. Evaluation demonstration script

1. Sign in with the bootstrap administrator and show the dashboard.
2. Open Rooms, add a sample room, and show the available/occupied beds.
3. Open Students, create a demo student account, and allocate a room.
4. Sign out, then sign in as that student.
5. Show the allocated room and submit a maintenance request.
6. Sign back in as staff, change the request to In progress and then Resolved.
7. Publish a hostel notice and show how it appears to the student.
8. Explain that changes are stored through the REST API in MongoDB rather than only in temporary frontend state.

Use fictitious names and email addresses during the demonstration.

## 13. Current limitations and future work

Current prototype limitations:
- Free hosted services can sleep, have quotas, and can change their free-tier rules.
- Account recovery, resident photo upload, payment collection, attendance, visitor logs, and automated messaging are not implemented.
- Admin setup is environment-based; there is no UI to promote a user to warden or admin.
- This repository currently targets Flutter Web; an Android APK build pipeline and native Android project scaffold are not included.
- Room updates and allocations need further stress testing before multi-warden operational use.

Possible next steps include CSV imports/exports, audit history, room edit UI, password reset, notification integration, automated backups, better session management, end-to-end tests, and an Android build.

## 14. Conclusion

HRMS demonstrates a practical full-stack solution for core hostel administration. It connects a Flutter interface to a protected backend and persistent database, supports room capacity rules, and creates a traceable maintenance workflow. Pilot and test with synthetic data before an institution relies on it for live operations.

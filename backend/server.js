require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const {
  normaliseEmail,
  isValidEmail,
  isStrongEnoughPassword,
  isNonEmptyText,
  isIntegerInRange
} = require('./lib/validation');

if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be configured in production.');
}
const JWT_SECRET = process.env.JWT_SECRET || 'local-development-only-secret-change-me';
const TOKEN_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());

const allowedOrigins = String(process.env.ALLOWED_ORIGINS || '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin is not allowed by CORS.'));
  }
}));
const standardJsonParser = express.json({ limit: '1mb' });
app.use((req, res, next) => {
  if (req.method === 'POST' && req.path === '/api/maintenance') return next();
  return standardJsonParser(req, res, next);
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many sign-in attempts. Please try again later.' }
});

const roomSchema = new mongoose.Schema({
  roomNumber: { type: String, required: true, trim: true, maxlength: 30 },
  block: { type: String, required: true, trim: true, maxlength: 60 },
  floor: { type: Number, required: true, min: 0, max: 100 },
  capacity: { type: Number, required: true, min: 1, max: 20 },
  occupiedBeds: { type: Number, default: 0, min: 0 },
  type: { type: String, enum: ['Single', 'Double', 'Triple', 'Dormitory'], default: 'Double' },
  monthlyFee: { type: Number, default: 0, min: 0, max: 1000000 }
}, { timestamps: true });
roomSchema.index({ block: 1, roomNumber: 1 }, { unique: true });

const Room = mongoose.model('Room', roomSchema);

const userSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 100 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true, maxlength: 254 },
  password: { type: String, required: true, minlength: 8, select: false },
  role: { type: String, enum: ['admin', 'warden', 'student'], default: 'student' },
  phone: { type: String, default: '', trim: true, maxlength: 30 },
  room: { type: mongoose.Schema.Types.ObjectId, ref: 'Room', default: null }
}, { timestamps: true });

userSchema.pre('save', async function hashPassword() {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, 12);
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

userSchema.set('toJSON', {
  transform: (doc, result) => {
    delete result.password;
    delete result.__v;
    return result;
  }
});

const User = mongoose.model('User', userSchema);

const maintenanceSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 120 },
  description: { type: String, required: true, trim: true, maxlength: 2000 },
  category: { type: String, enum: ['Plumbing', 'Electrical', 'Cleanliness', 'Furniture', 'Other'], default: 'Other' },
  priority: { type: String, enum: ['low', 'normal', 'high', 'urgent'], default: 'normal' },
  status: { type: String, enum: ['open', 'in_progress', 'resolved'], default: 'open' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  room: { type: mongoose.Schema.Types.ObjectId, ref: 'Room', default: null },
  resolvedAt: { type: Date, default: null },
  imageFileId: { type: mongoose.Schema.Types.ObjectId, default: null },
  imageMimeType: { type: String, enum: ['image/jpeg', 'image/png', 'image/webp', null], default: null },
  imageName: { type: String, trim: true, maxlength: 120, default: null }
}, { timestamps: true });

const MaintenanceRequest = mongoose.model('MaintenanceRequest', maintenanceSchema);

const announcementSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 140 },
  body: { type: String, required: true, trim: true, maxlength: 5000 },
  audience: { type: String, enum: ['all', 'students', 'staff'], default: 'all' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null }
}, { timestamps: true });

const Announcement = mongoose.model('Announcement', announcementSchema);

const asyncHandler = (handler) => (req, res, next) => {
  Promise.resolve(handler(req, res, next)).catch(next);
};

function issueToken(user) {
  return jwt.sign({ id: String(user._id), role: user.role }, JWT_SECRET, { expiresIn: TOKEN_EXPIRES_IN });
}

function authPayload(user) {
  return { token: issueToken(user), user: user.toJSON() };
}

const requireAuth = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const parts = header.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ message: 'Sign in to continue.' });
  }

  let decoded;
  try {
    decoded = jwt.verify(parts[1], JWT_SECRET);
  } catch (error) {
    return res.status(401).json({ message: 'Your session has expired. Please sign in again.' });
  }

  const user = await User.findById(decoded.id).select('-password').populate('room');
  if (!user) return res.status(401).json({ message: 'Account not found.' });
  req.user = user;
  next();
});

function staffOnly(req, res, next) {
  if (!req.user || !['admin', 'warden'].includes(req.user.role)) {
    return res.status(403).json({ message: 'This action is available to hostel staff only.' });
  }
  next();
}

function validId(id) {
  return mongoose.isValidObjectId(id);
}

const MAX_MAINTENANCE_IMAGE_BYTES = 8 * 1024 * 1024;

function maintenanceImageBucket() {
  if (!mongoose.connection.db) throw new Error('Database is not available for maintenance photo storage.');
  return new mongoose.mongo.GridFSBucket(mongoose.connection.db, { bucketName: 'maintenanceImages' });
}

function detectMaintenanceImageMime(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (bytes.length >= 12 && bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  return null;
}

function toSafeMessage(error) {
  if (error && error.code === 11000) return 'A record with those details already exists.';
  if (error && error.name === 'ValidationError') {
    return Object.values(error.errors).map((item) => item.message).join(' ');
  }
  return error && error.message ? error.message : 'Unexpected server error.';
}

const frontendUrl = String(process.env.FRONTEND_URL || 'https://shiva31rama-cell.github.io/HRMS/').trim();

app.get('/', (req, res) => {
  res.redirect(302, frontendUrl);
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'HRMS API',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

app.post('/api/auth/register', authLimiter, asyncHandler(async (req, res) => {
  const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  const email = normaliseEmail(req.body.email);
  const password = req.body.password;
  const phone = typeof req.body.phone === 'string' ? req.body.phone.trim() : '';

  if (!isNonEmptyText(name, 100) || !isValidEmail(email) || !isStrongEnoughPassword(password)) {
    return res.status(400).json({ message: 'Enter a name, valid email, and password with at least 8 characters.' });
  }
  if (phone.length > 30) return res.status(400).json({ message: 'Phone number is too long.' });

  const user = await User.create({ name, email, password, phone, role: 'student' });
  res.status(201).json(authPayload(user));
}));

app.post('/api/auth/login', authLimiter, asyncHandler(async (req, res) => {
  const email = normaliseEmail(req.body.email);
  const password = req.body.password;
  if (!isValidEmail(email) || typeof password !== 'string') {
    return res.status(400).json({ message: 'Enter a valid email and password.' });
  }

  const user = await User.findOne({ email }).select('+password');
  if (!user || !(await user.comparePassword(password))) {
    return res.status(401).json({ message: 'Incorrect email or password.' });
  }

  res.json(authPayload(user));
}));

app.get('/api/auth/me', requireAuth, (req, res) => {
  res.json({ user: req.user.toJSON() });
});

app.get('/api/rooms', requireAuth, asyncHandler(async (req, res) => {
  const rooms = await Room.find().sort({ block: 1, floor: 1, roomNumber: 1 }).lean();
  res.json({ rooms });
}));

app.post('/api/rooms', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const roomNumber = typeof req.body.roomNumber === 'string' ? req.body.roomNumber.trim() : '';
  const block = typeof req.body.block === 'string' ? req.body.block.trim() : '';
  const floor = Number(req.body.floor);
  const capacity = Number(req.body.capacity);
  const monthlyFee = Number(req.body.monthlyFee || 0);
  const type = req.body.type || 'Double';

  if (!isNonEmptyText(roomNumber, 30) || !isNonEmptyText(block, 60) ||
      !Number.isInteger(floor) || floor < 0 || floor > 100 ||
      !isIntegerInRange(capacity, 1, 20) || !Number.isFinite(monthlyFee) ||
      monthlyFee < 0 || monthlyFee > 1000000 ||
      !['Single', 'Double', 'Triple', 'Dormitory'].includes(type)) {
    return res.status(400).json({ message: 'Check the room number, block, floor, capacity, room type, and fee.' });
  }

  const room = await Room.create({ roomNumber, block, floor, capacity, monthlyFee, type });
  res.status(201).json({ room });
}));

app.patch('/api/rooms/:id', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid room ID.' });
  const room = await Room.findById(req.params.id);
  if (!room) return res.status(404).json({ message: 'Room not found.' });

  const fields = ['roomNumber', 'block', 'floor', 'capacity', 'type', 'monthlyFee'];
  for (const field of fields) {
    if (req.body[field] !== undefined) room[field] = req.body[field];
  }
  if (Number(room.capacity) < room.occupiedBeds) {
    return res.status(400).json({ message: 'Capacity cannot be lower than current occupancy.' });
  }
  await room.save();
  res.json({ room });
}));

app.delete('/api/rooms/:id', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid room ID.' });
  const room = await Room.findById(req.params.id);
  if (!room) return res.status(404).json({ message: 'Room not found.' });
  if (room.occupiedBeds > 0) return res.status(409).json({ message: 'Unallocate students before deleting this room.' });
  await room.deleteOne();
  res.json({ message: 'Room deleted.' });
}));

app.get('/api/students', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const students = await User.find({ role: 'student' }).select('-password')
    .populate('room').sort({ name: 1 }).lean();
  res.json({ students });
}));

app.post('/api/students', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  const email = normaliseEmail(req.body.email);
  const password = req.body.password;
  const phone = typeof req.body.phone === 'string' ? req.body.phone.trim() : '';
  if (!isNonEmptyText(name, 100) || !isValidEmail(email) ||
      !isStrongEnoughPassword(password) || phone.length > 30) {
    return res.status(400).json({ message: 'Enter a name, valid email, password (at least 8 characters), and a valid phone number.' });
  }
  const student = await User.create({ name, email, password, phone, role: 'student' });
  res.status(201).json({ student: student.toJSON() });
}));

app.patch('/api/students/:id/room', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid student ID.' });
  const student = await User.findOne({ _id: req.params.id, role: 'student' });
  if (!student) return res.status(404).json({ message: 'Student not found.' });

  const roomId = req.body.roomId || null;
  let newRoom = null;
  if (roomId) {
    if (!validId(roomId)) return res.status(400).json({ message: 'Invalid room ID.' });
    newRoom = await Room.findById(roomId);
    if (!newRoom) return res.status(404).json({ message: 'Room not found.' });
  }

  const oldRoomId = student.room ? String(student.room) : null;
  const newRoomId = newRoom ? String(newRoom._id) : null;
  if (oldRoomId !== newRoomId) {
    // Reserve the new bed atomically, so simultaneous allocations cannot exceed capacity.
    if (newRoomId) {
      const reserved = await Room.findOneAndUpdate(
        { _id: newRoom._id, $expr: { $lt: ['$occupiedBeds', '$capacity'] } },
        { $inc: { occupiedBeds: 1 } },
        { new: true }
      );
      if (!reserved) return res.status(409).json({ message: 'This room is full. Select another room.' });
    }

    try {
      student.room = newRoom ? newRoom._id : null;
      await student.save();
    } catch (error) {
      if (newRoomId) await Room.findOneAndUpdate({ _id: newRoomId, occupiedBeds: { $gt: 0 } }, { $inc: { occupiedBeds: -1 } });
      throw error;
    }
    if (oldRoomId) {
      await Room.findOneAndUpdate({ _id: oldRoomId, occupiedBeds: { $gt: 0 } }, { $inc: { occupiedBeds: -1 } });
    }
  }

  const updated = await User.findById(student._id).select('-password').populate('room');
  res.json({ student: updated.toJSON() });
}));

app.get('/api/maintenance', requireAuth, asyncHandler(async (req, res) => {
  const query = ['admin', 'warden'].includes(req.user.role) ? {} : { createdBy: req.user._id };
  const requests = await MaintenanceRequest.find(query)
    .populate('createdBy', 'name email').populate('room')
    .sort({ createdAt: -1 }).lean();
  res.json({ requests });
}));

app.get('/api/maintenance/:id/image', requireAuth, asyncHandler(async (req, res, next) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid request ID.' });
  const request = await MaintenanceRequest.findById(req.params.id).select('createdBy imageFileId imageMimeType imageName');
  if (!request) return res.status(404).json({ message: 'Maintenance request not found.' });
  const staff = ['admin', 'warden'].includes(req.user.role);
  if (!staff && String(request.createdBy) !== String(req.user._id)) {
    return res.status(403).json({ message: 'You cannot view this maintenance photo.' });
  }
  if (!request.imageFileId || !['image/jpeg', 'image/png', 'image/webp'].includes(request.imageMimeType)) {
    return res.status(404).json({ message: 'No photo is attached to this request.' });
  }
  res.set('Content-Type', request.imageMimeType);
  res.set('Content-Disposition', 'inline; filename="' + String(request.imageName || 'maintenance-photo').replace(/[^a-zA-Z0-9._-]/g, '_') + '"');
  res.set('Cache-Control', 'private, no-store');
  maintenanceImageBucket().openDownloadStream(request.imageFileId)
    .on('error', next)
    .pipe(res);
}));

app.post('/api/maintenance', requireAuth, express.json({ limit: '12mb' }), asyncHandler(async (req, res) => {
  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  const description = typeof body.description === 'string' ? body.description.trim() : '';
  const category = body.category || 'Other';
  const priority = body.priority || 'normal';
  if (!isNonEmptyText(title, 120) || !isNonEmptyText(description, 2000) ||
      !['Plumbing', 'Electrical', 'Cleanliness', 'Furniture', 'Other'].includes(category) ||
      !['low', 'normal', 'high', 'urgent'].includes(priority)) {
    return res.status(400).json({ message: 'Check the title, description, category, and priority.' });
  }
  let photo = null;
  let imageFileId = null;
  const encodedImage = body.imageBase64;
  if (encodedImage !== undefined && encodedImage !== null && encodedImage !== '') {
    const maximumEncodedLength = Math.ceil(MAX_MAINTENANCE_IMAGE_BYTES / 3) * 4;
    if (typeof encodedImage !== 'string' || encodedImage.length > maximumEncodedLength || encodedImage.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(encodedImage)) {
      return res.status(400).json({ message: 'The attached photo is invalid or larger than 8 MB.' });
    }
    const bytes = Buffer.from(encodedImage, 'base64');
    if (bytes.length === 0 || bytes.length > MAX_MAINTENANCE_IMAGE_BYTES) {
      return res.status(400).json({ message: 'The attached photo must be smaller than 8 MB.' });
    }
    const detectedMimeType = detectMaintenanceImageMime(bytes);
    if (!detectedMimeType || body.imageMimeType !== detectedMimeType) {
      return res.status(400).json({ message: 'Attach a valid JPG, PNG, or WebP photo.' });
    }
    const imageName = String(body.imageName || 'maintenance-photo')
      .trim().slice(0, 120).replace(/[^a-zA-Z0-9._-]/g, '_') || 'maintenance-photo';
    photo = { bytes, mimeType: detectedMimeType, name: imageName };
  }

  let roomId = req.user.room && req.user.room._id ? req.user.room._id : req.user.room;
  if (['admin', 'warden'].includes(req.user.role) && body.roomId) {
    if (!validId(body.roomId)) return res.status(400).json({ message: 'Invalid room ID.' });
    const selectedRoom = await Room.findById(body.roomId);
    if (!selectedRoom) return res.status(404).json({ message: 'Room not found.' });
    roomId = selectedRoom._id;
  }

  if (photo) {
    imageFileId = new mongoose.Types.ObjectId();
    await new Promise((resolve, reject) => {
      const upload = maintenanceImageBucket().openUploadStream(photo.name, {
        id: imageFileId,
        metadata: { contentType: photo.mimeType, ownerId: String(req.user._id) }
      });
      upload.once('error', reject);
      upload.once('finish', resolve);
      upload.end(photo.bytes);
    });
  }

  let request;
  try {
    request = await MaintenanceRequest.create({
      title, description, category, priority,
      createdBy: req.user._id,
      room: roomId || null,
      imageFileId,
      imageMimeType: photo ? photo.mimeType : null,
      imageName: photo ? photo.name : null
    });
  } catch (error) {
    if (imageFileId) await maintenanceImageBucket().delete(imageFileId).catch(() => {});
    throw error;
  }
  const populated = await MaintenanceRequest.findById(request._id)
    .populate('createdBy', 'name email').populate('room');
  res.status(201).json({ request: populated });
}));

app.patch('/api/maintenance/:id', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid request ID.' });
  const status = req.body.status;
  if (!['open', 'in_progress', 'resolved'].includes(status)) {
    return res.status(400).json({ message: 'Select open, in progress, or resolved.' });
  }
  const request = await MaintenanceRequest.findById(req.params.id);
  if (!request) return res.status(404).json({ message: 'Maintenance request not found.' });
  request.status = status;
  request.resolvedAt = status === 'resolved' ? new Date() : null;
  await request.save();
  const populated = await MaintenanceRequest.findById(request._id)
    .populate('createdBy', 'name email').populate('room');
  res.json({ request: populated });
}));

app.get('/api/announcements', requireAuth, asyncHandler(async (req, res) => {
  const audienceQuery = req.user.role === 'student'
    ? { audience: { $in: ['all', 'students'] } }
    : { audience: { $in: ['all', 'staff'] } };
  const announcements = await Announcement.find(audienceQuery)
    .populate('createdBy', 'name').sort({ createdAt: -1 }).lean();
  res.json({ announcements });
}));

app.post('/api/announcements', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const title = typeof req.body.title === 'string' ? req.body.title.trim() : '';
  const body = typeof req.body.body === 'string' ? req.body.body.trim() : '';
  const audience = req.body.audience || 'all';
  if (!isNonEmptyText(title, 140) || !isNonEmptyText(body, 5000) ||
      !['all', 'students', 'staff'].includes(audience)) {
    return res.status(400).json({ message: 'Enter a valid title, message, and audience.' });
  }
  const announcement = await Announcement.create({
    title, body, audience, createdBy: req.user._id
  });
  const populated = await Announcement.findById(announcement._id).populate('createdBy', 'name');
  res.status(201).json({ announcement: populated });
}));

app.patch('/api/announcements/:id', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid notice ID.' });
  const announcement = await Announcement.findById(req.params.id);
  if (!announcement) return res.status(404).json({ message: 'Notice not found.' });
  if (req.body.title !== undefined) announcement.title = req.body.title;
  if (req.body.body !== undefined) announcement.body = req.body.body;
  if (req.body.audience !== undefined) announcement.audience = req.body.audience;
  await announcement.save();
  res.json({ announcement });
}));

app.delete('/api/announcements/:id', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  if (!validId(req.params.id)) return res.status(400).json({ message: 'Invalid notice ID.' });
  const announcement = await Announcement.findByIdAndDelete(req.params.id);
  if (!announcement) return res.status(404).json({ message: 'Notice not found.' });
  res.json({ message: 'Notice deleted.' });
}));

app.get('/api/dashboard', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const [totalStudents, totalRooms, roomTotals, openMaintenance, recentRequests, recentAnnouncements] = await Promise.all([
    User.countDocuments({ role: 'student' }),
    Room.countDocuments(),
    Room.aggregate([{ $group: { _id: null, beds: { $sum: '$capacity' }, occupied: { $sum: '$occupiedBeds' } } }]),
    MaintenanceRequest.countDocuments({ status: { $ne: 'resolved' } }),
    MaintenanceRequest.find().populate('createdBy', 'name').populate('room').sort({ createdAt: -1 }).limit(5).lean(),
    Announcement.find().sort({ createdAt: -1 }).limit(3).lean()
  ]);
  const totals = roomTotals[0] || { beds: 0, occupied: 0 };
  res.json({
    stats: {
      totalStudents,
      totalRooms,
      totalBeds: totals.beds,
      occupiedBeds: totals.occupied,
      availableBeds: Math.max(0, totals.beds - totals.occupied),
      occupancyPercent: totals.beds > 0 ? Math.round((totals.occupied / totals.beds) * 100) : 0,
      openMaintenance
    },
    recentRequests,
    recentAnnouncements
  });
}));

// ML service integration. Database access remains in the authenticated Node API.
const mlServiceUrl = String(process.env.ML_SERVICE_URL || '').replace(/\/$/, '');

async function callMlService(path, payload) {
  if (!mlServiceUrl) {
    const error = new Error('ML_SERVICE_URL is not configured. Deploy the hrms-ml service and set this environment variable.');
    error.status = 503;
    throw error;
  }
  let response;
  try {
    response = await fetch(mlServiceUrl + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10000)
    });
  } catch (_) {
    const error = new Error('The ML service is unavailable. Check the hrms-ml deployment and ML_SERVICE_URL.');
    error.status = 503;
    throw error;
  }
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(body.detail || body.message || 'The ML service could not process this request.');
    error.status = response.status >= 400 && response.status < 500 ? response.status : 502;
    throw error;
  }
  return body;
}

app.post('/api/ml/predict-maintenance', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const title = typeof req.body.title === 'string' ? req.body.title.trim() : '';
  const description = typeof req.body.description === 'string' ? req.body.description.trim() : '';
  if (!isNonEmptyText(title, 120) || !isNonEmptyText(description, 2000)) {
    return res.status(400).json({ message: 'Enter a title and description for the maintenance issue.' });
  }
  const prediction = await callMlService('/predict-maintenance', { title, description });
  res.json(prediction);
}));

app.get('/api/ml/insights', requireAuth, staffOnly, asyncHandler(async (req, res) => {
  const tickets = await MaintenanceRequest.find()
    .select('category priority status createdAt resolvedAt')
    .sort({ createdAt: -1 })
    .limit(1000)
    .lean();
  const insights = await callMlService('/analytics', tickets.map((ticket) => ({
    category: ticket.category,
    priority: ticket.priority,
    status: ticket.status,
    createdAt: ticket.createdAt,
    resolvedAt: ticket.resolvedAt
  })));
  res.json(insights);
}));

app.use((req, res) => {
  res.status(404).json({ message: 'API route not found.' });
});

app.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = error && error.status ? error.status : 500;
  if (status >= 500) console.error(error);
  res.status(status).json({
    message: status >= 500 ? 'Server error. Please check the server logs.' : toSafeMessage(error)
  });
});

async function bootstrap() {
  if (!process.env.MONGODB_URI) {
    throw new Error('MONGODB_URI is required. Configure it in backend/.env or the hosting environment.');
  }
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('MongoDB connected.');

  const adminEmail = normaliseEmail(process.env.BOOTSTRAP_ADMIN_EMAIL);
  const adminPassword = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  if (adminEmail && adminPassword) {
    if (!isValidEmail(adminEmail) || !isStrongEnoughPassword(adminPassword)) {
      throw new Error('BOOTSTRAP_ADMIN_EMAIL must be valid and BOOTSTRAP_ADMIN_PASSWORD must be at least 8 characters.');
    }
    let admin = await User.findOne({ email: adminEmail });
    if (!admin) {
      admin = await User.create({
        name: process.env.BOOTSTRAP_ADMIN_NAME || 'Hostel Administrator',
        email: adminEmail,
        password: adminPassword,
        role: 'admin'
      });
      console.log('Initial administrator created from environment configuration.');
    } else if (admin.role !== 'admin') {
      admin.role = 'admin';
      await admin.save();
      console.log('Configured administrator account promoted from environment configuration.');
    }
  }

  if (process.env.SEED_DEMO_DATA === 'true') {
    if (await Room.countDocuments() === 0) {
      await Room.insertMany([
        { roomNumber: 'A-101', block: 'A Block', floor: 1, type: 'Double', capacity: 2, occupiedBeds: 0, monthlyFee: 3500 },
        { roomNumber: 'A-102', block: 'A Block', floor: 1, type: 'Triple', capacity: 3, occupiedBeds: 0, monthlyFee: 2800 },
        { roomNumber: 'A-201', block: 'A Block', floor: 2, type: 'Double', capacity: 2, occupiedBeds: 0, monthlyFee: 3500 },
        { roomNumber: 'B-101', block: 'B Block', floor: 1, type: 'Single', capacity: 1, occupiedBeds: 0, monthlyFee: 5000 },
        { roomNumber: 'B-102', block: 'B Block', floor: 1, type: 'Dormitory', capacity: 6, occupiedBeds: 0, monthlyFee: 2200 },
        { roomNumber: 'C-201', block: 'C Block', floor: 2, type: 'Double', capacity: 2, occupiedBeds: 0, monthlyFee: 3300 }
      ]);
      console.log('Sample rooms created.');
    }
    if (await Announcement.countDocuments() === 0) {
      const admin = adminEmail ? await User.findOne({ email: adminEmail }) : null;
      await Announcement.create({
        title: 'Welcome to HRMS',
        body: 'This is the hostel notice board. Staff can publish room updates, reminders, and important announcements here.',
        audience: 'all',
        createdBy: admin ? admin._id : null
      });
    }
  }

  const port = Number(process.env.PORT) || 5000;
  app.listen(port, () => console.log('HRMS API listening on port ' + port));
}

if (require.main === module) {
  bootstrap().catch((error) => {
    console.error('Could not start HRMS API:', error.message);
    process.exit(1);
  });
}

module.exports = { app, bootstrap, models: { User, Room, MaintenanceRequest, Announcement } };

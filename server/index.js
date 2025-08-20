const express = require("express");
const http = require("http");
const mongoose = require("mongoose");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const AccessLog = require("./models/access_log");
const Match = require("./models/match");

const Room = require("./models/room");
const Score = require("./models/score");
const Ban = require("./models/ban");
const User = require("./models/user");

const DB = "mongodb://deneme:deneme@ac-jpdlw8s-shard-00-00.mnuwwdl.mongodb.net:27017,ac-jpdlw8s-shard-00-01.mnuwwdl.mongodb.net:27017,ac-jpdlw8s-shard-00-02.mnuwwdl.mongodb.net:27017/tictactoe?replicaSet=atlas-bje4li-shard-0&ssl=true&authSource=admin&retryWrites=true&w=majority";
const SHUFFLE_INTERVAL = 1000;
const PORT = 3000;

const shuffleIntervals = {};
const shuffleBoards = {};
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || "change_me_now";

// ---------- HELPERS ----------
async function ensureScoreDoc(room) {
  if (!room?._id) return;
  await Score.updateOne(
    { room: room._id },
    {
      $setOnInsert: {
        room: room._id,
        gameId: room._id.toString(),
        players: room.players.map(p => ({ nickname: p.nickname, playerType: p.playerType })),
      },
    },
    { upsert: true }
  );
}

function adminAuth(req, res, next) {
  const token = req.headers["x-admin-token"];
  if (token !== ADMIN_TOKEN) return res.status(401).json({ error: "unauthorized" });
  next();
}
// index.js içinde, yardımcıların yanına ekle
function resetRoomState(r) {
  // puanları sıfırla
  (r.players || []).forEach(p => p.points = 0);

  // tahta / kuyruk / round / sıra
  r.board = Array(9).fill('');
  r.queues = { X: [], O: [] };
  r.currentRound = 1;
  r.nextRoundReady = [];
  r.turnIndex = 0;
  r.turn = r.players[0] || null;

  // lobi göstergesi
  r.isJoin = r.players.length < (r.occupancy || 2);
}
function stopShuffleFor(roomId) {
  if (shuffleIntervals[roomId]) {
    clearInterval(shuffleIntervals[roomId]);
    delete shuffleIntervals[roomId];
  }
  if (shuffleBoards[roomId]) delete shuffleBoards[roomId];
}

// Raund bittiğinde: oda puanı, skor tablosu ve kullanıcının "Skorlarım" geçmişi
async function recordRoundResult(roomId, winner) {
  const room = await Room.findById(roomId);
  if (!room) return null;

  const w = (winner === 'X' || winner === 'O') ? winner : 'draw';

  // Oda içi puan
  if (w === 'X' || w === 'O') {
    const idx = (room.players || []).findIndex(p => p.playerType === w);
    if (idx !== -1) {
      room.players[idx].points = (room.players[idx].points || 0) + 1;
      await room.save();
    }
  }

  // Score upsert
  const score = await Score.findOneAndUpdate(
    { room: room._id },
    {
      $inc:  { [`totals.${w}`]: 1 },
      $push: { history: { round: room.currentRound || 1, winner: w, at: new Date() } },
      $setOnInsert: {
        players: (room.players || []).map(p => ({ nickname: p.nickname, playerType: p.playerType })),
        gameId: room._id.toString(),
      },
    },
    { upsert: true, new: true }
  );

  // E-postaları mümkünse doğrudan room.players[*].email’den oku; yoksa AccessLog fallback
  const xP = (room.players || []).find(p => p.playerType === 'X');
  const oP = (room.players || []).find(p => p.playerType === 'O');

  async function getEmail(p) {
    if (p?.email) return (p.email || '').toLowerCase();
    try {
      const log = await AccessLog.findOne({ room: room._id, socketID: p?.socketID, action: 'join' })
                                 .sort({ createdAt: -1 });
      return (log?.userEmail || '').toLowerCase();
    } catch { return ''; }
  }

  const xEmail = await getEmail(xP);
  const oEmail = await getEmail(oP);

  const roomName = room.name || '';
  const level    = room.level || room.mode || 'easy';
  const now      = new Date();

  const docs = [];
  if (w === 'X') {
    if (xEmail) docs.push({
      userEmail: xEmail, userNickname: xP?.nickname || '',
      opponentEmail: oEmail, opponentNickname: oP?.nickname || '',
      room: room._id, roomName, level, result: 'win',
      createdAt: now, updatedAt: now,
    });
    if (oEmail) docs.push({
      userEmail: oEmail, userNickname: oP?.nickname || '',
      opponentEmail: xEmail, opponentNickname: xP?.nickname || '',
      room: room._id, roomName, level, result: 'loss',
      createdAt: now, updatedAt: now,
    });
  } else if (w === 'O') {
    if (oEmail) docs.push({
      userEmail: oEmail, userNickname: oP?.nickname || '',
      opponentEmail: xEmail, opponentNickname: xP?.nickname || '',
      room: room._id, roomName, level, result: 'win',
      createdAt: now, updatedAt: now,
    });
    if (xEmail) docs.push({
      userEmail: xEmail, userNickname: xP?.nickname || '',
      opponentEmail: oEmail, opponentNickname: oP?.nickname || '',
      room: room._id, roomName, level, result: 'loss',
      createdAt: now, updatedAt: now,
    });
  } else {
    if (xEmail) docs.push({
      userEmail: xEmail, userNickname: xP?.nickname || '',
      opponentEmail: oEmail, opponentNickname: oP?.nickname || '',
      room: room._id, roomName, level, result: 'draw',
      createdAt: now, updatedAt: now,
    });
    if (oEmail) docs.push({
      userEmail: oEmail, userNickname: oP?.nickname || '',
      opponentEmail: xEmail, opponentNickname: xP?.nickname || '',
      room: room._id, roomName, level, result: 'draw',
      createdAt: now, updatedAt: now,
    });
  }

  try {
    if (docs.length) await Match.insertMany(docs, { ordered: false });
  } catch (e) {
    console.error('save match error:', e?.message || e);
  }

  return { room, score };
}

// bağlı socket ID’lerini sağlam al
// ---------- HELPERS (tek kopya) ----------
function getLiveSocketIds(io) {
  // 1) io.sockets.sockets : Map<id, Socket>
  if (io?.sockets?.sockets && typeof io.sockets.sockets.size === 'number') {
    return new Set(io.sockets.sockets.keys());
  }
  // 2) namespace
  const nsp = (typeof io.of === 'function') ? io.of('/') : null;
  if (nsp?.sockets && typeof nsp.sockets.size === 'number') {
    return new Set(nsp.sockets.keys());
  }
  // 3) adapter fallback
  if (nsp?.adapter?.sids && typeof nsp.adapter.sids.size === 'number') {
    return new Set(nsp.adapter.sids.keys());
  }
  return new Set();
}

async function pruneDisconnectedPlayers(io, room) {
  try {
    const liveIds = getLiveSocketIds(io);
    const before = (room.players || []).length;

    room.players = (room.players || []).filter(p => liveIds.has(p.socketID));
    room.isJoin  = room.players.length < (room.occupancy || 2);

    if (room.turn && !room.players.some(p => p.socketID === room.turn.socketID)) {
      room.turnIndex = 0;
      room.turn = room.players[0] || null;
    }

    if (before !== room.players.length) {
      await room.save();
      return true;
    }
  } catch (e) {
    console.error('pruneDisconnectedPlayers error:', e?.message || e);
  }
  return false;
}

function toSummary(r) {
  return {
    id: r._id.toString(),
    _id: r._id,
    name: r.name || "",
    locked: !!(r.password && r.password.length),
    level: r.level || r.mode || 'easy',
    isJoin: r.isJoin === true,
    currentRound: r.currentRound || 1,
    maxRounds: r.maxRounds || 1,
    occupancy: r.occupancy || 2,
    playersCount: Array.isArray(r.players) ? r.players.length : 0,
    players: (r.players || []).map(p => ({ nickname: p.nickname, playerType: p.playerType })),
    isPermanent: !!r.isPermanent,
  };
}

async function emitRooms(io, toSocketId) {
  // doc olarak çek, prune et
  const docs = await Room.find({}, { board: 0, nextRoundReady: 0, turn: 0, password: 0 });
//  for (const doc of docs) await pruneDisconnectedPlayers(io, doc);

  // yayınlık lean liste
  const fresh = await Room.find({}, { board: 0, nextRoundReady: 0, turn: 0, password: 0 }).lean();
  const list = fresh
    .filter(r => r.isPermanent || (Array.isArray(r.players) && r.players.length > 0) || r.isJoin === true)
    .map(toSummary);

  if (toSocketId) io.to(toSocketId).emit('roomsList', list);
  else io.emit('roomsList', list);
}

const PERMA_ROOMS = [
  { permaKey: "perma:besiktas-1", name: "PUBLIC Beşiktaş #1", level: "besiktas" },
  { permaKey: "perma:besiktas-2", name: "PUBLIC Beşiktaş #2", level: "besiktas" },
  { permaKey: "perma:easy-1",     name: "PUBLIC Easy",        level: "easy" },
  { permaKey: "perma:medium-1",   name: "PUBLIC Medium",      level: "medium" },
  { permaKey: "perma:hard-1",     name: "PUBLIC Hard",        level: "hard" },
];

async function ensurePermanentRooms() {
  for (const cfg of PERMA_ROOMS) {
    const found = await Room.findOne({ permaKey: cfg.permaKey });

    if (!found) {
      await Room.create({
        permaKey:  cfg.permaKey,
        isPermanent: true,
        name:      cfg.name,
        level:     cfg.level,
        password:  "",
        occupancy: 2,
        isJoin:    true,
        players:   [],
        board:     Array(9).fill(""),
        queues:    { X: [], O: [] },
        currentRound: 1,
        maxRounds:    6,
        turnIndex:    0,
        turn:         null,
        nextRoundReady: [],
      });
      console.log("🧱 seeded:", cfg.permaKey, cfg.name);
      continue;
    }

    await Room.updateOne(
      { _id: found._id },
      {
        $set: {
          name: cfg.name,
          level: cfg.level,
          password: "",
          occupancy: 2,
          isPermanent: true,
          players: [],
          board: Array(9).fill(""),
          queues: { X: [], O: [] },
          isJoin: true,
          turn: null,
          turnIndex: 0,
          nextRoundReady: [],
        }
      }
    );
    console.log("🔧 ensured permanent:", cfg.permaKey);
  }
}

async function addAccessLog({ room, socket, action }) {
  try {
    const u = socket.user || {};
    await AccessLog.create({
      room: room._id,
      roomName: room.name || "",
      userNickname: (u.name || "").toString(),
      userEmail: (u.email || "").toString(),
      socketID: socket.id,
      action,
    });
  } catch (e) {
    console.error("accesslog error:", e.message);
  }
}

function swapRandomTwo(arr) {
  const filled = [];
  for (let i = 0; i < arr.length; i++) if (arr[i] !== "") filled.push(i);
  if (filled.length < 2) return arr;
  let idx1 = filled[Math.floor(Math.random() * filled.length)];
  let idx2 = idx1;
  while (idx2 === idx1) idx2 = filled[Math.floor(Math.random() * filled.length)];
  const newArr = [...arr];
  [newArr[idx1], newArr[idx2]] = [newArr[idx2], newArr[idx1]];
  return newArr;
}

const nodemailer = require("nodemailer");

async function sendVerificationEmail(email, code) {
  const transporter = nodemailer.createTransport({
    service: "gmail",   // şimdilik gmail kullanalım, uygulama şifresi gerekiyor
    auth: {
      user: "seninmailinr@gmail.com",
      pass: "sifre"   // Google hesabından alacağın App Password
    },
  });

  await transporter.sendMail({
    from: '"TicTacToe 👾" <seninmailin@gmail.com>',
    to: email, // BURASI kullanıcının girdiği mail olacak
    subject: "Doğrulama Kodun",
    text: `Doğrulama kodun: ${code}`,
    html: `<h2>Doğrulama Kodun</h2><p><b>${code}</b></p>`,
  });
}
  async function emailForSocket(roomId, socketID) {
  try {
    const log = await AccessLog.findOne({
      room: roomId,
      socketID,
      action: "join",
    }).sort({ createdAt: -1 });
    return (log?.userEmail || "").toLowerCase();
  } catch (e) {
    return "";
  }
}

async function saveMatchRound(room, winnerType /* 'X' | 'O' | 'draw' */) {
  try {
    const pX = (room.players || []).find(p => p.playerType === 'X');
    const pO = (room.players || []).find(p => p.playerType === 'O');

    const base = {
      room: room._id,
      roomName: room.name || '',
      level: room.level || 'easy',
      round: room.currentRound,
    };

    const docs = [];

    if (pX) {
      const resultForX = winnerType === 'X' ? 'win' : (winnerType === 'O' ? 'loss' : 'draw');
      docs.push({
        ...base,
        userEmail: (pX.email || '').toLowerCase(),
        userNickname: pX.nickname,
        opponentEmail: pO?.email || '',
        opponentNickname: pO?.nickname || '',
        result: resultForX,
      });
    }
    if (pO) {
      const resultForO = winnerType === 'O' ? 'win' : (winnerType === 'X' ? 'loss' : 'draw');
      docs.push({
        ...base,
        userEmail: (pO.email || '').toLowerCase(),
        userNickname: pO.nickname,
        opponentEmail: pX?.email || '',
        opponentNickname: pX?.nickname || '',
        result: resultForO,
      });
    }

    if (docs.length) await Match.insertMany(docs);
  } catch (e) {
    console.error("saveMatchRound error:", e?.message || e);
  }
}

// ---------- BOOT ----------
(async () => {
  try {
    await mongoose.connect(DB, { serverSelectionTimeoutMS: 10000 });
    console.log("✅ MongoDB connected:", mongoose.connection.host);

    const app = express();
    app.use(express.json());
    app.use(cors({ origin: '*', methods: ['GET','POST','DELETE','OPTIONS'], allowedHeaders: ['Content-Type', 'x-admin-token'] }));
    app.options(/.*/, cors());

    const server = http.createServer(app);
    const io = require("socket.io")(server, { cors: { origin: "*" } });

    
// -------- AUTH (REGISTER / VERIFY / LOGIN) --------
app.post("/auth/register", async (req, res) => {
  try {
    const { username, email, password } = req.body;

    // Daha önce kayıtlı mı kontrol et
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: "Bu e-posta adresi zaten kayıtlı" });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const code = Math.floor(100000 + Math.random() * 900000).toString();

    const user = new User({
      username,
      email,
      passwordHash,
      verificationCode: code,
    });

    await user.save();
    await sendVerificationEmail(email, code);

    res.json({ message: "Kayıt başarılı, doğrulama kodu mailine gönderildi" });
  } catch (err) {
    console.error("Register Error:", err);
    res.status(500).json({ error: "Sunucu hatası" });
  }
});


app.post("/auth/verify", async (req, res) => {
  try {
    const { email, code } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: "Kullanıcı bulunamadı" });

    if (user.verificationCode !== code) {
      return res.status(400).json({ error: "Kod hatalı" });
    }

    user.isVerified = true;
    user.verificationCode = null;
    await user.save();

    res.json({ message: "Doğrulama başarılı" });
  } catch (err) {
    res.status(500).json({ error: "Sunucu hatası" });
  }
});

// ✅ LOGIN
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    // Basit doğrulamalar
    if (!email || !password) {
      return res.status(400).json({ error: "email_password_required" });
    }

    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      return res.status(404).json({ error: "Kullanıcı bulunamadı" });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({ error: "Şifre yanlış" });
    }

    if (!user.isVerified) {
      return res.status(403).json({ error: "E-posta doğrulanmamış" });
    }

    // Şifre hash'i gibi hassas alanları döndürme
    const safeUser = {
      _id: user._id,
      username: user.username,
      email: user.email,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };

    return res.json({ message: "Giriş başarılı", user: safeUser });
  } catch (err) {
    console.error("Login Error:", err);
    return res.status(500).json({ error: "Sunucu hatası" });
  }
});



// ✅ Oda oluşturma (join zorunluluğu eklendi)
app.post("/create-room", async (req, res) => {
  const { userId } = req.body;
  const user = await User.findById(userId);

  if (!user || !user.isJoined) {
    return res.status(403).json({ msg: "Odaya katılmak için üye olmanız gerekir." });
  }

  // Oda oluşturma işlemleri...
  res.json({ msg: "Oda oluşturuldu" });
});


    // -------- ADMIN API --------
    app.get("/admin/overview", adminAuth, async (req, res) => {
      const [roomsCount, playersTotal, scoresCount, bansCount, usersCount, recentRooms] = await Promise.all([
        Room.countDocuments(),
        Room.aggregate([{ $unwind: "$players" }, { $count: "c" }]).then(a => (a[0]?.c || 0)),
        Score.countDocuments(),
        Ban.countDocuments(),
        User.countDocuments(),
        Room.find({}).sort({ createdAt: -1 }).limit(10).select({ name: 1, level: 1, isJoin: 1, createdAt: 1 }).lean(),
      ]);
      res.json({ roomsCount, playersTotal, scoresCount, bansCount, usersCount, recentRooms });
    });

    // Tüm kullanıcıları getir
// GET /admin/users
app.get("/admin/users", adminAuth, async (req, res) => {
  try {
    const page = parseInt(req.query.p) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const search = req.query.q || "";

    const filter = search
      ? {
          $or: [
            { username: { $regex: search, $options: "i" } },
            { email: { $regex: search, $options: "i" } },
          ],
        }
      : {};

    const total = await User.countDocuments(filter);
    const users = await User.find(filter)
      .skip((page - 1) * limit)
      .limit(limit)
      .sort({ createdAt: -1 });

    res.json({
      users,
      total,
      page,
      limit,
    });
  } catch (err) {
    console.error("❌ Fetch users error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// DELETE /admin/users/:id
app.delete("/admin/users/:id", adminAuth, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (err) {
    console.error("❌ Delete user error:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// GET /users/:email/matches?limit=100&page=1
// Kullanıcının maç geçmişi
app.get("/users/:email/matches", async (req, res) => {
  try {
    const email = (req.params.email || "").toLowerCase();
    if (!email) return res.json({ items: [] });

    const limit = Math.min(Math.max(parseInt(req.query.limit || "50"), 1), 200);

    const items = await Match.find({ userEmail: email })
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    res.json({ items });
  } catch (e) {
    console.error("matches endpoint error:", e?.message || e);
    res.status(500).json({ error: "server_error" });
  }
});



    app.get("/admin/rooms", adminAuth, async (req, res) => {
      const page = Math.max(parseInt(req.query.page || "1"), 1);
      const limit = Math.min(Math.max(parseInt(req.query.limit || "25"), 1), 200);
      const q = (req.query.q || "").trim();
      const filter = q ? { $or: [{ name: new RegExp(q, "i") }, { level: new RegExp(q, "i") }] } : {};
      const [items, total] = await Promise.all([
        Room.find(filter)
          .sort({ createdAt: -1 })
          .skip((page - 1) * limit)
          .limit(limit)
          .select({ name: 1, level: 1, isJoin: 1, occupancy: 1, players: 1, currentRound: 1, maxRounds: 1, createdAt: 1, password: 1 })
          .lean(),
        Room.countDocuments(filter),
      ]);
      items.forEach(r => (r.locked = !!(r.password && r.password.length)));
      res.json({ items, total, page, limit });
    });

app.get('/debug/rooms', async (req, res) => {
  const docs = await Room.find({}).lean();
  res.json({
    count: docs.length,
    perma: docs.filter(d => d.isPermanent).length,
    sample: docs.slice(0, 5).map(d => ({
      _id: d._id, name: d.name, level: d.level, isJoin: d.isJoin, isPermanent: d.isPermanent,
      players: (d.players||[]).map(p => p.nickname)
    }))
  });
});

    app.get("/admin/rooms/:id", adminAuth, async (req, res) => {
      const room = await Room.findById(req.params.id).lean();
      if (!room) return res.status(404).json({ error: "not_found" });
      room.locked = !!(room.password && room.password.length);
      res.json(room);
    });

    app.delete("/admin/rooms/:id", adminAuth, async (req, res) => {
      const id = req.params.id;
      if (shuffleIntervals[id]) { clearInterval(shuffleIntervals[id]); delete shuffleIntervals[id]; }
      delete shuffleBoards[id];
      await Promise.all([ Room.deleteOne({ _id: id }), Score.deleteOne({ room: id }) ]);
      res.json({ ok: true });
    });

    app.post("/admin/rooms/:id/kick", adminAuth, async (req, res) => {
      const id = req.params.id;
      const { socketID, nickname } = req.body || {};
      const room = await Room.findById(id);
      if (!room) return res.status(404).json({ error: "not_found" });
      const before = room.players.length;

      room.players = room.players.filter(p => {
        if (socketID) return p.socketID !== socketID;
        if (nickname) return p.nickname !== nickname;
        return true;
      });

      room.isJoin = room.players.length < room.occupancy;
      await room.save();
      res.json({ ok: true, removed: before - room.players.length, players: room.players });
    });

    app.get("/admin/scores", adminAuth, async (req, res) => {
      const { roomId } = req.query;
      const filter = roomId ? { room: roomId } : {};
const scores = await Score.find(filter)
  .sort({ createdAt: -1 })
  .limit(100)
  .populate('room', 'name');
return res.json(scores);

    });

    app.delete("/admin/scores/:roomId", adminAuth, async (req, res) => {
      await Score.deleteOne({ room: req.params.roomId });
      res.json({ ok: true });
    });

    app.get("/admin/bans", adminAuth, async (req, res) => {
      const bans = await Ban.find().sort({ createdAt: -1 }).lean();
      res.json(bans);
    });

    app.post("/admin/bans", adminAuth, async (req, res) => {
      const { nickname, reason } = req.body || {};
      if (!nickname) return res.status(400).json({ error: "nickname_required" });
      const b = await Ban.findOneAndUpdate({ nickname }, { $set: { reason: reason || "" } }, { upsert: true, new: true });
      res.json({ ok: true, ban: b });
    });

    app.delete("/admin/bans/:nickname", adminAuth, async (req, res) => {
      await Ban.deleteOne({ nickname: req.params.nickname });
      res.json({ ok: true });
    });


// === SOCKET.IO (tek middleware + tek connection) ===

// 1) Kimlik middleware — io.on'dan önce
io.use((socket, next) => {
  const h = socket.handshake || {};
  const a = (h.auth && Object.keys(h.auth).length) ? h.auth : (h.query || {});
  socket.user = { name: (a.name || '').toString(), email: (a.email || '').toString() };
  next();
});

// --- Tek connection handler ---
io.on('connection', (socket) => {
  console.log('⚡ New client connected:', socket.id, socket.user);
  socket.setMaxListeners(20);

  socket.on('listRooms', async () => {
    console.log(`[listRooms] from ${socket.id}`);
    emitRooms(io, socket.id);
  });

  socket.on('bindUser', (userId) => { socket.userId = userId; });

  // ------- ODA OLUŞTUR -------
  socket.on('createRoom', async (payload, cb) => {
    try {
      const u = socket.user || {};
     const creator = {
  nickname:  (u.name && u.name.trim()) ? u.name.trim() : 'Player',
  email:     (u.email || '').toLowerCase(),
  socketID:  socket.id,
  playerType:'X',
  points:    0,
  email:     (u.email || '').toLowerCase(),
};


      const room = await Room.create({
        name:        payload?.name || payload?.roomName || `Room-${Date.now()}`,
        password:    payload?.password || '',
        level:       payload?.level || payload?.mode || 'easy',
        isJoin:      true,
        occupancy:   payload?.occupancy || 2,
        currentRound:1,
        maxRounds:   6,
        board:       Array(9).fill(""),
        queues:      { X: [], O: [] },
        nextRoundReady: [],
        players:     [creator],
        turn:        creator,
        turnIndex:   0,
      });

      const roomId = String(room._id);
      socket.join(roomId);

      // client listener’ı
      socket.emit('createRoomSuccess', room);
      // ack
      cb && cb({ ok: true, room });

      await emitRooms(io);
      console.log('✅ Room created:', roomId);
    } catch (e) {
      const msg = e?.message || 'createRoom failed';
      socket.emit('errorOccurred', msg);
      cb && cb({ ok: false, message: msg });
    }
  });

  // ------- ODAYA KATIL -------
// ------- ODAYA KATIL -------
socket.on('joinRoom', async ({ roomId, password = '' }, cb) => {
  try {
    const u = socket.user || {};
    if (!u.name) throw new Error('Auth missing');

    const r = await Room.findById(roomId);
    if (!r) throw new Error('Room not found');
    if (r.password && r.password !== password) throw new Error('Wrong password');

    // X dolu mu? ikinci oyuncu O olsun
    const hasX = (r.players || []).some(p => p.playerType === 'X');
    const playerType = hasX ? 'O' : 'X';

    // ❗ artık nickname ile “already” kontrolü YOK
    const already = (r.players || []).find(p =>
      p.socketID === socket.id || (socket.userId && p.userId === socket.userId)
    );

    const wasEmpty = (r.players?.length || 0) === 0;

    if (!already) {
      if ((r.players?.length || 0) >= (r.occupancy || 2)) throw new Error('Room is full');

      // aynı nick varsa #2, #3… ekle
      let nick = (u.name || 'Player').trim();
      if (r.players.some(p => p.nickname === nick)) {
        const base = nick; let i = 2;
        while (r.players.some(p => p.nickname === `${base}#${i}`)) i++;
        nick = `${base}#${i}`;
      }

r.players.push({
  nickname: nick, // üretilmiş benzersiz takma ad
  email: (u.email || '').toLowerCase(),
  socketID: socket.id,
  playerType,
  points: 0,
});


    }

    // İlk oyuncu girdiyse başlangıç state’i kur
    if (wasEmpty) {
      r.turnIndex = 0;
      r.turn = r.players.find(p => p.playerType === 'X') || r.players[0] || null;
      r.board = Array(9).fill('');
      r.queues = { X: [], O: [] };
      r.currentRound = 1;
      r.nextRoundReady = [];
    }

    // joinable flag’i
    r.isJoin = r.players.length < (r.occupancy || 2);
    await r.save();

    const id = String(r._id);
    socket.join(id);
    await addAccessLog({ room: r, socket, action: "join" });

    // katılana ve odaya yayın
    socket.emit('joinRoomSuccess', r);
    io.to(id).emit('updateRoom', r);

    // 2 oyuncu tamamlandıysa bekleme bitti -> isJoin=false kaydet + herkese yayın
    if (r.players.length >= (r.occupancy || 2)) {
      r.isJoin = false;
      await r.save();

      // odaya yayın
      io.to(id).emit('updateRoom', r);
      io.to(id).emit('gameReady', r); // opsiyonel ama faydalı

      // oyuncu soketlerine doğrudan da gönder (rooms üyeliği bozulduysa bile)
      for (const p of r.players) {
        if (p.socketID) {
          io.to(p.socketID).emit('updateRoom', r);
          io.to(p.socketID).emit('gameReady', r);
        }
      }
    }

    await emitRooms(io);
    cb && cb({ ok: true });
    console.log('✅ joinRoom ok:', id, 'players=', r.players.length, 'isJoin=', r.isJoin);
  } catch (e) {
    const msg = e?.message || 'joinRoom failed';
    console.error('joinRoom err:', msg);
    socket.emit('errorOccurred', msg);
    cb && cb({ ok: false, message: msg });
  }
});

 socket.on('leaveRoom', async ({ roomId }) => {
    try {
      const r = await Room.findById(roomId);
      if (!r) return;

      // oyuncuyu çıkar
      r.players = (r.players || []).filter(p => p.socketID !== socket.id);
      stopShuffleFor(String(r._id));

      // her çıkışta round/puan sıfırla (talebin bu yöndeydi)
      resetRoomState(r);

      await r.save();

      // skor kaydını da temizlemek istersen:
      try { await Score.deleteOne({ room: r._id }); } catch (_) {}

      io.to(String(r._id)).emit('updateRoom', r);
      await emitRooms(io);

      socket.leave(String(r._id));
    } catch (e) {
      console.error('leaveRoom error:', e?.message || e);
    }
  });
  // ------- OYUN EVENTLERİ (mevcut akış korunuyor) -------
socket.on("tap", async ({ index, roomId }) => {
  try {
    const room = await Room.findById(roomId);
    if (!room) return;

    const choice = room?.turn?.playerType;
    if (!choice) return; // sıra belli değilse hamle alma

    if (room.level === "hard") {
      if (!shuffleBoards[roomId]) shuffleBoards[roomId] = Array(9).fill("");
      if (shuffleBoards[roomId][index] !== "") return;
      shuffleBoards[roomId][index] = choice;
    } else {
      if (!room.board) room.board = Array(9).fill("");
      if (room.board[index] !== "") return;
      room.board[index] = choice;

      if (room.level === "besiktas") {
        room.queues[choice].push(index);
        if (room.queues[choice].length > 3) {
          const oldestIndex = room.queues[choice].shift();
          if (typeof oldestIndex === "number") room.board[oldestIndex] = "";
        }
      }
    }

    // Sıra değiştir
    if ((room.players || []).length >= 2) {
      room.turnIndex = room.turnIndex === 0 ? 1 : 0;
      room.turn = room.players[room.turnIndex];
    } else {
      room.turnIndex = 0;
      room.turn = room.players[0] || null;
    }

    await room.save();
    const boardToSend = room.level === "hard" ? shuffleBoards[roomId] : room.board;
    io.to(roomId).emit("tapped", { board: boardToSend, index, choice, room });
  } catch (e) { console.error(e); }
  emitRooms(io);
});


  socket.on("startHardModeShuffle", async ({ roomId, board }) => {
    const room = await Room.findById(roomId);
    if (!room || room.level !== "hard") return;
    if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
    shuffleBoards[roomId] = Array.isArray(board) && board.length === 9 ? [...board] : Array(9).fill("");
    shuffleIntervals[roomId] = setInterval(() => {
      if (!shuffleBoards[roomId]) shuffleBoards[roomId] = Array(9).fill("");
      shuffleBoards[roomId] = swapRandomTwo(shuffleBoards[roomId]);
      io.to(roomId).emit("shuffleBoard", { board: shuffleBoards[roomId] });
    }, SHUFFLE_INTERVAL);
    emitRooms(io);
  });

  socket.on("stopHardModeShuffle", ({ roomId }) => {
    if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
    if (shuffleBoards[roomId]) delete shuffleBoards[roomId];
    emitRooms(io);
  });

  socket.on("winner", async ({ winnerSocketId, roomId }) => {
    try {
      const room = await Room.findById(roomId);
      if (!room) return;
      const winner = room.players.find(p => p.socketID === winnerSocketId);
      if (!winner) return;
      const result = await recordRoundResult(roomId, winner.playerType);
await saveMatchRound(result.room, winner.playerType);

      if (room.level === "hard") {
        if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
        if (shuffleBoards[roomId]) delete shuffleBoards[roomId];
      }

      if (result?.room.players.find(p => p.socketID === winnerSocketId)?.points >= result?.room.maxRounds) {
        io.to(roomId).emit("endGame", winner);
      } else {
        io.to(roomId).emit("pointIncrease", winner);
      }

      if (result?.score) {
        io.to(roomId).emit("scoreUpdated", {
          players: result.room.players,
          totals: result.score.totals,
          history: result.score.history.slice(-5),
        });
      }
    } catch (e) { console.error(e); }
    emitRooms(io);
  });
// --- NEXT ROUND (Play Again) ---
// İki oyuncu da "Tekrar Oyna" dediğinde yeni raund
socket.on('readyForNextRound', async ({ roomId, socketID }, cb) => {
  try {
    if (!roomId) return cb && cb({ ok: false, message: 'roomId missing' });

    const r = await Room.findById(roomId);
    if (!r) return cb && cb({ ok: false, message: 'room not found' });

    const sid = socketID || socket.id; // <<< güvenli
    r.nextRoundReady = Array.isArray(r.nextRoundReady) ? r.nextRoundReady.filter(Boolean) : [];

    if (!r.nextRoundReady.includes(sid)) {
      r.nextRoundReady.push(sid);
      await r.save();
    }

    const playersCount = (r.players || []).length;
    const need = Math.min(playersCount, (r.occupancy || 2)); // genelde 2

    if (r.nextRoundReady.length >= need) {
      // yeni raund state
      r.currentRound += 1;
      r.board = Array(9).fill('');
      r.queues = { X: [], O: [] };
      r.nextRoundReady = [];

      // sırayı sabitle: X başlasın (yoksa ilk oyuncu)
      const p0 = r.players.find(p => p.playerType === 'X') || r.players[0] || null;
      r.turn = p0;
      r.turnIndex = p0 ? r.players.findIndex(p => p.socketID === p0.socketID) : 0;

      await r.save();
      io.to(roomId).emit('startNextRound', r);
    } else {
      io.to(roomId).emit('readyState', { ready: r.nextRoundReady.length, need });
    }

    cb && cb({ ok: true });
  } catch (e) {
    console.error('readyForNextRound err:', e?.message || e);
    cb && cb({ ok: false, message: 'server error' });
  }
});

 socket.on("draw", async ({ roomId }) => {
  try {
    const room = await Room.findById(roomId);
    if (room?.level === "hard") {
      if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
      if (shuffleBoards[roomId]) delete shuffleBoards[roomId];
    }

   const result = await recordRoundResult(roomId, "draw");
await saveMatchRound(result.room, 'draw'); // ✅


    if (result?.score) {
      io.to(roomId).emit("scoreUpdated", {
        players: result.room.players,
        totals: result.score.totals,
        history: result.score.history.slice(-5),
      });
    }
  } catch (e) { console.error(e); }
  emitRooms(io);
});

  socket.on("startNextRound", ({ roomId, board }) => {
    if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
    shuffleBoards[roomId] = [...board];
  });

  socket.on("timeout", async ({ roomId }) => {
    if (shuffleIntervals[roomId]) { clearInterval(shuffleIntervals[roomId]); delete shuffleIntervals[roomId]; }
    if (shuffleBoards[roomId]) delete shuffleBoards[roomId];
    io.to(roomId).emit("timeoutGame");
    emitRooms(io);
  });

  // ------- ÇIKIŞ -------
socket.on("disconnect", async (reason) => {
  try {
    const rooms = await Room.find({ "players.socketID": socket.id });
    for (const r of rooms) {
      await addAccessLog({ room: r, socket, action: "leave" });

      // oyuncuyu çıkar
      r.players = (r.players || []).filter(p => p.socketID !== socket.id);

      // hard mod shuffle durdur
      stopShuffleFor(String(r._id));

      // her çıkışta round/puan sıfırla
      resetRoomState(r);

      await r.save();

      // skor kaydını da temizlemek istersen:
      try { await Score.deleteOne({ room: r._id }); } catch (_) {}

      io.to(String(r._id)).emit('updateRoom', r);
    }
    await emitRooms(io);
  } catch (e) {
    console.error("disconnect cleanup error:", e?.message || e);
  }
  console.log("❌ Client disconnected:", socket.id, reason);
});


  // Bağlanır bağlanmaz bu sokete o anki listeyi gönder
  emitRooms(io, socket.id);
});
await ensurePermanentRooms();
    const permaCount = await Room.countDocuments({ isPermanent: true });
    const allCount   = await Room.countDocuments({});
    console.log(`🧱 permaRooms in DB = ${permaCount} / all=${allCount}`);
    await emitRooms(io);

    server.listen(PORT, () => console.log(`🚀 Server started on port ${PORT}`));
  } catch (err) {
    console.error("❌ Mongo bağlantı hatası:", err);
    process.exit(1);
  }
})();
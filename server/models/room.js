// server/models/room.js
const mongoose = require("mongoose");
const playerSchema = require("./player");

const roomSchema = new mongoose.Schema(
  {
    // Oda / katılım
    name:       { type: String, trim: true, default: "" },
    password:   { type: String, default: "" },
    occupancy:  { type: Number, default: 2 },
    isJoin:     { type: Boolean, default: true },
    roomOwner:  { type: mongoose.Schema.Types.ObjectId, ref: "User" },

    // Oyun ayarları
    level: {
      type: String,
      enum: ["easy", "medium", "hard", "besiktas"],
      default: "easy",
    },
    maxRounds:    { type: Number, default: 6 },
    currentRound: { type: Number, default: 1, required: true },

    // Oyuncular
    players: { type: [playerSchema], default: [] },

    // Tahta ve kuyruklar
    board: {
      type: [String],
      default: () => Array(9).fill(""),
    },
    queues: {
      X: { type: [Number], default: [] },
      O: { type: [Number], default: [] },
    },

    // Sıra bilgisi
    turn:      { type: playerSchema, default: null }, // ilk oyuncu girince set edilecek
    turnIndex: { type: Number, default: 0 },

    // “Tekrar oyna” el sıkışması
    nextRoundReady: { type: [String], default: [] },

    // Sabit odalar
    isPermanent: { type: Boolean, default: false },
    permaKey:    { type: String, unique: true, sparse: true }, // örn: "perma:hard-1"
  },
  { timestamps: true }
);

// (opsiyonel) küçük sorgu iyileştirmeleri
roomSchema.index({ level: 1, isJoin: 1 });
roomSchema.index({ createdAt: -1 });

module.exports = mongoose.model("Room", roomSchema);

// server/models/match.js
const mongoose = require('mongoose');

const MatchSchema = new mongoose.Schema({
  userEmail: { type: String, index: true },         // kimin skor satırı
  userNickname: { type: String, default: "" },

  opponentEmail: { type: String, default: "" },
  opponentNickname: { type: String, default: "" },

  room: { type: mongoose.Schema.Types.ObjectId, ref: 'Room' },
  roomName: { type: String, default: "" },
  level: { type: String, default: "" },             // easy/medium/hard/besiktas

  result: { type: String, enum: ['win', 'loss', 'draw'] },
}, { timestamps: true });

module.exports = mongoose.model('Match', MatchSchema);

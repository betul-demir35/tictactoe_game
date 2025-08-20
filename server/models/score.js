const mongoose = require('mongoose');

const scoreSchema = new mongoose.Schema({
  room:   { type: mongoose.Schema.Types.ObjectId, ref: 'Room', required: true, index: true },
  gameId: { type: String, index: true }, // oda/oyun etiketi istersen
  players: [{
    nickname: String,
    playerType: { type: String, enum: ['X','O'] },
  }],
  totals: {
    X:    { type: Number, default: 0 },
    O:    { type: Number, default: 0 },
    draw: { type: Number, default: 0 },
  },
  history: [{
    round:  Number,
    winner: { type: String, enum: ['X','O','draw'], required: true },
    at:     { type: Date, default: Date.now }
  }],
}, { timestamps: true });

module.exports = mongoose.model('Score', scoreSchema);

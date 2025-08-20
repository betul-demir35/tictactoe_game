// Mongoose kütüphanesini projeye dahil ediyoruz (MongoDB ile çalışmak için)
const mongoose = require("mongoose");

// Oyuncu bilgilerinin şemasını tanımlıyoruz
const playerSchema = new mongoose.Schema(
  {
    nickname: { type: String, trim: true },
    socketID: String,
    points: { type: Number, default: 0 },
    playerType: { type: String, enum: ["X", "O"], required: true },
  },
  { _id: false } // embedded kullanım; ayrı _id oluşturmasın
);
// Bu şemayı dışa aktarıyoruz, böylece başka dosyalarda kullanılabilir
module.exports = playerSchema;

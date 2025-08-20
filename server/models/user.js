const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    // ---- Kayıt/Giriş bilgileri ----
    username: { type: String, trim: true, required: true }, // Oyun içi isim
    email: { 
      type: String, 
      trim: true, 
      lowercase: true, 
      required: true, 
      unique: true 
    },
    passwordHash: { type: String, required: true }, // Şifre (bcrypt hash)
    isVerified: { type: Boolean, default: false },  // Email doğrulandı mı
    verificationCode: { type: String },             // 6 haneli kod

    // ---- Oyun bilgileri ----
    socketID: { type: String, default: "" },        // Socket.IO bağlantısı
    isJoined: { type: Boolean, default: false },    // Bir odaya bağlı mı
    currentRoom: {                                  // O anda hangi odada
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      default: null,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("User", userSchema);

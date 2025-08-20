// server/models/ban.js
const mongoose = require("mongoose");

const banSchema = new mongoose.Schema(
  {
    nickname: { type: String, required: true, unique: true, trim: true },
    reason:   { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Ban", banSchema);

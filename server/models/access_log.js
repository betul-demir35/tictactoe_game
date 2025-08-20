const mongoose = require("mongoose");

const accessLogSchema = new mongoose.Schema(
  {
    room:         { type: mongoose.Schema.Types.ObjectId, ref: "Room", required: true, index: true },
    roomName:     { type: String, default: "" },

    userNickname: { type: String, default: "" },
    userEmail:    { type: String, default: "" },
    socketID:     { type: String, default: "" },

    action:       { type: String, enum: ["join", "leave"], required: true }, // join/leave
    at:           { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model("AccessLog", accessLogSchema);

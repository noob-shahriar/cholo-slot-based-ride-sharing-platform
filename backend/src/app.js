const express = require("express");
const cors = require("cors");
const rideRoutes = require("./routes/rideRoutes");
const bookingRoutes = require("./routes/bookingRoutes");
const fareRoutes = require("./routes/fareRoutes");
const paymentRoutes = require("./routes/paymentRoutes");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Cholo backend is running");
});

app.use("/api/rides", rideRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/api/fares", fareRoutes);
app.use("/api/payments", paymentRoutes);

module.exports = app;
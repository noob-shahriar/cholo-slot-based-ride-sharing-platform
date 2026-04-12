const express = require("express");
const router = express.Router();
const rideController = require("../controllers/rideController");
const seatController = require("../controllers/seatController");

router.post("/", rideController.createRide);
router.get("/:id/seat-map", seatController.getSeatMap);
router.get("/:id", rideController.getRideById);
router.put("/:id/route", rideController.updateRideRoute);
router.put("/:id/start", rideController.startRide);
router.put("/:id/cancel", rideController.cancelRide);

module.exports = router;
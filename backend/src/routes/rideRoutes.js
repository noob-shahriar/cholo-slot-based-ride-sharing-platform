const express = require("express");
const router = express.Router();
const rideController = require("../controllers/rideController");

router.post("/", rideController.createRide);
router.get("/:id", rideController.getRideById);
router.put("/:id/route", rideController.updateRideRoute);
router.put("/:id/start", rideController.startRide);
router.put("/:id/cancel", rideController.cancelRide);
router.put("/:id/end", rideController.endRide);

module.exports = router;
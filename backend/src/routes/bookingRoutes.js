const express = require("express");
const router = express.Router();
const bookingController = require("../controllers/bookingController");
const seatController = require("../controllers/seatController");

router.post("/", bookingController.createBookingRequest);
router.get("/ride/:rideId", bookingController.getBookingRequestsByRide);
router.get("/:id", bookingController.getBookingById);
router.post("/:id/seat/lock", seatController.lockSeat);
router.post("/:id/seat/release", seatController.releaseSeat);
router.post("/:id/seat/confirm", seatController.confirmSeat);
router.put("/:id/accept", bookingController.acceptBookingRequest);
router.put("/:id/reject", bookingController.rejectBookingRequest);

module.exports = router;
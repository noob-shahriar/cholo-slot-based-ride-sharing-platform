const seatService = require("../services/seatService");

function mapSeatError(code, message) {
  switch (code) {
    case "BOOKING_NOT_FOUND":
      return { status: 404, message: message || "Booking not found" };
    case "BOOKING_NOT_ACCEPTED":
      return { status: 400, message: message || "Booking must be accepted before seat selection." };
    case "RIDE_NOT_PLANNED":
      return { status: 400, message: message || "Seats can only be reserved while the ride is planned." };
    case "SEAT_ALREADY_CONFIRMED":
      return { status: 400, message: message || "Seat is already confirmed for this booking." };
    case "INVALID_SEAT":
      return { status: 400, message: message || "Invalid seat index." };
    case "SEAT_HELD_BY_OTHER":
      return { status: 409, message: message || "This seat is temporarily held by another passenger." };
    case "SEAT_ALREADY_BOOKED":
      return { status: 409, message: message || "This seat is already booked." };
    case "NO_ACTIVE_LOCK":
      return { status: 400, message: message || "No active seat lock. Select a seat again." };
    case "SEAT_MISMATCH":
      return { status: 400, message: message || "Seat does not match your lock." };
    case "PICKUP_DROPOFF_REQUIRED":
      return { status: 400, message: message || "Pickup and drop-off coordinates are required." };
    case "SEAT_RACE_LOST":
      return {
        status: 409,
        message: message || "Another passenger confirmed this seat first. Please choose another.",
      };
    default:
      return { status: 500, message: message || "Unexpected error" };
  }
}

exports.getSeatMap = async (req, res) => {
  try {
    const rideId = Number(req.params.id);
    const data = await seatService.getSeatMap(rideId);
    if (!data) {
      return res.status(404).json({ message: "Ride not found" });
    }
    res.json({
      rideId,
      rideStatus: data.ride.status,
      totalSeats: data.ride.seats,
      lockTtlMs: seatService.DEFAULT_LOCK_MS,
      seats: data.seats,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.lockSeat = async (req, res) => {
  try {
    const bookingRequestId = Number(req.params.id);
    const seatIndex = Number(req.body?.seatIndex);

    if (!bookingRequestId || !Number.isInteger(seatIndex)) {
      return res.status(400).json({ message: "seatIndex is required (integer)." });
    }

    const lock = await seatService.lockSeatForBooking(bookingRequestId, seatIndex);
    res.status(201).json({
      message: "Seat held temporarily",
      lock: {
        rideId: lock.rideId,
        seatIndex: lock.seatIndex,
        bookingRequestId: lock.bookingRequestId,
        expiresAt: lock.expiresAt.toISOString(),
      },
      lockTtlMs: seatService.DEFAULT_LOCK_MS,
    });
  } catch (error) {
    const mapped = mapSeatError(error.code, error.message);
    res.status(mapped.status).json({ message: mapped.message, code: error.code });
  }
};

exports.releaseSeat = async (req, res) => {
  try {
    const bookingRequestId = Number(req.params.id);
    if (!bookingRequestId) {
      return res.status(400).json({ message: "Invalid booking id" });
    }
    const result = await seatService.releaseSeatLock(bookingRequestId);
    res.json({ message: result.released ? "Lock released" : "No lock to release", ...result });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.confirmSeat = async (req, res) => {
  try {
    const bookingRequestId = Number(req.params.id);
    if (!bookingRequestId) {
      return res.status(400).json({ message: "Invalid booking id" });
    }

    const result = await seatService.confirmSeatForBooking(bookingRequestId, req.body ?? {});

    if (result.already) {
      return res.json({
        message: "Seat was already confirmed",
        bookingRequest: result.booking,
        confirmedSeat: result.confirmedSeat,
      });
    }

    res.status(201).json({
      message: "Seat confirmed",
      bookingRequest: result.booking,
      confirmedSeat: result.confirmedSeat,
    });
  } catch (error) {
    const mapped = mapSeatError(error.code, error.message);
    res.status(mapped.status).json({ message: mapped.message, code: error.code });
  }
};

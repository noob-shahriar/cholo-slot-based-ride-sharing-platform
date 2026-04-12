const { processMockPayment } = require("../services/paymentService");

function mapPayError(code) {
  switch (code) {
    case "BOOKING_NOT_FOUND":
      return { status: 404, message: "Booking not found" };
    case "BOOKING_NOT_ACCEPTED":
      return { status: 400, message: "Booking must be accepted before payment." };
    case "SEAT_NOT_CONFIRMED":
      return { status: 400, message: "Confirm your seat before paying." };
    case "RIDE_CANCELLED":
      return { status: 400, message: "This ride was cancelled." };
    case "PICKUP_DROPOFF_REQUIRED":
      return { status: 400, message: "Pickup and drop-off are required for pricing." };
    default:
      return { status: 500, message: "Payment failed" };
  }
}

exports.mockPay = async (req, res) => {
  try {
    const bookingRequestId = Number(req.body?.bookingRequestId);
    if (!bookingRequestId) {
      return res.status(400).json({ message: "bookingRequestId is required." });
    }

    const mockMethod = req.body?.mockMethod ?? "mock_card";
    const idempotencyKey =
      typeof req.body?.idempotencyKey === "string" && req.body.idempotencyKey.trim().length > 0
        ? req.body.idempotencyKey.trim()
        : null;

    const result = await processMockPayment({
      bookingRequestId,
      mockMethod,
      idempotencyKey,
    });

    if (result.idempotent) {
      return res.json({
        message: "Idempotent replay",
        payment: result.payment,
        bookingRequest: result.booking,
      });
    }

    if (result.alreadyPaid) {
      return res.json({
        message: "Already paid",
        payment: result.payment,
        bookingRequest: result.booking,
      });
    }

    res.status(201).json({
      message: "Payment successful (mock)",
      payment: result.payment,
      bookingRequest: result.booking,
    });
  } catch (error) {
    const mapped = mapPayError(error.code);
    res.status(mapped.status).json({ message: mapped.message, code: error.code });
  }
};

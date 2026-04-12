const prisma = require("../lib/prisma");
const { computeFareQuote } = require("./fareService");

async function refundPaymentsForRide(rideId) {
  const paidBookings = await prisma.bookingRequest.findMany({
    where: {
      rideId,
      paymentStatus: "PAID",
    },
    include: { payment: true },
  });

  let refunded = 0;

  await prisma.$transaction(async (tx) => {
    for (const b of paidBookings) {
      if (b.payment && b.payment.status === "COMPLETED") {
        await tx.payment.update({
          where: { id: b.payment.id },
          data: { status: "REFUNDED" },
        });
        await tx.bookingRequest.update({
          where: { id: b.id },
          data: { paymentStatus: "REFUNDED" },
        });
        refunded += 1;
      }
    }
  });

  return { refundedCount: refunded };
}

async function processMockPayment({ bookingRequestId, mockMethod, idempotencyKey }) {
  if (idempotencyKey) {
    const existing = await prisma.payment.findUnique({
      where: { idempotencyKey },
      include: { bookingRequest: { include: { ride: true, confirmedSeat: true } } },
    });
    if (existing) {
      return { idempotent: true, payment: existing, booking: existing.bookingRequest };
    }
  }

  const booking = await prisma.bookingRequest.findUnique({
    where: { id: bookingRequestId },
    include: {
      ride: true,
      confirmedSeat: true,
      payment: true,
    },
  });

  if (!booking) {
    const err = new Error("BOOKING_NOT_FOUND");
    err.code = "BOOKING_NOT_FOUND";
    throw err;
  }

  if (booking.status !== "ACCEPTED") {
    const err = new Error("BOOKING_NOT_ACCEPTED");
    err.code = "BOOKING_NOT_ACCEPTED";
    throw err;
  }

  if (!booking.confirmedSeat) {
    const err = new Error("SEAT_NOT_CONFIRMED");
    err.code = "SEAT_NOT_CONFIRMED";
    throw err;
  }

  if (booking.ride.status === "CANCELLED") {
    const err = new Error("RIDE_CANCELLED");
    err.code = "RIDE_CANCELLED";
    throw err;
  }

  if (booking.paymentStatus === "PAID" && booking.payment) {
    return { idempotent: false, alreadyPaid: true, payment: booking.payment, booking };
  }

  const latOk =
    booking.pickupLat != null &&
    booking.pickupLng != null &&
    booking.dropoffLat != null &&
    booking.dropoffLng != null;

  if (!latOk) {
    const err = new Error("PICKUP_DROPOFF_REQUIRED");
    err.code = "PICKUP_DROPOFF_REQUIRED";
    throw err;
  }

  const quote = await computeFareQuote({
    ride: booking.ride,
    pickupLat: booking.pickupLat,
    pickupLng: booking.pickupLng,
    dropoffLat: booking.dropoffLat,
    dropoffLng: booking.dropoffLng,
    bookingRequestId: booking.id,
  });

  const created = await prisma.$transaction(async (tx) => {
    const pay = await tx.payment.create({
      data: {
        bookingRequestId: booking.id,
        amountCents: quote.totalCents,
        currency: quote.currency,
        status: "COMPLETED",
        mockMethod: mockMethod ?? "mock_card",
        fareBreakdown: { ...quote.breakdown, totalCents: quote.totalCents },
        idempotencyKey: idempotencyKey ?? null,
      },
    });

    const updated = await tx.bookingRequest.update({
      where: { id: booking.id },
      data: {
        paymentStatus: "PAID",
        fareAmountCents: quote.totalCents,
        fareBreakdown: quote.breakdown,
      },
      include: { ride: true, confirmedSeat: true, payment: true, passenger: true },
    });

    return { payment: pay, booking: updated };
  });

  return { idempotent: false, alreadyPaid: false, ...created };
}

module.exports = {
  refundPaymentsForRide,
  processMockPayment,
};

const prisma = require("../lib/prisma");

const DEFAULT_LOCK_MS = Number(process.env.SEAT_LOCK_MS || 5 * 60 * 1000);

async function deleteExpiredLocks(rideId) {
  await prisma.seatLock.deleteMany({
    where: {
      rideId,
      expiresAt: { lt: new Date() },
    },
  });
}

async function getSeatMap(rideId) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) return null;

  await deleteExpiredLocks(rideId);

  const locks = await prisma.seatLock.findMany({
    where: { rideId, expiresAt: { gt: new Date() } },
    include: { bookingRequest: { include: { passenger: true } } },
  });

  const confirmed = await prisma.confirmedSeat.findMany({
    where: { rideId },
    include: { bookingRequest: { include: { passenger: true } } },
  });

  const lockBySeat = new Map(locks.map((l) => [l.seatIndex, l]));
  const confirmedBySeat = new Map(confirmed.map((c) => [c.seatIndex, c]));

  const seats = [];
  for (let i = 1; i <= ride.seats; i += 1) {
    const conf = confirmedBySeat.get(i);
    if (conf) {
      seats.push({
        seatIndex: i,
        state: "BOOKED",
        bookingRequestId: conf.bookingRequestId,
        passengerName: conf.bookingRequest.passenger?.name ?? null,
      });
      continue;
    }
    const lock = lockBySeat.get(i);
    if (lock) {
      seats.push({
        seatIndex: i,
        state: "LOCKED",
        bookingRequestId: lock.bookingRequestId,
        expiresAt: lock.expiresAt.toISOString(),
        passengerName: lock.bookingRequest.passenger?.name ?? null,
      });
      continue;
    }
    seats.push({ seatIndex: i, state: "AVAILABLE" });
  }

  return { ride, seats };
}

async function lockSeatForBooking(bookingRequestId, seatIndex) {
  const booking = await prisma.bookingRequest.findUnique({
    where: { id: bookingRequestId },
    include: { ride: true, confirmedSeat: true, seatLock: true },
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

  if (booking.ride.status !== "PLANNED") {
    const err = new Error("RIDE_NOT_PLANNED");
    err.code = "RIDE_NOT_PLANNED";
    throw err;
  }

  if (booking.confirmedSeat) {
    const err = new Error("SEAT_ALREADY_CONFIRMED");
    err.code = "SEAT_ALREADY_CONFIRMED";
    throw err;
  }

  if (!Number.isInteger(seatIndex) || seatIndex < 1 || seatIndex > booking.ride.seats) {
    const err = new Error("INVALID_SEAT");
    err.code = "INVALID_SEAT";
    throw err;
  }

  await deleteExpiredLocks(booking.rideId);

  const expiresAt = new Date(Date.now() + DEFAULT_LOCK_MS);

  try {
    await prisma.$transaction(async (tx) => {
      await tx.seatLock.deleteMany({ where: { bookingRequestId } });

      const blocking = await tx.seatLock.findFirst({
        where: {
          rideId: booking.rideId,
          seatIndex,
          expiresAt: { gt: new Date() },
        },
      });

      if (blocking) {
        const err = new Error("SEAT_HELD_BY_OTHER");
        err.code = "SEAT_HELD_BY_OTHER";
        throw err;
      }

      const booked = await tx.confirmedSeat.findFirst({
        where: { rideId: booking.rideId, seatIndex },
      });
      if (booked) {
        const err = new Error("SEAT_ALREADY_BOOKED");
        err.code = "SEAT_ALREADY_BOOKED";
        throw err;
      }

      await tx.seatLock.create({
        data: {
          rideId: booking.rideId,
          seatIndex,
          bookingRequestId,
          expiresAt,
        },
      });
    });
  } catch (e) {
    if (e.code === "SEAT_HELD_BY_OTHER" || e.code === "SEAT_ALREADY_BOOKED") throw e;
    if (e.code === "P2002") {
      const err = new Error("SEAT_HELD_BY_OTHER");
      err.code = "SEAT_HELD_BY_OTHER";
      throw err;
    }
    throw e;
  }

  return prisma.seatLock.findUnique({
    where: { bookingRequestId },
    include: { ride: true },
  });
}

async function releaseSeatLock(bookingRequestId) {
  const booking = await prisma.bookingRequest.findUnique({
    where: { id: bookingRequestId },
    include: { seatLock: true },
  });
  if (!booking?.seatLock) {
    return { released: false };
  }
  await prisma.seatLock.delete({ where: { bookingRequestId } });
  return { released: true };
}

async function confirmSeatForBooking(bookingRequestId, payload) {
  const {
    pickupLat,
    pickupLng,
    dropoffLat,
    dropoffLng,
    pickupLabel,
    dropoffLabel,
    seatIndex: seatFromPayload,
  } = payload;

  const booking = await prisma.bookingRequest.findUnique({
    where: { id: bookingRequestId },
    include: { ride: true, confirmedSeat: true, seatLock: true },
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

  if (booking.ride.status !== "PLANNED") {
    const err = new Error("RIDE_NOT_PLANNED");
    err.code = "RIDE_NOT_PLANNED";
    throw err;
  }

  if (booking.confirmedSeat) {
    const full = await prisma.bookingRequest.findUnique({
      where: { id: bookingRequestId },
      include: {
        passenger: true,
        ride: true,
        confirmedSeat: true,
        payment: true,
        seatLock: true,
      },
    });
    return { already: true, confirmedSeat: booking.confirmedSeat, booking: full };
  }

  await deleteExpiredLocks(booking.rideId);

  const lock = await prisma.seatLock.findUnique({
    where: { bookingRequestId },
  });

  if (!lock || lock.expiresAt <= new Date()) {
    const err = new Error("NO_ACTIVE_LOCK");
    err.code = "NO_ACTIVE_LOCK";
    throw err;
  }

  if (seatFromPayload != null && Number(seatFromPayload) !== lock.seatIndex) {
    const err = new Error("SEAT_MISMATCH");
    err.code = "SEAT_MISMATCH";
    throw err;
  }

  const taken = await prisma.confirmedSeat.findFirst({
    where: { rideId: booking.rideId, seatIndex: lock.seatIndex },
  });
  if (taken) {
    const err = new Error("SEAT_RACE_LOST");
    err.code = "SEAT_RACE_LOST";
    throw err;
  }

  const latOk =
    pickupLat != null &&
    pickupLng != null &&
    dropoffLat != null &&
    dropoffLng != null &&
    !Number.isNaN(Number(pickupLat)) &&
    !Number.isNaN(Number(pickupLng)) &&
    !Number.isNaN(Number(dropoffLat)) &&
    !Number.isNaN(Number(dropoffLng));

  if (!latOk) {
    const err = new Error("PICKUP_DROPOFF_REQUIRED");
    err.code = "PICKUP_DROPOFF_REQUIRED";
    throw err;
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const fresh = await tx.seatLock.findUnique({ where: { bookingRequestId } });
      if (!fresh || fresh.seatIndex !== lock.seatIndex || fresh.expiresAt <= new Date()) {
        const e = new Error("NO_ACTIVE_LOCK");
        e.code = "NO_ACTIVE_LOCK";
        throw e;
      }

      const confirmed = await tx.confirmedSeat.create({
        data: {
          rideId: booking.rideId,
          seatIndex: lock.seatIndex,
          bookingRequestId,
        },
      });

      await tx.seatLock.delete({ where: { bookingRequestId } });

      const updatedBooking = await tx.bookingRequest.update({
        where: { id: bookingRequestId },
        data: {
          pickupLat: Number(pickupLat),
          pickupLng: Number(pickupLng),
          dropoffLat: Number(dropoffLat),
          dropoffLng: Number(dropoffLng),
          pickupLabel: pickupLabel ?? null,
          dropoffLabel: dropoffLabel ?? null,
        },
        include: { passenger: true, ride: true, confirmedSeat: true },
      });

      return { confirmedSeat: confirmed, booking: updatedBooking };
    });

    return { already: false, ...result };
  } catch (e) {
    if (e.code === "P2002") {
      const err = new Error("SEAT_RACE_LOST");
      err.code = "SEAT_RACE_LOST";
      throw err;
    }
    throw e;
  }
}

module.exports = {
  getSeatMap,
  lockSeatForBooking,
  releaseSeatLock,
  confirmSeatForBooking,
  deleteExpiredLocks,
  DEFAULT_LOCK_MS,
};

const prisma = require("../lib/prisma");

const BASE_FARE_CENTS = Number(process.env.FARE_BASE_CENTS || 5000);
const PER_KM_CENTS = Number(process.env.FARE_PER_KM_CENTS || 1800);
const MIN_FARE_CENTS = Number(process.env.FARE_MIN_CENTS || 2000);
const PEAK_MULTIPLIER = Number(process.env.FARE_PEAK_MULTIPLIER || 1.25);
const DEFAULT_SINUOSITY = Number(process.env.FARE_DEFAULT_SINUOSITY || 1.25);

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function crowRideKm(ride) {
  if (
    ride.originLat == null ||
    ride.originLng == null ||
    ride.destinationLat == null ||
    ride.destinationLng == null
  ) {
    return null;
  }
  return haversineKm(ride.originLat, ride.originLng, ride.destinationLat, ride.destinationLng);
}

function sinuosityForRide(ride) {
  const crow = crowRideKm(ride);
  if (!crow || crow < 0.5 || !ride.routeDistanceKm || ride.routeDistanceKm <= 0) {
    return DEFAULT_SINUOSITY;
  }
  const s = ride.routeDistanceKm / crow;
  return Math.min(Math.max(s, 1), 2.2);
}

function isPeakHour(departureTime) {
  const d = new Date(departureTime);
  const h = d.getHours();
  return (h >= 7 && h < 10) || (h >= 17 && h < 21);
}

async function countAcceptedBookings(rideId, excludeBookingRequestId) {
  return prisma.bookingRequest.count({
    where: {
      rideId,
      status: "ACCEPTED",
      ...(excludeBookingRequestId ? { id: { not: excludeBookingRequestId } } : {}),
    },
  });
}

function occupancyMultiplier(acceptedPassengerCount) {
  const n = Math.max(1, acceptedPassengerCount);
  return 1 / (1 + 0.06 * (n - 1));
}

function segmentKmForPassenger(ride, pickupLat, pickupLng, dropoffLat, dropoffLng) {
  const crowPassenger = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  const sinu = sinuosityForRide(ride);
  let segmentKm = crowPassenger * sinu;

  const rideCrow = crowRideKm(ride);
  if (ride.routeDistanceKm && rideCrow && rideCrow > 0.5) {
    const shareOfRoute = Math.min(1, crowPassenger / rideCrow);
    const alt = shareOfRoute * ride.routeDistanceKm;
    segmentKm = Math.max(segmentKm, alt * 0.85);
  }

  return Math.max(0.5, segmentKm);
}

async function computeFareQuote({
  ride,
  pickupLat,
  pickupLng,
  dropoffLat,
  dropoffLng,
  bookingRequestId,
}) {
  const segmentKm = segmentKmForPassenger(ride, pickupLat, pickupLng, dropoffLat, dropoffLng);
  const others = await countAcceptedBookings(ride.id, bookingRequestId || undefined);
  const occupancy = occupancyMultiplier(others + 1);
  const peak = isPeakHour(ride.departureTime) ? PEAK_MULTIPLIER : 1;
  const baseComponent = BASE_FARE_CENTS;
  const distanceComponent = Math.round(PER_KM_CENTS * segmentKm);
  let subtotal = Math.round((baseComponent + distanceComponent) * occupancy * peak);
  subtotal = Math.max(subtotal, MIN_FARE_CENTS);

  const rideStatus = ride.status;

  return {
    currency: "BDT",
    totalCents: subtotal,
    segmentKm: Math.round(segmentKm * 1000) / 1000,
    breakdown: {
      baseFareCents: baseComponent,
      distanceKm: Math.round(segmentKm * 1000) / 1000,
      distanceFareCents: distanceComponent,
      occupancyMultiplier: Math.round(occupancy * 1000) / 1000,
      peakMultiplier: peak,
      rideStatus,
      acceptedPassengersForOccupancy: others + 1,
      sinuosity: Math.round(sinuosityForRide(ride) * 1000) / 1000,
      minimumApplied: subtotal === MIN_FARE_CENTS && subtotal < baseComponent + distanceComponent,
    },
  };
}

module.exports = {
  haversineKm,
  computeFareQuote,
  isPeakHour,
};

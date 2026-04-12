const prisma = require("../lib/prisma");
const { computeFareQuote } = require("../services/fareService");

function mapCoords(body) {
  const rideId = Number(body.rideId);
  const pickupLat = body.pickupLat != null ? Number(body.pickupLat) : null;
  const pickupLng = body.pickupLng != null ? Number(body.pickupLng) : null;
  const dropoffLat = body.dropoffLat != null ? Number(body.dropoffLat) : null;
  const dropoffLng = body.dropoffLng != null ? Number(body.dropoffLng) : null;
  const bookingRequestId =
    body.bookingRequestId != null ? Number(body.bookingRequestId) : undefined;

  return { rideId, pickupLat, pickupLng, dropoffLat, dropoffLng, bookingRequestId };
}

exports.previewFare = async (req, res) => {
  try {
    const { rideId, pickupLat, pickupLng, dropoffLat, dropoffLng, bookingRequestId } = mapCoords(
      req.body,
    );

    if (!rideId || [pickupLat, pickupLng, dropoffLat, dropoffLng].some((v) => v == null || Number.isNaN(v))) {
      return res.status(400).json({
        message: "rideId, pickupLat, pickupLng, dropoffLat, and dropoffLng are required.",
      });
    }

    const ride = await prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    if (bookingRequestId) {
      const br = await prisma.bookingRequest.findUnique({ where: { id: bookingRequestId } });
      if (!br || br.rideId !== rideId) {
        return res.status(400).json({ message: "bookingRequestId does not match this ride." });
      }
    }

    const quote = await computeFareQuote({
      ride,
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      bookingRequestId,
    });

    res.json({
      rideId,
      pickupLabel: req.body.pickupLabel ?? null,
      dropoffLabel: req.body.dropoffLabel ?? null,
      ...quote,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

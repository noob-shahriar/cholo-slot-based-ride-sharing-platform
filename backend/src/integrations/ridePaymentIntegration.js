const { refundPaymentsForRide } = require("../services/paymentService");

async function onRideCancelled(rideId) {
  try {
    const result = await refundPaymentsForRide(rideId);
    if (result.refundedCount > 0) {
      console.info(`Ride ${rideId} cancelled: refunded ${result.refundedCount} payment(s).`);
    }
  } catch (e) {
    console.error(`Refund hook failed for ride ${rideId}:`, e.message);
  }
}

module.exports = { onRideCancelled };

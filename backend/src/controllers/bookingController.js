const prisma = require("../lib/prisma");

exports.createBookingRequest = async (req, res) => {
  try {
    const { rideId, passengerId } = req.body;

    if (!rideId || !passengerId) {
      return res.status(400).json({ message: "rideId and passengerId are required." });
    }

    const ride = await prisma.ride.findUnique({
      where: { id: Number(rideId) },
    });

    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    const passenger = await prisma.user.findUnique({
      where: { id: Number(passengerId) },
    });

    if (!passenger) {
      return res.status(404).json({ message: "Passenger not found" });
    }

    const existingRequest = await prisma.bookingRequest.findUnique({
      where: {
        rideId_passengerId: {
          rideId: Number(rideId),
          passengerId: Number(passengerId),
        },
      },
    });

    if (existingRequest) {
      return res.status(400).json({ message: "Booking request already exists for this passenger and ride." });
    }

    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        rideId: Number(rideId),
        passengerId: Number(passengerId),
        status: "PENDING",
      },
      include: {
        passenger: true,
        ride: true,
      },
    });

    res.status(201).json({
      message: "Booking request created successfully",
      bookingRequest,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getBookingRequestsByRide = async (req, res) => {
  try {
    const rideId = Number(req.params.rideId);

    const bookingRequests = await prisma.bookingRequest.findMany({
      where: { rideId },
      include: {
        passenger: true,
      },
      orderBy: {
        createdAt: "desc",
      },
    });

    res.json(bookingRequests);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.acceptBookingRequest = async (req, res) => {
  try {
    const id = Number(req.params.id);

    const existingRequest = await prisma.bookingRequest.findUnique({
      where: { id },
      include: { ride: true },
    });

    if (!existingRequest) {
      return res.status(404).json({ message: "Booking request not found" });
    }

    if (existingRequest.status !== "PENDING") {
      return res.status(400).json({ message: "Only pending requests can be accepted." });
    }

    const acceptedCount = await prisma.bookingRequest.count({
      where: {
        rideId: existingRequest.rideId,
        status: "ACCEPTED",
      },
    });

    if (acceptedCount >= existingRequest.ride.seats) {
      return res.status(400).json({ message: "No seats available for this ride." });
    }

    const updatedRequest = await prisma.bookingRequest.update({
      where: { id },
      data: { status: "ACCEPTED" },
      include: {
        passenger: true,
        ride: true,
      },
    });

    res.json({
      message: "Booking request accepted successfully",
      bookingRequest: updatedRequest,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getBookingById = async (req, res) => {
  try {
    const id = Number(req.params.id);

    const bookingRequest = await prisma.bookingRequest.findUnique({
      where: { id },
      include: {
        passenger: true,
        ride: true,
        seatLock: true,
        confirmedSeat: true,
        payment: true,
      },
    });

    if (!bookingRequest) {
      return res.status(404).json({ message: "Booking not found" });
    }

    res.json(bookingRequest);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.rejectBookingRequest = async (req, res) => {
  try {
    const id = Number(req.params.id);

    const existingRequest = await prisma.bookingRequest.findUnique({
      where: { id },
    });

    if (!existingRequest) {
      return res.status(404).json({ message: "Booking request not found" });
    }

    if (existingRequest.status !== "PENDING") {
      return res.status(400).json({ message: "Only pending requests can be rejected." });
    }

    const updatedRequest = await prisma.bookingRequest.update({
      where: { id },
      data: { status: "REJECTED" },
      include: {
        passenger: true,
        ride: true,
      },
    });

    res.json({
      message: "Booking request rejected successfully",
      bookingRequest: updatedRequest,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
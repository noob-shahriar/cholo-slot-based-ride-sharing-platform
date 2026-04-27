const prisma = require("../lib/prisma");

exports.getUserProfile = async (req, res) => {
  try {
    const id = Number(req.params.id);

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        emergencyContact: true,
        createdAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateEmergencyContact = async (req, res) => {
  try {
    const id = Number(req.params.id);
    const { emergencyContact } = req.body;

    const user = await prisma.user.findUnique({
      where: { id },
    });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const updatedUser = await prisma.user.update({
      where: { id },
      data: {
        emergencyContact,
      },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        emergencyContact: true,
      },
    });

    res.json({
      message: "Emergency contact updated successfully",
      user: updatedUser,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

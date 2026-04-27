const express = require("express");
const path = require("path");
const verificationController = require("../controllers/verificationController");

const router = express.Router();

// Serve uploaded verification documents
router.get("/documents/:filename", (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(__dirname, "../../uploads/verification", filename);

  res.sendFile(filePath, (err) => {
    if (err) {
      res.status(404).json({ message: "Document not found" });
    }
  });
});

// Submit a verification request
router.post("/submit", verificationController.submitVerification);

// Get all verification requests (for admin)
router.get("/all", verificationController.getAllVerificationRequests);

// Get verification request by ID
router.get("/:id", verificationController.getVerificationRequestById);

// Approve verification request (for admin)
router.put("/:id/approve", verificationController.approveVerification);

// Reject verification request (for admin)
router.put("/:id/reject", verificationController.rejectVerification);

// Get verification request status for a user
router.get("/user/:userId", verificationController.getUserVerificationStatus);

module.exports = router;

const express = require("express");
const router = express.Router();
const userController = require("../controllers/userController");

router.get("/:id", userController.getUserProfile);
router.put("/:id/emergency-contact", userController.updateEmergencyContact);

module.exports = router;

const express = require("express");
const router = express.Router();
const paymentController = require("../controllers/paymentController");

router.post("/mock", paymentController.mockPay);

module.exports = router;

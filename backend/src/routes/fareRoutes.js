const express = require("express");
const router = express.Router();
const fareController = require("../controllers/fareController");

router.post("/preview", fareController.previewFare);

module.exports = router;

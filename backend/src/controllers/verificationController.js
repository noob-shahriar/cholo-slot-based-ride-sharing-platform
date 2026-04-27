const { PrismaClient } = require("@prisma/client");
const multer = require("multer");
const path = require("path");
const fs = require("fs-extra");
const sharp = require("sharp");
const axios = require("axios");
const FormData = require("form-data");

const prisma = new PrismaClient();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const uploadDir = path.join(__dirname, "../../uploads/verification");
    await fs.ensureDir(uploadDir);
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files (jpg, jpeg, png) are allowed!"));
    }
  },
});

// OCR.space API function
async function extractTextFromImage(imagePath) {
  try {
    const apiKey = process.env.OCR_SPACE_API_KEY;
    if (!apiKey) {
      throw new Error("OCR_SPACE_API_KEY not configured");
    }

    const imageBuffer = await fs.readFile(imagePath);
    const base64Image = imageBuffer.toString('base64');
    const defaultLanguage = process.env.OCR_SPACE_LANGUAGE || 'eng';

    const createForm = (language) => {
      const form = new FormData();
      form.append('apikey', apiKey);
      form.append('base64Image', `data:image/jpeg;base64,${base64Image}`);
      form.append('language', language);
      form.append('isOverlayRequired', 'false');
      form.append('detectOrientation', 'true');
      form.append('scale', 'true');
      return form;
    };

    const primaryForm = createForm(defaultLanguage);
    const primaryHeaders = primaryForm.getHeaders();
    const primaryResponse = await axios.post('https://api.ocr.space/parse/image', primaryForm, {
      headers: primaryHeaders,
      timeout: 30000,
    });

    if (primaryResponse.data && primaryResponse.data.ParsedResults && primaryResponse.data.ParsedResults.length > 0) {
      const parsedText = primaryResponse.data.ParsedResults[0].ParsedText || "";
      if (parsedText.trim().length > 0) {
        return parsedText;
      }
    }

    if (defaultLanguage !== 'ben') {
      const fallbackForm = createForm('ben');
      const fallbackHeaders = fallbackForm.getHeaders();
      const fallbackResponse = await axios.post('https://api.ocr.space/parse/image', fallbackForm, {
        headers: fallbackHeaders,
        timeout: 30000,
      });

      if (fallbackResponse.data && fallbackResponse.data.ParsedResults && fallbackResponse.data.ParsedResults.length > 0) {
        return fallbackResponse.data.ParsedResults[0].ParsedText || "";
      }
    }

    return "";
  } catch (error) {
    console.error("OCR.space Error:", error.response?.data || error.message);
    return "";
  }
}

// Parse extracted text to get structured data
function parseDocumentData(text, documentType) {
  const data = {
    rawText: text,
    extractedFields: {},
  };

  if (documentType === "NID") {
    // Extract NID specific information, including Bangla and English labels seen on Bangladesh NID cards
    const nidRegex = /(?:NID|N\.I\.D|ID\s*NO|National\s*ID|জাতীয়\s*পরিচয়পত্র\s*নং|জাতীয়\s*পরিচয়পত্র\s*নং)\s*[:\-]?\s*([\d\s]{8,17})/i;
    const nameRegex = /(?:Name|নাম)\s*[:\-]?\s*([^\n\r0-9]+)/i;
    const dobRegex = /(?:Date\s*of\s*Birth|DOB|Birth|জন্ম\s*তারিখ|জন্ম)\s*[:\-]?\s*([\d]{1,2}\s*[A-Za-z]{3,9}\s*[\d]{2,4}|[\d]{1,2}[-\/]\d{1,2}[-\/]\d{2,4}|[\d]{1,2}\s+[A-Z][a-z]{2,8}\s+[\d]{4})/i;
    const addressRegex = /(?:Address|ঠিকানা)\s*[:\-]?\s*([^\n\r]+)/i;
    const fatherRegex = /(?:Father|পিতা)\s*[:\-]?\s*([^\n\r0-9]+)/i;
    const motherRegex = /(?:Mother|মাতা)\s*[:\-]?\s*([^\n\r0-9]+)/i;

    let nidMatch = text.match(nidRegex);
    let nidNumber = null;
    
    // If labeled NID not found, try to find any 10-17 digit sequence
    if (nidMatch) {
      nidNumber = nidMatch[1].replace(/\s+/g, '').trim();
    } else {
      const digitOnlyRegex = /(\d{10,17})/;
      const digitMatch = text.match(digitOnlyRegex);
      if (digitMatch) {
        nidNumber = digitMatch[1];
      }
    }

    const nameMatch = text.match(nameRegex);
    const dobMatch = text.match(dobRegex);
    const addressMatch = text.match(addressRegex);
    const fatherMatch = text.match(fatherRegex);
    const motherMatch = text.match(motherRegex);


    data.extractedFields = {
      nidNumber: nidNumber || null,
      fullName: nameMatch ? nameMatch[1].trim().replace(/\s+/g, ' ').trim() : null,
      dateOfBirth: dobMatch ? dobMatch[1].trim() : null,
      address: addressMatch ? addressMatch[1].trim() : null,
      fatherName: fatherMatch ? fatherMatch[1].trim().replace(/\s+/g, ' ').trim() : null,
      motherName: motherMatch ? motherMatch[1].trim().replace(/\s+/g, ' ').trim() : null,
    };
  } else if (documentType === "DRIVERS_LICENSE") {
    // Extract Driver's License specific information
    const licenseRegex = /License\s*No\.?\s*[:\-]?\s*([A-Z\d\-]+)/i;
    const nameRegex = /Name\s*[:\-]?\s*([^\n\r]+)/i;
    const dobRegex = /DOB\s*[:\-]?\s*([\d\/\-]+)/i;
    const expiryRegex = /Expiry\s*[:\-]?\s*([\d\/\-]+)/i;

    const licenseMatch = text.match(licenseRegex);
    const nameMatch = text.match(nameRegex);
    const dobMatch = text.match(dobRegex);
    const expiryMatch = text.match(expiryRegex);

    data.extractedFields = {
      licenseNumber: licenseMatch ? licenseMatch[1].trim() : null,
      fullName: nameMatch ? nameMatch[1].trim() : null,
      dateOfBirth: dobMatch ? dobMatch[1].trim() : null,
      expiryDate: expiryMatch ? expiryMatch[1].trim() : null,
    };
  }

  return data;
}

// Submit a verification request with file upload
exports.submitVerification = [
  upload.single("document"),
  async (req, res) => {
    try {
      if (!req.body) {
        console.error("Missing req.body on multipart request", {
          headers: req.headers,
          route: req.originalUrl,
        });
      }

      const { userId, documentType } = req.body || {};

      if (!userId || !documentType) {
        return res.status(400).json({
          message: "Missing required fields: userId, documentType",
        });
      }

      if (!req.file) {
        return res.status(400).json({
          message: "Document file is required",
        });
      }

      // Check if user exists
      const user = await prisma.user.findUnique({
        where: { id: parseInt(userId) },
      });

      if (!user) {
        return res.status(404).json({ message: "User not found" });
      }

      // Check if user already has a pending verification request
      const existingRequest = await prisma.verificationRequest.findFirst({
        where: {
          userId: parseInt(userId),
          status: "PENDING",
        },
      });

      if (existingRequest) {
        // Clean up uploaded file
        await fs.remove(req.file.path);
        return res.status(400).json({
          message: "You already have a pending verification request",
        });
      }

      // Process the uploaded image
      const imagePath = req.file.path;

      // Extract text using Google Cloud Vision
      console.log("Starting OCR processing...");
      const extractedText = await extractTextFromImage(imagePath);
      console.log("OCR completed, parsing data...");

      // Parse the extracted text
      const parsedData = parseDocumentData(extractedText, documentType);

      // Create verification request
      const verificationRequest = await prisma.verificationRequest.create({
        data: {
          userId: parseInt(userId),
          documentType,
          documentPath: req.file.filename,
          extractedData: parsedData,
          status: "PENDING",
        },
        include: {
          user: {
            select: {
              id: true,
              name: true,
              email: true,
            },
          },
        },
      });

      res.status(201).json({
        message: "Verification request submitted successfully",
        data: verificationRequest,
      });
    } catch (error) {
      console.error("Error submitting verification request:", error);

      // Clean up uploaded file if it exists
      if (req.file && req.file.path) {
        await fs.remove(req.file.path).catch(console.error);
      }

      res.status(500).json({ message: "Internal server error" });
    }
  },
];

// Get all verification requests (for admin)
exports.getAllVerificationRequests = async (req, res) => {
  try {
    const { status } = req.query;

    const where = {};
    if (status) {
      where.status = status.toUpperCase();
    }

    const verificationRequests = await prisma.verificationRequest.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            role: true,
          },
        },
      },
      orderBy: {
        createdAt: "desc",
      },
    });

    res.status(200).json({
      message: "Verification requests retrieved successfully",
      data: verificationRequests,
    });
  } catch (error) {
    console.error("Error retrieving verification requests:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get verification request by ID
exports.getVerificationRequestById = async (req, res) => {
  try {
    const { id } = req.params;

    const verificationRequest = await prisma.verificationRequest.findUnique({
      where: { id: parseInt(id) },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            role: true,
          },
        },
      },
    });

    if (!verificationRequest) {
      return res
        .status(404)
        .json({ message: "Verification request not found" });
    }

    res.status(200).json({
      message: "Verification request retrieved successfully",
      data: verificationRequest,
    });
  } catch (error) {
    console.error("Error retrieving verification request:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Approve verification request (for admin)
exports.approveVerification = async (req, res) => {
  try {
    const { id } = req.params;

    const verificationRequest = await prisma.verificationRequest.findUnique({
      where: { id: parseInt(id) },
    });

    if (!verificationRequest) {
      return res
        .status(404)
        .json({ message: "Verification request not found" });
    }

    const updatedRequest = await prisma.verificationRequest.update({
      where: { id: parseInt(id) },
      data: {
        status: "APPROVED",
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    res.status(200).json({
      message: "Verification request approved successfully",
      data: updatedRequest,
    });
  } catch (error) {
    console.error("Error approving verification request:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Reject verification request (for admin)
exports.rejectVerification = async (req, res) => {
  try {
    const { id } = req.params;
    const { rejectionReason } = req.body;

    const verificationRequest = await prisma.verificationRequest.findUnique({
      where: { id: parseInt(id) },
    });

    if (!verificationRequest) {
      return res
        .status(404)
        .json({ message: "Verification request not found" });
    }

    const updatedRequest = await prisma.verificationRequest.update({
      where: { id: parseInt(id) },
      data: {
        status: "REJECTED",
        rejectionReason: rejectionReason || null,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    res.status(200).json({
      message: "Verification request rejected successfully",
      data: updatedRequest,
    });
  } catch (error) {
    console.error("Error rejecting verification request:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get verification request status for a user
exports.getUserVerificationStatus = async (req, res) => {
  try {
    const { userId } = req.params;

    const latestRequest = await prisma.verificationRequest.findFirst({
      where: { userId: parseInt(userId) },
      orderBy: {
        createdAt: "desc",
      },
    });

    res.status(200).json({
      message: "User verification status retrieved successfully",
      data: latestRequest,
    });
  } catch (error) {
    console.error("Error retrieving user verification status:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

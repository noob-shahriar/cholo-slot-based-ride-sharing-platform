-- CreateEnum
CREATE TYPE "BookingPaymentStatus" AS ENUM ('NONE', 'PAID', 'REFUNDED');

-- CreateEnum
CREATE TYPE "PaymentRecordStatus" AS ENUM ('COMPLETED', 'REFUNDED', 'FAILED');

-- AlterTable
ALTER TABLE "BookingRequest" ADD COLUMN     "pickupLat" DOUBLE PRECISION,
ADD COLUMN     "pickupLng" DOUBLE PRECISION,
ADD COLUMN     "pickupLabel" TEXT,
ADD COLUMN     "dropoffLat" DOUBLE PRECISION,
ADD COLUMN     "dropoffLng" DOUBLE PRECISION,
ADD COLUMN     "dropoffLabel" TEXT,
ADD COLUMN     "fareAmountCents" INTEGER,
ADD COLUMN     "fareBreakdown" JSONB,
ADD COLUMN     "paymentStatus" "BookingPaymentStatus" NOT NULL DEFAULT 'NONE';

-- CreateTable
CREATE TABLE "SeatLock" (
    "id" SERIAL NOT NULL,
    "rideId" INTEGER NOT NULL,
    "seatIndex" INTEGER NOT NULL,
    "bookingRequestId" INTEGER NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SeatLock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConfirmedSeat" (
    "id" SERIAL NOT NULL,
    "rideId" INTEGER NOT NULL,
    "seatIndex" INTEGER NOT NULL,
    "bookingRequestId" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ConfirmedSeat_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Payment" (
    "id" SERIAL NOT NULL,
    "bookingRequestId" INTEGER NOT NULL,
    "amountCents" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'BDT',
    "status" "PaymentRecordStatus" NOT NULL DEFAULT 'COMPLETED',
    "mockMethod" TEXT,
    "fareBreakdown" JSONB,
    "idempotencyKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SeatLock_bookingRequestId_key" ON "SeatLock"("bookingRequestId");

-- CreateIndex
CREATE UNIQUE INDEX "SeatLock_rideId_seatIndex_key" ON "SeatLock"("rideId", "seatIndex");

-- CreateIndex
CREATE UNIQUE INDEX "ConfirmedSeat_bookingRequestId_key" ON "ConfirmedSeat"("bookingRequestId");

-- CreateIndex
CREATE UNIQUE INDEX "ConfirmedSeat_rideId_seatIndex_key" ON "ConfirmedSeat"("rideId", "seatIndex");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_bookingRequestId_key" ON "Payment"("bookingRequestId");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_idempotencyKey_key" ON "Payment"("idempotencyKey");

-- AddForeignKey
ALTER TABLE "SeatLock" ADD CONSTRAINT "SeatLock_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "Ride"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeatLock" ADD CONSTRAINT "SeatLock_bookingRequestId_fkey" FOREIGN KEY ("bookingRequestId") REFERENCES "BookingRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConfirmedSeat" ADD CONSTRAINT "ConfirmedSeat_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "Ride"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConfirmedSeat" ADD CONSTRAINT "ConfirmedSeat_bookingRequestId_fkey" FOREIGN KEY ("bookingRequestId") REFERENCES "BookingRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_bookingRequestId_fkey" FOREIGN KEY ("bookingRequestId") REFERENCES "BookingRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

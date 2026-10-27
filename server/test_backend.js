const http = require('http');
const crypto = require('crypto');

// Configure test environment secrets before requiring server
process.env.NODE_ENV = 'test';
process.env.RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || 'rzp_test_MOCK_SUITE_KEY';
process.env.RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'test_secret_for_suite_2026';
process.env.RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || 'test_webhook_secret_for_suite_2026';

const app = require('./index');

const SECRET_KEY = process.env.RAZORPAY_KEY_SECRET;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

let BASE_URL = '';

function makeRequest(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : {};
          resolve({ statusCode: res.statusCode, body: parsed, rawData: data });
        } catch (e) {
          resolve({ statusCode: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      const payload = typeof body === 'string' ? body : JSON.stringify(body);
      req.write(payload);
    }
    req.end();
  });
}

async function runBackendTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING NODE BACKEND INTEGRATION TEST SUITE');
  console.log('   Security, Webhooks, Razorpay & Overlap Validation');
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName) {
    if (condition) {
      console.log(` ✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(` ❌ FAIL: ${testName}`);
      failed++;
    }
  }

  // Start self-contained HTTP server on an ephemeral port
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => {
      const port = s.address().port;
      BASE_URL = `http://127.0.0.1:${port}`;
      console.log(`[TEST RUNNER] ephemeral server listening at ${BASE_URL}\n`);
      resolve(s);
    });
  });

  try {
    const today = new Date().toISOString().split('T')[0];

    // Test 1: Health Check
    const health = await makeRequest('GET', '/');
    assert(health.statusCode === 200 && health.body.status === 'online', '1. Server Health Endpoint (GET /)');

    // Test 2: Selecting a 10:30 AM start time for 30 minutes
    const prep30Min = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_test_30m',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1', // Rate: 60000 paise/hr (₹600)
      sportId: 'Pickleball',
      bookingDate: today,
      startTime: '10:30 AM',
      endTime: '11:00 AM',
      durationMinutes: 30,
    });
    assert(
      prep30Min.statusCode === 200 &&
      prep30Min.body.success &&
      prep30Min.body.amountPaise === 30000,
      '2. 30-minute Booking at 10:30 AM with correct half-hour price (30,000 paise / ₹300)'
    );

    // Test 3: Booking for 1 hour
    const prep1Hr = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_test_1hr',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1',
      sportId: 'Pickleball',
      bookingDate: today,
      startTime: '02:00 PM',
      endTime: '03:00 PM',
      durationMinutes: 60,
    });
    assert(
      prep1Hr.statusCode === 200 &&
      prep1Hr.body.success &&
      prep1Hr.body.amountPaise === 60000,
      '3. 1-Hour Booking (2:00 PM–3:00 PM) with standard rate: 60,000 paise (₹600)'
    );

    // Test 4: Booking for 2 hours (120 minutes)
    const prep2Hr = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_test_2hr',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1', // Rate: 80000 paise/hr (₹800)
      sportId: 'Box Cricket',
      bookingDate: today,
      startTime: '10:30 AM',
      endTime: '12:30 PM',
      durationMinutes: 120,
    });
    assert(
      prep2Hr.statusCode === 200 &&
      prep2Hr.body.success &&
      prep2Hr.body.amountPaise === 160000,
      '4. 2-Hour Consecutive Booking (10:30 AM–12:30 PM) with trusted server price: 160,000 paise (₹1,600)'
    );
    const booking2HrId = prep2Hr.body.bookingId;
    const order2HrId = prep2Hr.body.razorpayOrderId;

    // Test 5: Booking ending exactly at venue closing time (11:00 PM for Sidsar Arena)
    const prepClosingExact = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_test_close_exact',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      sportId: 'Box Cricket',
      bookingDate: today,
      startTime: '10:00 PM',
      endTime: '11:00 PM',
      durationMinutes: 60,
    });
    assert(
      prepClosingExact.statusCode === 200 && prepClosingExact.body.success,
      '5. Booking ending exactly at venue closing time (10:00 PM - 11:00 PM) is allowed'
    );

    // Test 6: Booking extending beyond venue closing time (10:30 PM for 1 hour -> 11:30 PM)
    const prepExceedClose = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_test_exceed_close',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      sportId: 'Box Cricket',
      bookingDate: today,
      startTime: '10:30 PM',
      endTime: '11:30 PM',
      durationMinutes: 60,
    });
    assert(
      prepExceedClose.statusCode === 400 && !prepExceedClose.body.success,
      '6. Reject booking extending beyond venue closing time (HTTP 400)'
    );

    // Test 7: Overlapping active hold rejection
    const holdOverlap = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_other_intruder',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      sportId: 'Box Cricket',
      bookingDate: today,
      startTime: '11:00 AM',
      endTime: '12:00 PM',
      durationMinutes: 60,
    });
    assert(
      holdOverlap.statusCode === 409 && !holdOverlap.body.success,
      '7. Reject overlapping request inside active 10-minute hold (HTTP 409 Conflict)'
    );

    // Test 8: Security - Reject missing payment signature
    const missingSig = await makeRequest('POST', '/api/payments/verify', {
      bookingId: booking2HrId,
      razorpayOrderId: order2HrId,
      razorpayPaymentId: 'pay_test_missing_sig',
    });
    assert(
      missingSig.statusCode === 400 && !missingSig.body.success,
      '8. Security: Reject payment verification request when signature is missing (HTTP 400)'
    );

    // Test 9: Security - Reject invalid payment signature
    const invalidSig = await makeRequest('POST', '/api/payments/verify', {
      bookingId: booking2HrId,
      razorpayOrderId: order2HrId,
      razorpayPaymentId: 'pay_test_invalid_sig',
      razorpaySignature: 'bad_signature_forged_hash_123',
    });
    assert(
      invalidSig.statusCode === 400 && !invalidSig.body.success,
      '9. Security: Reject invalid payment signature via constant-time verification (HTTP 400)'
    );

    // Test 10: Security - Reject mismatched order ID
    const mismatchedOrder = await makeRequest('POST', '/api/payments/verify', {
      bookingId: booking2HrId,
      razorpayOrderId: 'order_wrong_fake_9999',
      razorpayPaymentId: 'pay_test_mismatched',
      razorpaySignature: crypto.createHmac('sha256', SECRET_KEY).update('order_wrong_fake_9999|pay_test_mismatched').digest('hex'),
    });
    assert(
      mismatchedOrder.statusCode === 400 && !mismatchedOrder.body.success,
      '10. Security: Reject mismatched Razorpay order ID (HTTP 400)'
    );

    // Test 11: Confirm booking with authentic valid signature
    const payment2HrId = 'pay_2hr_' + crypto.randomBytes(6).toString('hex');
    const validSignature = crypto.createHmac('sha256', SECRET_KEY)
      .update(`${order2HrId}|${payment2HrId}`)
      .digest('hex');

    const verifyRes = await makeRequest('POST', '/api/payments/verify', {
      bookingId: booking2HrId,
      razorpayOrderId: order2HrId,
      razorpayPaymentId: payment2HrId,
      razorpaySignature: validSignature,
    });
    assert(
      verifyRes.statusCode === 200 &&
      verifyRes.body.success &&
      verifyRes.body.booking.bookingStatus === 'CONFIRMED',
      '11. Payment verification with valid signature confirms booking (HTTP 200)'
    );

    // Test 12: Idempotent repeat verification returns confirmed without error
    const repeatVerify = await makeRequest('POST', '/api/payments/verify', {
      bookingId: booking2HrId,
      razorpayOrderId: order2HrId,
      razorpayPaymentId: payment2HrId,
      razorpaySignature: validSignature,
    });
    assert(
      repeatVerify.statusCode === 200 && repeatVerify.body.success,
      '12. Idempotency: Repeated verification call with same payment ID safely succeeds (HTTP 200)'
    );

    // Test 13: Overlapping confirmed booking rejection across partial intervals
    const confirmedOverlap = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_overlap_boundary',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      sportId: 'Box Cricket',
      bookingDate: today,
      startTime: '12:00 PM',
      endTime: '01:00 PM',
      durationMinutes: 60,
    });
    assert(
      confirmedOverlap.statusCode === 409 && !confirmedOverlap.body.success,
      '13. Reject partial interval overlap with confirmed booking (HTTP 409)'
    );

    // Test 14: Two concurrent requests for overlapping intervals
    const concurrentA = makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_conc_A',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1',
      sportId: 'Pickleball',
      bookingDate: today,
      startTime: '04:00 PM',
      endTime: '06:00 PM',
      durationMinutes: 120,
    });
    const concurrentB = makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_conc_B',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1',
      sportId: 'Pickleball',
      bookingDate: today,
      startTime: '05:00 PM',
      endTime: '07:00 PM',
      durationMinutes: 120,
    });
    const [resA, resB] = await Promise.all([concurrentA, concurrentB]);
    const onePassedOneFailed =
      (resA.statusCode === 200 && resB.statusCode === 409) ||
      (resB.statusCode === 200 && resA.statusCode === 409);
    assert(
      onePassedOneFailed,
      '14. Concurrency: Exactly one concurrent overlapping request succeeds (200), other is rejected (409)'
    );

    // Test 15: Release Hold safely on payment cancellation
    const winningBookingId = resA.statusCode === 200 ? resA.body.bookingId : resB.body.bookingId;
    const releaseRes = await makeRequest('POST', `/api/bookings/${winningBookingId}/release-hold`);
    assert(
      releaseRes.statusCode === 200 && releaseRes.body.success,
      '15. Release hold endpoint frees held interval on cancellation'
    );

    // Test 16: Released interval is now available again
    const rebookRes = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_rebook_after_release',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1',
      sportId: 'Pickleball',
      bookingDate: today,
      startTime: '04:00 PM',
      endTime: '05:30 PM',
      durationMinutes: 90,
    });
    assert(
      rebookRes.statusCode === 200 && rebookRes.body.success,
      '16. Previously held interval is immediately re-bookable after release'
    );

    // Test 17: Webhook - Reject missing X-Razorpay-Signature header
    const webhookMissingSig = await makeRequest('POST', '/api/webhooks/razorpay', {
      event: 'payment.captured',
    });
    assert(
      webhookMissingSig.statusCode === 400 && webhookMissingSig.body.status === 'missing_signature',
      '17. Webhook Security: Reject webhook request missing X-Razorpay-Signature header (HTTP 400)'
    );

    // Test 18: Webhook - Reject invalid signature
    const webhookInvalidSig = await makeRequest('POST', '/api/webhooks/razorpay', {
      event: 'payment.captured',
    }, {
      'X-Razorpay-Signature': 'invalid_forged_webhook_signature',
    });
    assert(
      webhookInvalidSig.statusCode === 400 && webhookInvalidSig.body.status === 'invalid_signature',
      '18. Webhook Security: Reject webhook request with invalid signature (HTTP 400)'
    );

    // Test 19: Webhook - Valid signature processing payment.captured
    const webhookOrderId = rebookRes.body.razorpayOrderId;
    const webhookPaymentId = 'pay_hook_' + crypto.randomBytes(6).toString('hex');
    const webhookEventId = 'evt_' + crypto.randomBytes(6).toString('hex');
    const webhookPayload = JSON.stringify({
      id: webhookEventId,
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: webhookPaymentId,
            order_id: webhookOrderId,
            status: 'captured',
          }
        }
      }
    });

    const validWebhookSig = crypto.createHmac('sha256', WEBHOOK_SECRET)
      .update(webhookPayload)
      .digest('hex');

    const webhookRes = await makeRequest('POST', '/api/webhooks/razorpay', webhookPayload, {
      'X-Razorpay-Signature': validWebhookSig,
    });
    assert(
      webhookRes.statusCode === 200 && webhookRes.body.status === 'ok',
      '19. Webhook: Valid signed webhook confirms booking on payment.captured (HTTP 200)'
    );

    // Test 20: Webhook - Idempotent deduplication rejects repeated event ID
    const duplicateWebhookRes = await makeRequest('POST', '/api/webhooks/razorpay', webhookPayload, {
      'X-Razorpay-Signature': validWebhookSig,
    });
    assert(
      duplicateWebhookRes.statusCode === 200 && duplicateWebhookRes.body.status === 'already_processed',
      '20. Webhook Idempotency: Duplicate webhook event delivery is safely recognized as already_processed'
    );

    // Test 21: Cancellation & Refund Processing
    const cancelRes = await makeRequest('POST', `/api/bookings/${booking2HrId}/cancel`, {
      userId: 'user_test_2hr',
    });
    assert(
      cancelRes.statusCode === 200 && cancelRes.body.success,
      '21. Booking cancellation & refund calculation'
    );

    // ==========================================
    // COUPON SYSTEM & SLOT BLOCKING TESTS
    // ==========================================

    // Test 22: GET /api/coupons returns configured offers
    const couponsListRes = await makeRequest('GET', '/api/coupons?amountPaise=80000');
    assert(
      couponsListRes.statusCode === 200 &&
      couponsListRes.body.success &&
      Array.isArray(couponsListRes.body.coupons) &&
      couponsListRes.body.coupons.length >= 4,
      '22. GET /api/coupons returns configured promotions with eligibility evaluated'
    );

    // Test 23: POST /api/coupons/validate accepts valid coupon (TOLII150)
    const validateToli150 = await makeRequest('POST', '/api/coupons/validate', {
      code: 'TOLII150',
      amountPaise: 80000,
    });
    assert(
      validateToli150.statusCode === 200 &&
      validateToli150.body.isEligible === true &&
      validateToli150.body.discountPaise === 15000 &&
      validateToli150.body.finalPayablePaise === 65000,
      '23. Coupon Validation: Valid flat coupon (TOLII150) calculates exact 15,000 paise (₹150) discount'
    );

    // Test 24: POST /api/coupons/validate evaluates percentage coupon (PLAYSPORTS20)
    const validatePct = await makeRequest('POST', '/api/coupons/validate', {
      code: 'PLAYSPORTS20',
      amountPaise: 80000,
    });
    assert(
      validatePct.statusCode === 200 &&
      validatePct.body.isEligible === true &&
      validatePct.body.discountPaise === 16000 && // 20% of 80000 = 16000 paise (₹160)
      validatePct.body.finalPayablePaise === 64000,
      '24. Coupon Validation: Percentage coupon (PLAYSPORTS20) calculates 20% discount (16,000 paise)'
    );

    // Test 25: POST /api/coupons/validate rejects invalid/non-existent coupon
    const validateBogus = await makeRequest('POST', '/api/coupons/validate', {
      code: 'FAKEPROMO99',
      amountPaise: 80000,
    });
    assert(
      validateBogus.statusCode === 400 && validateBogus.body.isEligible === false,
      '25. Coupon Validation: Non-existent coupon code is rejected (HTTP 400)'
    );

    // Test 26: POST /api/coupons/validate rejects coupon when minBookingPaise is not met
    const validateMinReq = await makeRequest('POST', '/api/coupons/validate', {
      code: 'CRICKET100', // min booking: 70000 paise
      amountPaise: 50000, // only 50000 paise
    });
    assert(
      validateMinReq.statusCode === 400 && validateMinReq.body.isEligible === false,
      '26. Coupon Validation: Ineligible booking below minimum required amount is rejected (HTTP 400)'
    );

    // Test 27: POST /api/bookings/prepare-payment with coupon applies discount to order
    const couponBookingRes = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_coupon_tester',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      bookingDate: '2026-10-30',
      startTime: '04:00 PM',
      endTime: '05:00 PM',
      durationMinutes: 60,
      pricePaise: 80000,
      hourlyRatePaise: 80000,
      couponCode: 'TOLII150',
    });
    assert(
      couponBookingRes.statusCode === 200 &&
      couponBookingRes.body.discountPaise === 15000 &&
      couponBookingRes.body.amountPaise === 65000 &&
      couponBookingRes.body.appliedCouponCode === 'TOLII150',
      '27. Checkout: Razorpay order created for server-discounted amount (65,000 paise)'
    );

    // Confirm the coupon booking
    const couponBookingId = couponBookingRes.body.bookingId;
    const couponOrderId = couponBookingRes.body.razorpayOrderId;
    const couponPayId = 'pay_coup_' + crypto.randomBytes(6).toString('hex');
    const couponSig = crypto.createHmac('sha256', SECRET_KEY)
      .update(`${couponOrderId}|${couponPayId}`)
      .digest('hex');

    const couponConfirmRes = await makeRequest('POST', '/api/payments/verify', {
      bookingId: couponBookingId,
      razorpayOrderId: couponOrderId,
      razorpayPaymentId: couponPayId,
      razorpaySignature: couponSig,
      userId: 'user_coupon_tester',
    });
    assert(
      couponConfirmRes.statusCode === 200 && couponConfirmRes.body.success,
      '28. Payment Verification: Booking confirmed with coupon details saved'
    );

    // Test 29: Per-user usage limit prevents reusing TOLII150 (usageLimitPerUser: 1)
    const reuseCouponRes = await makeRequest('POST', '/api/coupons/validate', {
      code: 'TOLII150',
      userId: 'user_coupon_tester',
      amountPaise: 80000,
    });
    assert(
      reuseCouponRes.statusCode === 400 && reuseCouponRes.body.isEligible === false,
      '29. Coupon Security: Per-user usage limit rejects exhausted coupon reuse'
    );

    // Test 30: Permanent Slot Blocking - Availability query reflects confirmed slot as booked
    const availabilityRes = await makeRequest(
      'GET',
      '/api/bookings/availability?courtId=court_sidsar_cricket_1&date=2026-10-30'
    );
    assert(
      availabilityRes.statusCode === 200 &&
      availabilityRes.body.bookings.some(b => b.bookingId === couponBookingId && b.bookingStatus === 'CONFIRMED'),
      '30. Permanent Slot Blocking: GET /api/bookings/availability returns confirmed slot as permanently booked'
    );

    // Test 31: Overlapping request for another user on the same court/date/interval is rejected
    const overlapAttempt = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_other_competitor',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      bookingDate: '2026-10-30',
      startTime: '04:30 PM', // Partial overlap with 04:00 PM - 05:00 PM
      durationMinutes: 60,
      pricePaise: 80000,
    });
    assert(
      overlapAttempt.statusCode === 409,
      '31. Permanent Slot Blocking: Future overlapping request on confirmed slot is rejected (HTTP 409 Conflict)'
    );

    // Test 32: Different court on the same date and time interval is NOT blocked
    const diffCourtBooking = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_other_competitor',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_pickleball_1', // Different court!
      bookingDate: '2026-10-30',
      startTime: '04:00 PM',
      durationMinutes: 60,
      pricePaise: 60000,
      hourlyRatePaise: 60000,
    });
    assert(
      diffCourtBooking.statusCode === 200 && diffCourtBooking.body.success,
      '32. Isolation: Different court on the exact same date and time interval is available and allowed'
    );

    // Test 33: Different date on the same court and time interval is NOT blocked
    const diffDateBooking = await makeRequest('POST', '/api/bookings/prepare-payment', {
      userId: 'user_other_competitor',
      venueId: 'venue_sidsar_arena',
      courtId: 'court_sidsar_cricket_1',
      bookingDate: '2026-10-31', // Different date!
      startTime: '04:00 PM',
      durationMinutes: 60,
      pricePaise: 80000,
      hourlyRatePaise: 80000,
    });
    assert(
      diffDateBooking.statusCode === 200 && diffDateBooking.body.success,
      '33. Isolation: Different date on the same court and time interval is available and allowed'
    );

  } catch (err) {
    console.error('❌ Error executing integration test suite:', err);
    failed++;
  } finally {
    server.close();
  }

  console.log('\n====================================================');
  console.log(`📊 INTEGRATION TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================\n');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runBackendTests();

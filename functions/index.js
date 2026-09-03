const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

// Define Firebase Cloud Functions Secrets
const zegoAppIdSecret = defineSecret("ZEGO_APP_ID");
const zegoServerSecretSecret = defineSecret("ZEGO_SERVER_SECRET");

/**
 * Generates a ZegoCloud Token 04 payload for secure room access.
 *
 * @param {number} appId - ZegoCloud App ID
 * @param {string} serverSecret - ZegoCloud Server Secret key (32 bytes)
 * @param {string} userId - Authenticated user identifier
 * @param {string} roomId - Target room identifier
 * @param {number} effectiveTimeInSeconds - Validity window in seconds
 * @param {string} payload - Additional payload metadata
 * @returns {string} Base64 encoded Zego Token 04 string
 */
function generateToken04(appId, serverSecret, userId, roomId, effectiveTimeInSeconds, payload = '') {
  if (!appId || !serverSecret || !userId) {
    throw new Error('Invalid arguments for ZegoCloud token generation');
  }

  const createTime = Math.floor(Date.now() / 1000);
  const expireTime = createTime + effectiveTimeInSeconds;
  const nonce = Math.floor(Math.random() * 2147483647);

  const tokenInfo = {
    app_id: appId,
    user_id: userId,
    room_id: roomId || '',
    nonce: nonce,
    ctime: createTime,
    expire: expireTime,
    payload: payload
  };

  const tokenJson = JSON.stringify(tokenInfo);

  // Normalization of ServerSecret length to 32 bytes for AES-256-CBC
  let secretKey = serverSecret;
  if (secretKey.length < 32) {
    secretKey = secretKey.padEnd(32, '0');
  } else if (secretKey.length > 32) {
    secretKey = secretKey.substring(0, 32);
  }

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(secretKey, 'utf8'), iv);
  let encrypted = cipher.update(tokenJson, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);

  // Binary Token04 Header Structure
  const expireBuf = Buffer.alloc(8);
  expireBuf.writeBigInt64BE(BigInt(expireTime), 0);

  const ivLenBuf = Buffer.alloc(2);
  ivLenBuf.writeUInt16BE(iv.length, 0);

  const encLenBuf = Buffer.alloc(2);
  encLenBuf.writeUInt16BE(encrypted.length, 0);

  const tokenBuf = Buffer.concat([
    Buffer.from('04', 'utf8'),
    expireBuf,
    ivLenBuf,
    iv,
    encLenBuf,
    encrypted
  ]);

  return tokenBuf.toString('base64');
}

/**
 * Firebase Cloud Function to generate ZegoCloud Token 04 for authenticated clients.
 * Reads ZEGO_APP_ID and ZEGO_SERVER_SECRET securely from Firebase Secret Manager / environment.
 */
exports.generateZegoToken = onCall(
  { secrets: [zegoAppIdSecret, zegoServerSecretSecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated via Firebase Auth to request a ZegoCloud token."
      );
    }

    const userId = request.data.userId || request.auth.uid;
    const roomId = request.data.roomId;

    if (!roomId) {
      throw new HttpsError("invalid-argument", "Missing required parameter 'roomId'.");
    }

    // Retrieve secret values dynamically from secret parameters or environment variables
    const rawAppId = zegoAppIdSecret.value() || process.env.ZEGO_APP_ID;
    const serverSecret = zegoServerSecretSecret.value() || process.env.ZEGO_SERVER_SECRET;

    if (!rawAppId || !serverSecret) {
      logger.error("ZEGO_APP_ID or ZEGO_SERVER_SECRET secret configuration is missing.");
      throw new HttpsError("failed-precondition", "Backend security credentials are unconfigured.");
    }

    const appId = parseInt(rawAppId, 10);
    const effectiveTimeInSeconds = request.data.effectiveTimeInSeconds || 3600;

    try {
      const token = generateToken04(
        appId,
        serverSecret,
        userId,
        roomId,
        effectiveTimeInSeconds
      );

      return {
        token,
        appId,
        userId,
        roomId,
      };
    } catch (error) {
      logger.error("Failed to generate ZegoCloud token:", error);
      throw new HttpsError("internal", "Internal error occurred while generating ZegoCloud token.");
    }
  }
);

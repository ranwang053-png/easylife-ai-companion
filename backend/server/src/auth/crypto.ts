import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";

export function keyedHash(value: string, key: Buffer): Buffer {
  return createHmac("sha256", key).update(value).digest();
}

export function equalHashes(left: Buffer, right: Buffer): boolean {
  return left.length === right.length && timingSafeEqual(left, right);
}

export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

export function randomSmsCode(): string {
  const value = randomBytes(4).readUInt32BE() % 1_000_000;
  return value.toString().padStart(6, "0");
}

export function encryptPhone(phone: string, key: Buffer): Buffer {
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  const ciphertext = Buffer.concat([
    cipher.update(phone, "utf8"),
    cipher.final(),
  ]);
  return Buffer.concat([nonce, cipher.getAuthTag(), ciphertext]);
}

export function decryptPhone(value: Buffer, key: Buffer): string {
  const nonce = value.subarray(0, 12);
  const tag = value.subarray(12, 28);
  const ciphertext = value.subarray(28);
  const decipher = createDecipheriv("aes-256-gcm", key, nonce);
  decipher.setAuthTag(tag);
  return Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]).toString("utf8");
}

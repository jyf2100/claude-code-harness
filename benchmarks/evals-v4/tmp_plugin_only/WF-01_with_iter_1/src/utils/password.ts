/**
 * パスワードハッシュ化ユーティリティ
 *
 * bcrypt を使用してパスワードを安全にハッシュ化・検証する
 */

import { randomBytes, timingSafeEqual, pbkdf2 } from 'node:crypto';

/**
 * bcrypt のコスト係数
 * 12 は現在推奨される値（2^12 = 4096 回のイテレーション）
 */
const BCRYPT_COST = 12;

/**
 * Node.js の crypto モジュールを使用した PBKDF2 ベースのハッシュ化
 * bcrypt と同等のセキュリティを提供
 *
 * フォーマット: $pbkdf2$iterations$salt$hash
 */
const ITERATIONS = 100000;
const KEY_LENGTH = 64;
const DIGEST = 'sha512';

/**
 * パスワードをハッシュ化する
 *
 * @param plainPassword - 平文パスワード
 * @returns ハッシュ化されたパスワード
 */
export async function hashPassword(plainPassword: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const salt = randomBytes(32).toString('hex');

    pbkdf2(
      plainPassword,
      salt,
      ITERATIONS,
      KEY_LENGTH,
      DIGEST,
      (err: Error | null, derivedKey: Buffer) => {
        if (err) {
          reject(err);
          return;
        }
        const hash = derivedKey.toString('hex');
        // フォーマット: $pbkdf2$iterations$salt$hash
        resolve(`$pbkdf2$${ITERATIONS}$${salt}$${hash}`);
      }
    );
  });
}

/**
 * パスワードを検証する
 *
 * @param plainPassword - 平文パスワード
 * @param hashedPassword - ハッシュ化されたパスワード
 * @returns パスワードが一致すれば true
 */
export async function verifyPassword(
  plainPassword: string,
  hashedPassword: string
): Promise<boolean> {
  return new Promise((resolve, reject) => {
    // ハッシュをパース
    const parts = hashedPassword.split('$');
    if (parts.length !== 5 || parts[1] !== 'pbkdf2') {
      resolve(false);
      return;
    }

    const iterations = parseInt(parts[2], 10);
    const salt = parts[3];
    const storedHash = parts[4];

    pbkdf2(
      plainPassword,
      salt,
      iterations,
      KEY_LENGTH,
      DIGEST,
      (err: Error | null, derivedKey: Buffer) => {
        if (err) {
          reject(err);
          return;
        }
        const hash = derivedKey.toString('hex');
        // タイミング攻撃を防ぐため、固定時間で比較
        try {
          const storedBuffer = Buffer.from(storedHash, 'hex');
          const derivedBuffer = Buffer.from(hash, 'hex');
          resolve(timingSafeEqual(storedBuffer, derivedBuffer));
        } catch {
          resolve(false);
        }
      }
    );
  });
}

/**
 * パスワードの強度を検証する
 *
 * @param password - 検証するパスワード
 * @returns エラーメッセージ（問題なければ null）
 */
export function validatePasswordStrength(password: string): string | null {
  if (password.length < 8) {
    return 'パスワードは8文字以上である必要があります';
  }
  if (!/[A-Z]/.test(password)) {
    return 'パスワードには大文字を含める必要があります';
  }
  if (!/[a-z]/.test(password)) {
    return 'パスワードには小文字を含める必要があります';
  }
  if (!/[0-9]/.test(password)) {
    return 'パスワードには数字を含める必要があります';
  }
  return null;
}

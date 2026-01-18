/**
 * ユーザー管理サービス
 *
 * ユーザーの作成・更新・削除・検索を提供する
 */

import { randomUUID } from 'node:crypto';
import type { User, CreateUserInput, UpdateUserInput, SafeUser, UserRole } from '../types/user';
import { hashPassword, verifyPassword, validatePasswordStrength } from '../utils/password';

/**
 * ユーザーが見つからない場合のエラー
 */
export class UserNotFoundError extends Error {
  constructor(identifier: string) {
    super(`ユーザーが見つかりません: ${identifier}`);
    this.name = 'UserNotFoundError';
  }
}

/**
 * メールアドレスが既に使用されている場合のエラー
 */
export class EmailAlreadyExistsError extends Error {
  constructor(email: string) {
    super(`このメールアドレスは既に使用されています: ${email}`);
    this.name = 'EmailAlreadyExistsError';
  }
}

/**
 * パスワードが弱い場合のエラー
 */
export class WeakPasswordError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'WeakPasswordError';
  }
}

/**
 * ユーザー管理サービス
 *
 * インメモリストレージを使用（本番環境ではDBに置き換え）
 */
export class UserService {
  private users: Map<string, User> = new Map();

  /**
   * 新しいユーザーを作成する
   *
   * @param input - ユーザー作成入力
   * @returns 作成されたユーザー（パスワードを除く）
   * @throws EmailAlreadyExistsError - メールアドレスが既に使用されている場合
   * @throws WeakPasswordError - パスワードが弱い場合
   */
  async create(input: CreateUserInput): Promise<SafeUser> {
    // メールアドレスの重複チェック
    const existingUser = await this.findByEmail(input.email);
    if (existingUser) {
      throw new EmailAlreadyExistsError(input.email);
    }

    // パスワード強度チェック
    const passwordError = validatePasswordStrength(input.password);
    if (passwordError) {
      throw new WeakPasswordError(passwordError);
    }

    // パスワードをハッシュ化
    const hashedPassword = await hashPassword(input.password);

    const now = new Date();
    const user: User = {
      id: randomUUID(),
      email: input.email,
      hashedPassword,
      role: input.role ?? 'user',
      createdAt: now,
      updatedAt: now,
    };

    this.users.set(user.id, user);

    return this.toSafeUser(user);
  }

  /**
   * ユーザー情報を更新する
   *
   * @param id - ユーザーID
   * @param input - 更新入力
   * @returns 更新されたユーザー（パスワードを除く）
   * @throws UserNotFoundError - ユーザーが見つからない場合
   * @throws EmailAlreadyExistsError - 新しいメールアドレスが既に使用されている場合
   * @throws WeakPasswordError - 新しいパスワードが弱い場合
   */
  async update(id: string, input: UpdateUserInput): Promise<SafeUser> {
    const user = this.users.get(id);
    if (!user) {
      throw new UserNotFoundError(id);
    }

    // メールアドレス変更時の重複チェック
    if (input.email && input.email !== user.email) {
      const existingUser = await this.findByEmail(input.email);
      if (existingUser) {
        throw new EmailAlreadyExistsError(input.email);
      }
      user.email = input.email;
    }

    // パスワード変更
    if (input.password) {
      const passwordError = validatePasswordStrength(input.password);
      if (passwordError) {
        throw new WeakPasswordError(passwordError);
      }
      user.hashedPassword = await hashPassword(input.password);
    }

    // ロール変更
    if (input.role) {
      user.role = input.role;
    }

    user.updatedAt = new Date();
    this.users.set(id, user);

    return this.toSafeUser(user);
  }

  /**
   * ユーザーを削除する
   *
   * @param id - ユーザーID
   * @throws UserNotFoundError - ユーザーが見つからない場合
   */
  async delete(id: string): Promise<void> {
    const user = this.users.get(id);
    if (!user) {
      throw new UserNotFoundError(id);
    }

    this.users.delete(id);
  }

  /**
   * IDでユーザーを検索する
   *
   * @param id - ユーザーID
   * @returns ユーザー（パスワードを除く）または null
   */
  async findById(id: string): Promise<SafeUser | null> {
    const user = this.users.get(id);
    return user ? this.toSafeUser(user) : null;
  }

  /**
   * メールアドレスでユーザーを検索する
   *
   * @param email - メールアドレス
   * @returns ユーザー（パスワードを除く）または null
   */
  async findByEmail(email: string): Promise<SafeUser | null> {
    for (const user of this.users.values()) {
      if (user.email === email) {
        return this.toSafeUser(user);
      }
    }
    return null;
  }

  /**
   * ユーザーの管理者権限を設定する
   *
   * @param id - ユーザーID
   * @param isAdmin - 管理者にするかどうか
   * @returns 更新されたユーザー（パスワードを除く）
   * @throws UserNotFoundError - ユーザーが見つからない場合
   */
  async setAdminRole(id: string, isAdmin: boolean): Promise<SafeUser> {
    const user = this.users.get(id);
    if (!user) {
      throw new UserNotFoundError(id);
    }

    user.role = isAdmin ? 'admin' : 'user';
    user.updatedAt = new Date();
    this.users.set(id, user);

    return this.toSafeUser(user);
  }

  /**
   * パスワードを検証する（ログイン用）
   *
   * @param email - メールアドレス
   * @param password - パスワード
   * @returns 検証成功時はユーザー、失敗時は null
   */
  async verifyCredentials(email: string, password: string): Promise<SafeUser | null> {
    // 内部用: hashedPassword を含むユーザーを取得
    let foundUser: User | null = null;
    for (const user of this.users.values()) {
      if (user.email === email) {
        foundUser = user;
        break;
      }
    }

    if (!foundUser) {
      return null;
    }

    const isValid = await verifyPassword(password, foundUser.hashedPassword);
    return isValid ? this.toSafeUser(foundUser) : null;
  }

  /**
   * User から SafeUser に変換（パスワードを除去）
   */
  private toSafeUser(user: User): SafeUser {
    const { hashedPassword, ...safeUser } = user;
    return safeUser;
  }
}

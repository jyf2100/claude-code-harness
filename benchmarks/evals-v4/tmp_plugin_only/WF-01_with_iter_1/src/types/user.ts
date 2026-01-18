/**
 * ユーザー管理機能の型定義
 */

/**
 * ユーザーの権限レベル
 */
export type UserRole = 'admin' | 'user';

/**
 * ユーザーエンティティ
 */
export interface User {
  id: string;
  email: string;
  hashedPassword: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * ユーザー作成時の入力
 */
export interface CreateUserInput {
  email: string;
  password: string;
  role?: UserRole;
}

/**
 * ユーザー更新時の入力
 */
export interface UpdateUserInput {
  email?: string;
  password?: string;
  role?: UserRole;
}

/**
 * パスワードを除いたユーザー情報（外部公開用）
 */
export type SafeUser = Omit<User, 'hashedPassword'>;

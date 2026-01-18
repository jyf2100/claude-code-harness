import { describe, it, expect, beforeEach } from 'vitest';
import {
  UserService,
  UserNotFoundError,
  EmailAlreadyExistsError,
  WeakPasswordError,
} from '../services/userService';
import { hashPassword, verifyPassword, validatePasswordStrength } from '../utils/password';

describe('UserService', () => {
  let userService: UserService;

  beforeEach(() => {
    userService = new UserService();
  });

  describe('create', () => {
    it('新しいユーザーを作成できる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      expect(user.email).toBe('test@example.com');
      expect(user.role).toBe('user');
      expect(user.id).toBeDefined();
      expect(user.createdAt).toBeInstanceOf(Date);
      expect(user.updatedAt).toBeInstanceOf(Date);
      // hashedPassword は SafeUser に含まれないことを確認
      expect((user as any).hashedPassword).toBeUndefined();
    });

    it('管理者として作成できる', async () => {
      const user = await userService.create({
        email: 'admin@example.com',
        password: 'Password123',
        role: 'admin',
      });

      expect(user.role).toBe('admin');
    });

    it('同じメールアドレスで作成するとエラー', async () => {
      await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      await expect(
        userService.create({
          email: 'test@example.com',
          password: 'Password456',
        })
      ).rejects.toThrow(EmailAlreadyExistsError);
    });

    it('弱いパスワードで作成するとエラー', async () => {
      await expect(
        userService.create({
          email: 'test@example.com',
          password: '1234',
        })
      ).rejects.toThrow(WeakPasswordError);
    });
  });

  describe('update', () => {
    it('メールアドレスを更新できる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const updated = await userService.update(user.id, {
        email: 'new@example.com',
      });

      expect(updated.email).toBe('new@example.com');
    });

    it('パスワードを更新できる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      await userService.update(user.id, {
        password: 'NewPassword456',
      });

      // 新しいパスワードで認証できることを確認
      const verified = await userService.verifyCredentials(
        'test@example.com',
        'NewPassword456'
      );
      expect(verified).not.toBeNull();
    });

    it('存在しないユーザーを更新するとエラー', async () => {
      await expect(
        userService.update('non-existent-id', { email: 'new@example.com' })
      ).rejects.toThrow(UserNotFoundError);
    });
  });

  describe('delete', () => {
    it('ユーザーを削除できる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      await userService.delete(user.id);

      const found = await userService.findById(user.id);
      expect(found).toBeNull();
    });

    it('存在しないユーザーを削除するとエラー', async () => {
      await expect(userService.delete('non-existent-id')).rejects.toThrow(
        UserNotFoundError
      );
    });
  });

  describe('findById', () => {
    it('IDでユーザーを検索できる', async () => {
      const created = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const found = await userService.findById(created.id);
      expect(found).not.toBeNull();
      expect(found!.email).toBe('test@example.com');
    });

    it('存在しないIDで検索すると null', async () => {
      const found = await userService.findById('non-existent-id');
      expect(found).toBeNull();
    });
  });

  describe('findByEmail', () => {
    it('メールアドレスでユーザーを検索できる', async () => {
      await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const found = await userService.findByEmail('test@example.com');
      expect(found).not.toBeNull();
      expect(found!.email).toBe('test@example.com');
    });

    it('存在しないメールアドレスで検索すると null', async () => {
      const found = await userService.findByEmail('nonexistent@example.com');
      expect(found).toBeNull();
    });
  });

  describe('setAdminRole', () => {
    it('ユーザーを管理者に設定できる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const updated = await userService.setAdminRole(user.id, true);
      expect(updated.role).toBe('admin');
    });

    it('管理者を一般ユーザーに戻せる', async () => {
      const user = await userService.create({
        email: 'test@example.com',
        password: 'Password123',
        role: 'admin',
      });

      const updated = await userService.setAdminRole(user.id, false);
      expect(updated.role).toBe('user');
    });

    it('存在しないユーザーの権限を変更するとエラー', async () => {
      await expect(
        userService.setAdminRole('non-existent-id', true)
      ).rejects.toThrow(UserNotFoundError);
    });
  });

  describe('verifyCredentials', () => {
    it('正しいパスワードで認証できる', async () => {
      await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const user = await userService.verifyCredentials(
        'test@example.com',
        'Password123'
      );
      expect(user).not.toBeNull();
      expect(user!.email).toBe('test@example.com');
    });

    it('間違ったパスワードで認証できない', async () => {
      await userService.create({
        email: 'test@example.com',
        password: 'Password123',
      });

      const user = await userService.verifyCredentials(
        'test@example.com',
        'WrongPassword'
      );
      expect(user).toBeNull();
    });

    it('存在しないユーザーで認証できない', async () => {
      const user = await userService.verifyCredentials(
        'nonexistent@example.com',
        'Password123'
      );
      expect(user).toBeNull();
    });
  });
});

describe('Password Utilities', () => {
  describe('hashPassword', () => {
    it('パスワードをハッシュ化できる', async () => {
      const hash = await hashPassword('Password123');
      expect(hash).toContain('$pbkdf2$');
      expect(hash).not.toBe('Password123');
    });

    it('同じパスワードでも異なるハッシュを生成する（ソルト）', async () => {
      const hash1 = await hashPassword('Password123');
      const hash2 = await hashPassword('Password123');
      expect(hash1).not.toBe(hash2);
    });
  });

  describe('verifyPassword', () => {
    it('正しいパスワードを検証できる', async () => {
      const hash = await hashPassword('Password123');
      const isValid = await verifyPassword('Password123', hash);
      expect(isValid).toBe(true);
    });

    it('間違ったパスワードを拒否する', async () => {
      const hash = await hashPassword('Password123');
      const isValid = await verifyPassword('WrongPassword', hash);
      expect(isValid).toBe(false);
    });

    it('不正なハッシュ形式を拒否する', async () => {
      const isValid = await verifyPassword('Password123', 'invalid-hash');
      expect(isValid).toBe(false);
    });
  });

  describe('validatePasswordStrength', () => {
    it('強いパスワードは通過する', () => {
      expect(validatePasswordStrength('Password123')).toBeNull();
    });

    it('短いパスワードは拒否される', () => {
      expect(validatePasswordStrength('Pass1')).not.toBeNull();
    });

    it('大文字がないパスワードは拒否される', () => {
      expect(validatePasswordStrength('password123')).not.toBeNull();
    });

    it('小文字がないパスワードは拒否される', () => {
      expect(validatePasswordStrength('PASSWORD123')).not.toBeNull();
    });

    it('数字がないパスワードは拒否される', () => {
      expect(validatePasswordStrength('PasswordABC')).not.toBeNull();
    });
  });
});

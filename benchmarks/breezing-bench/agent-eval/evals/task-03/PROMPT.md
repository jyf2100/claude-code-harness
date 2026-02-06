user-service.ts の UserService クラスは責務が多すぎます。認証、プロフィール、通知の3つのモジュールに分離してください。既存のテストが全て通ることを確認してください。

## リファクタリング手順

1. `AuthModule` クラスを作成し、以下のメソッドを移動:
   - `findUser`, `createUser`, `hashPassword`, `verifyPassword`, `createSession`, `verifyToken`

2. `ProfileModule` クラスを作成し、以下のメソッドを移動:
   - `updateProfile`, `getProfile`, `verifyUserEmail`

3. `NotificationModule` クラスを作成し、以下のメソッドを移動:
   - `sendNotification`, `getNotifications`, `sendWelcomeEmail`, `sendPasswordResetEmail`

4. `UserService` をファサードに変更:
   - 内部で上記3モジュールをインスタンス化
   - 既存の全メソッドをモジュールへ委譲
   - `validateEmail`, `logAction`, `getLogs`, `clearLogs`, `reset` はファサードに残す

注意: 既存のテストは UserService のインスタンスを使っているため、ファサードの公開 API は変更しないこと。

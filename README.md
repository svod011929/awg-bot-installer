# AWG Bot 2.0 + AmneziaWG Installer (Улучшенная версия)

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Ubuntu 22.04+](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)
![Debian 11+](https://img.shields.io/badge/Debian-11%2B-red)
![Bash 5.0+](https://img.shields.io/badge/Bash-5.0+-green)

Полностью автоматизированный скрипт установки **AmneziaWG VPN сервера** и **AWG Bot 2.0** (Telegram бот для управления VPN) на Ubuntu/Debian сервер с улучшеным пользовательским интерфейсом.

## 🎯 Что улучшено в версии 2.0

### ✅ Критические исправления

- **Синтаксис и структура** — исправлены все синтаксические ошибки функций
- **Зависимости** — замена `netstat` на `ss` (не требует `net-tools`)
- **Автоопределение интерфейса выхода** — вместо жёсткого `eth0` используется автоматическое определение
- **Поддержка Debian** — убрана зависимость от `add-apt-repository`
- **Безопасность** — удалено добавление пользователя в группу `root`

### 🎨 Улучшения пользовательского интерфейса

- **Полная русификация** — все сообщения на русском языке
- **Цветной вывод с эмодзи** — красочный и интуитивный интерфейс
- **ASCII-арт баннер** — красивое приветствие
- **Прогресс-индикаторы** — отслеживание хода установки
- **Интерактивные вопросы** — контроль над критичными операциями

### 🚀 Оптимизация

- **Умная проверка зависимостей** — пропуск уже установленного ПО
- **Расширенная диагностика** — детальная информация об ошибках
- **Кэширование** — повторная установка выполняет только необходимые шаги
- **Безопасные права доступа** — использование `setfacl` вместо добавления в `root`

## 🚀 Возможности

- ✅ Полная автоматизация установки AmneziaWG и AWG Bot
- ✅ Поддержка Ubuntu 22.04+ и Debian 11+
- ✅ Автоматическая конфигурация и оптимизация
- ✅ Systemd сервис с автозагрузкой
- ✅ Подробное логирование процесса установки
- ✅ Проверка зависимостей и верификация
- ✅ Защита конфигурационных файлов
- ✅ Красочный и информативный вывод
- ✅ Поддержка интерактивного режима

## 📋 Требования

### Системные требования

- **ОС**: Ubuntu 22.04+ или Debian 11+
- **Память**: 512 МБ RAM (минимум)
- **Диск**: 2 ГБ свободного места
- **Интернет**: Активное подключение к интернету
- **Доступ**: Привилегии root или sudo

### Сетевые требования

- **Порт 42666** (AmneziaWG) должен быть доступен (UDP)
- Правила брандмауэра открыты для этого порта
- Возможность использования IP forwarding

### Telegram

- Получить токен бота у [@BotFather](https://t.me/botfather)
- Узнать свой Telegram ID через [@userinfobot](https://t.me/userinfobot)

## 📥 Установка

### Шаг 1️⃣: Скачивание скрипта

#### Через curl
```bash
curl -O https://raw.githubusercontent.com/svod011929/awg-bot-installer/improved/awg-bot-install.sh
```

#### Через wget
```bash
wget https://raw.githubusercontent.com/svod011929/awg-bot-installer/improved/awg-bot-install.sh
```

### Шаг 2️⃣: Предоставление прав на выполнение

```bash
chmod +x awg-bot-install.sh
```

### Шаг 3️⃣: Запуск установки

```bash
sudo bash awg-bot-install.sh
```

Скрипт будет:
- Задавать вопросы перед критичными операциями
- Показывать прогресс установки
- Выводить информативные сообщения на русском языке

### Шаг 4️⃣: Конфигурация

После успешной установки отредактируйте файл конфигурации:

```bash
sudo nano /opt/awg-bot/.env
```

**Необходимо заполнить:**
```env
BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN_HERE
ADMIN_ID=YOUR_TELEGRAM_ADMIN_ID_HERE
```

### Шаг 5️⃣: Запуск сервиса

```bash
sudo systemctl start awg-bot
sudo systemctl enable awg-bot  # Для автозагрузки
sudo systemctl restart awg-bot  # После изменения конфигурации
```

## 🔧 Использование

### Проверка статуса сервисов

```bash
# Статус бота
sudo systemctl status awg-bot

# Статус AmneziaWG
sudo systemctl status awg-quick@awg0

# Просмотр логов бота (в реальном времени)
sudo journalctl -u awg-bot -f

# Последние 50 строк логов установки
tail -50 /var/log/awg-bot-install.log
```

### Управление VPN клиентами

```bash
# Просмотр активных интерфейсов
sudo awg show

# Просмотр интерфейса awg0
sudo awg show awg0

# Добавить нового пира (клиента)
sudo awg set awg0 peer <PUBLIC_KEY> allowed-ips <CLIENT_IP>/32

# Просмотр статистики
sudo awg show awg0 stats
```

### Проверка портов и сети

```bash
# Проверить доступность порта VPN
sudo ss -tulpn | grep 42666

# Проверить статус брандмауэра
sudo ufw status

# Разрешить порт VPN
sudo ufw allow 42666/udp

# Проверить IP forwarding
cat /proc/sys/net/ipv4/ip_forward
```

### Управление через Telegram бота

В Telegram отправьте боту команды:
- `/start` — Начало работы
- `/help` — Справка по командам
- `/add_client` — Добавить нового клиента
- `/list_clients` — Список подключённых клиентов
- `/stats` — Статистика использования
- `/remove_client` — Удалить клиента

*(Доступные команды зависят от реализации в AWG_Bot2.0)*

## 📁 Структура установки

```
/opt/awg-bot/                         # Основная директория бота
├── .env                              # Конфигурация (НИКОГДА не коммитить!)
├── main.py                           # Основной скрипт бота
├── requirements.txt                  # Python зависимости
├── venv/                             # Python виртуальное окружение
│   ├── bin/
│   │   └── python
│   ├── lib/
│   │   └── python3.*/site-packages/
│   └── ...
└── ...                               # Другие файлы проекта

/etc/amnezia/amneziawg/               # Конфигурация AmneziaWG
└── awg0.conf                         # Конфиг интерфейса

/etc/systemd/system/                  # Systemd сервисы
├── awg-bot.service                   # Сервис бота
└── awg-quick@awg0.service            # Сервис AmneziaWG

/var/log/awg-bot-install.log         # Лог установки и ошибок
```

## 🐛 Устранение неполадок

### Бот не запускается

```bash
# Проверить статус сервиса
sudo systemctl status awg-bot

# Просмотреть логи ошибок
sudo journalctl -u awg-bot -n 100

# Проверить конфигурацию
cat /opt/awg-bot/.env

# Проверить права доступа
ls -la /opt/awg-bot/

# Проверить, включены ли требуемые значения
sudo nano /opt/awg-bot/.env
```

**Распространённые проблемы:**

| Проблема | Решение |
|----------|---------|
| `BOT_TOKEN not set` | Отредактируйте `.env` и добавьте токен |
| `Permission denied` | Проверьте права: `sudo chown awgbot:awgbot /opt/awg-bot/.env` |
| `Connection refused` | Убедитесь, что сервис запущен: `sudo systemctl start awg-bot` |
| `Module not found` | Переустановите зависимости: `cd /opt/awg-bot && source venv/bin/activate && pip install -r requirements.txt` |

### AmneziaWG не работает

```bash
# Проверить интерфейс
ip addr show awg0

# Проверить статус сервиса
sudo systemctl status awg-quick@awg0

# Просмотр логов ядра
dmesg | tail -20

# Перезагрузить сервис
sudo systemctl restart awg-quick@awg0

# Проверить модуль ядра
lsmod | grep amneziawg
```

### Проблемы с портом

```bash
# Проверить доступность порта
sudo ss -tulpn | grep 42666

# Проверить брандмауэр
sudo ufw status

# Разрешить порт на брандмауэре (UFW)
sudo ufw allow 42666/udp

# Разрешить порт (если используется iptables)
sudo iptables -A INPUT -p udp --dport 42666 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

### Нет интернета после установки

Проверьте, что IP forwarding включен и iptables правила корректны:

```bash
# Включить IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Проверить текущее состояние
cat /proc/sys/net/ipv4/ip_forward

# Постоянная конфигурация
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/00-amnezia.conf
sudo sysctl -p /etc/sysctl.d/00-amnezia.conf
```

## 📊 Переменные конфигурации

| Переменная | По умолчанию | Описание | Изменяемая |
|-----------|------------|---------|-----------|
| `BOT_TOKEN` | - | Токен Telegram бота от @BotFather | ✅ Да |
| `ADMIN_ID` | - | Telegram ID администратора | ✅ Да |
| `AWG_INTERFACE` | `awg0` | Имя сетевого интерфейса | ⚠️ С осторожностью |
| `AWG_PORT` | `42666` | UDP порт для VPN | ⚠️ С осторожностью |
| `AWG_SUBNET` | `10.10.8.0/24` | Внутренняя подсеть VPN | ⚠️ С осторожностью |
| `AWG_CONFIG_PATH` | `/etc/amnezia/amneziawg/awg0.conf` | Путь до конфига | ⚠️ С осторожностью |
| `LOG_LEVEL` | `INFO` | Уровень логирования | ✅ Да |

## 🔐 Безопасность

### Рекомендации

1. **Сменить порт AmneziaWG** (если необходимо по умолчанию используется 42666)
   ```bash
   # Отредактируйте конфиг и перезагрузите сервис
   sudo nano /etc/amnezia/amneziawg/awg0.conf
   sudo systemctl restart awg-quick@awg0
   ```

2. **Использовать HTTPS** при удалённом доступе к управлению
   ```bash
   # Генерируем самоподписной сертификат
   sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
   ```

3. **Ограничить SSH доступ** по IP адресам
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Добавить: AllowUsers user@192.168.1.0/24
   ```

4. **Регулярно обновлять** пакеты
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

5. **Мониторить логи** на предмет подозрительной активности
   ```bash
   sudo journalctl -u awg-bot -u awg-quick@awg0 --since "1 hour ago"
   ```

### Защита конфигурационных файлов

```bash
# Никогда не коммитьте .env в Git!
echo ".env" > /opt/awg-bot/.gitignore

# Правильные права на конфиг
sudo chmod 600 /opt/awg-bot/.env
sudo chown awgbot:awgbot /opt/awg-bot/.env

# Ограничение доступа к логам
sudo chmod 640 /var/log/awg-bot-install.log
```

## 🤝 Участие в проекте

Приветствуются:
- 🐛 Багрепорты (issues)
- 💡 Улучшения и предложения (discussions)
- 📝 Улучшения документации
- 🔧 Патчи и pull requests

### Процесс участия

1. **Fork** проекта на GitHub
2. **Создать** feature branch (`git checkout -b feature/improvement`)
3. **Commit** изменений (`git commit -am 'Add improvement'`)
4. **Push** в branch (`git push origin feature/improvement`)
5. **Открыть** Pull Request

## 📝 История версий

### v2.0 (Улучшенная версия)
- ✅ Полная русификация всех сообщений
- ✅ Цветной вывод с эмодзи и ASCII-артом
- ✅ Исправлены синтаксические ошибки
- ✅ Замена netstat на ss
- ✅ Автоопределение интерфейса выхода
- ✅ Удаление из группы root, использование setfacl
- ✅ Интерактивные вопросы перед критичными операциями
- ✅ Улучшенная диагностика ошибок
- ✅ Расширенная документация

### v1.0 (Исходная версия)
- Базовая установка AmneziaWG и AWG Bot
- Английский язык
- Минимальный пользовательский интерфейс

## 📚 Дополнительные ресурсы

- **AWG Bot 2.0**: https://github.com/JB-SelfCompany/AWG_Bot2.0
- **AmneziaWG**: https://github.com/amnezia-vpn/amneziawg-linux
- **Документация Amnezia**: https://amnezia.org/
- **Telegram BotFather**: https://t.me/botfather

## 👤 Автор

**svod011929**
- GitHub: [@svod011929](https://github.com/svod011929)
- Repository: [awg-bot-installer](https://github.com/svod011929/awg-bot-installer)

## 🙏 Благодарности

Спасибо за вклад в развитие проекта:

- **[JB-SelfCompany](https://github.com/JB-SelfCompany)** — за превосходный AWG Bot 2.0
- **[Amnezia VPN Team](https://github.com/amnezia-vpn)** — за AmneziaWG
- **Всем участникам** сообщества и пользователям

## 📞 Поддержка

Если у вас возникли вопросы или проблемы:

1. 📖 Прочитайте этот README и раздел **Устранение неполадок**
2. 🔍 Посмотрите [существующие issues](https://github.com/svod011929/awg-bot-installer/issues)
3. 🆕 Создайте [новый issue](https://github.com/svod011929/awg-bot-installer/issues/new) с описанием проблемы
4. 💬 Обсудите в [discussions](https://github.com/svod011929/awg-bot-installer/discussions)

При создании issue, пожалуйста, включите:
- Версию ОС (`uname -a`)
- Логи установки (`tail -100 /var/log/awg-bot-install.log`)
- Статус сервисов (`systemctl status awg-bot awg-quick@awg0`)

## 📄 Лицензия

MIT License — see [LICENSE](LICENSE) файл

```
Copyright (c) 2026 svod011929

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

<div align="center">

**⭐ Если проект вам понравился, поставьте звезду! ⭐**

[GitHub](https://github.com/svod011929) • [Issues](https://github.com/svod011929/awg-bot-installer/issues) • [Discussions](https://github.com/svod011929/awg-bot-installer/discussions)

Последнее обновление: 2026-01-01 | Версия: 2.0 (Улучшенная)

</div>

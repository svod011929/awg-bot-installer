#!/bin/bash

################################################################################
#   AWG Bot 2.0 + AmneziaWG Auto-Installer v2.1 (с полной визуализацией)
#   Полностью переработанный скрипт с цветным интерфейсом и прогресс-барами
#   MIT License | Автор: svod011929
################################################################################

set -e

# ═══════════════════════════════════════════════════════════════════════════════
#                          ЦВЕТОВАЯ СХЕМА И ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════════

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Символы
CHECKMARK='✔'
CROSS='✗'
ARROW='→'
BULLET='•'
HOURGLASS='⏳'
GEAR='⚙'
FIRE='🔥'

# Переменные
SCRIPT_VERSION="2.1"
SCRIPT_START_TIME=$(date +%s)
LOG_FILE="/var/log/awg-bot-install.log"
INSTALL_STEP=0
TOTAL_STEPS=18

# ═══════════════════════════════════════════════════════════════════════════════
#                              ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

# Логирование с временной меткой
log() {
    local timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
    echo "${timestamp} $*" | tee -a "$LOG_FILE"
}

# Вывод с цветом
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Прогресс-бар
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "]${NC} %3d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Заголовок секции
section_header() {
    echo ""
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║  $1"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Подзаголовок шага
step_header() {
    ((INSTALL_STEP++))
    printf "\n"
    print_color "$MAGENTA" "[$INSTALL_STEP/$TOTAL_STEPS] ▶ $1"
    print_color "$GRAY" "$(printf '─%.0s' {1..70})"
}

# Успешный результат
success_msg() {
    print_color "$GREEN" "  $CHECKMARK $1"
}

# Ошибка
error_msg() {
    print_color "$RED" "  $CROSS $1"
}

# Информационное сообщение
info_msg() {
    print_color "$BLUE" "  $ARROW $1"
}

# Предупреждение
warning_msg() {
    print_color "$YELLOW" "  ⚠ $1"
}

# Выполнение команды с отображением
run_command() {
    local cmd="$1"
    local description="$2"
    
    info_msg "$description..."
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        success_msg "$description ✅"
        return 0
    else
        error_msg "$description ❌"
        return 1
    fi
}

# Интерактивный вопрос (Yes/No)
ask_yes_no() {
    local question="$1"
    local response
    
    while true; do
        print_color "$YELLOW" "  ? $question (yes/no): " 
        read -r response
        case "$response" in
            yes|y|YES|Y)
                return 0
                ;;
            no|n|NO|N)
                return 1
                ;;
            *)
                error_msg "Пожалуйста, введите 'yes' или 'no'"
                ;;
        esac
    done
}

# Интерактивный ввод
ask_input() {
    local question="$1"
    local response
    
    print_color "$YELLOW" "  ? $question: "
    read -r response
    echo "$response"
}

# Проверка команды
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ГЛАВНЫЙ БАННЕР
# ═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    clear
    print_color "$MAGENTA" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$CYAN" "║         🚀 AWG Bot 2.0 + AmneziaWG Auto-Installer 🚀           ║"
    print_color "$MAGENTA" "║                      Версия $SCRIPT_VERSION (Улучшенная)               ║"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$MAGENTA" "║  Этот скрипт установит и настроит:                           ║"
    print_color "$MAGENTA" "║    • AmneziaWG VPN Server (с управлением клиентами)          ║"
    print_color "$MAGENTA" "║    • AWG Bot 2.0 (Telegram бот для управления VPN)           ║"
    print_color "$MAGENTA" "║    • Systemd сервисы для автозагрузки                        ║"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$MAGENTA" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ПРОВЕРКА ПРЕДВАРИТЕЛЬНЫХ ТРЕБОВАНИЙ
# ═══════════════════════════════════════════════════════════════════════════════

check_requirements() {
    section_header "🔍 ПРОВЕРКА ТРЕБОВАНИЙ"
    
    step_header "Проверка прав доступа"
    if [ "$EUID" -ne 0 ]; then
        error_msg "Скрипт должен запускаться с правами root или sudo"
        log "ОШИБКА: Недостаточно прав (не root)"
        exit 1
    fi
    success_msg "Запущен с правами root"
    log "Скрипт запущен с правами root"
    
    step_header "Определение операционной системы"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        
        info_msg "Обнаружена ОС: $PRETTY_NAME"
        
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            if (( $(echo "$OS_VERSION >= 22.04" | bc -l) || [ "$OS" == "debian" ] && (( $(echo "$OS_VERSION >= 11" | bc -l) )))); then
                success_msg "ОС совместима ($PRETTY_NAME)"
                log "Совместимая ОС: $PRETTY_NAME"
            else
                error_msg "Требуется Ubuntu 22.04+ или Debian 11+"
                exit 1
            fi
        else
            error_msg "Поддерживаются только Ubuntu и Debian"
            exit 1
        fi
    else
        error_msg "Не удалось определить ОС"
        exit 1
    fi
    
    step_header "Проверка подключения к интернету"
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        success_msg "Интернет подключен"
        log "Интернет подключение: OK"
    else
        warning_msg "Нет подключения к интернету (может быть проблема)"
        log "ПРЕДУПРЕЖДЕНИЕ: Интернет не доступен"
    fi
    
    step_header "Проверка дискового пространства"
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$free_space" -gt 2000000 ]; then
        success_msg "Достаточно места на диске (${free_space} КБ)"
        log "Дисковое пространство: ${free_space} КБ"
    else
        warning_msg "Мало места на диске! (${free_space} КБ)"
        log "ПРЕДУПРЕЖДЕНИЕ: Мало дискового пространства"
    fi
    
    step_header "Проверка доступной оперативной памяти"
    local free_ram=$(free -m | awk 'NR==2 {print $7}')
    info_msg "Свободно RAM: ${free_ram} МБ"
    if [ "$free_ram" -lt 256 ]; then
        warning_msg "Оперативной памяти может быть недостаточно"
    else
        success_msg "Память достаточна"
    fi
    log "Свободная оперативная память: ${free_ram} МБ"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ПОДТВЕРЖДЕНИЕ УСТАНОВКИ
# ═══════════════════════════════════════════════════════════════════════════════

confirm_installation() {
    section_header "⚠️  ПОДТВЕРЖДЕНИЕ"
    
    print_color "$YELLOW" "  Этот скрипт выполнит следующие операции:"
    print_color "$GRAY" ""
    print_color "$GRAY" "  1. Обновление списка пакетов (apt update)"
    print_color "$GRAY" "  2. Установка необходимых зависимостей"
    print_color "$GRAY" "  3. Компиляция и установка AmneziaWG"
    print_color "$GRAY" "  4. Загрузка и установка AWG Bot 2.0"
    print_color "$GRAY" "  5. Создание systemd сервисов"
    print_color "$GRAY" "  6. Настройка конфигурации"
    print_color "$GRAY" "  7. Запуск сервисов"
    print_color "$GRAY" ""
    
    if ! ask_yes_no "Продолжить установку?"; then
        print_color "$YELLOW" "  Установка отменена пользователем"
        log "Установка отменена пользователем"
        exit 0
    fi
    
    log "НАЧАЛО УСТАНОВКИ AWG Bot 2.0 + AmneziaWG"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ПРОЦЕСС УСТАНОВКИ
# ═══════════════════════════════════════════════════════════════════════════════

install_dependencies() {
    section_header "📦 УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    step_header "Обновление списка пакетов"
    info_msg "Выполняется: apt update..."
    show_progress 1 5
    
    if apt-get update >> "$LOG_FILE" 2>&1; then
        show_progress 5 5
        success_msg "Списки пакетов обновлены"
        log "apt update: успешно"
    else
        error_msg "Ошибка при обновлении списков пакетов"
        log "ОШИБКА: apt update failed"
        exit 1
    fi
    printf "\n"
    
    step_header "Установка основных пакетов"
    local packages="build-essential libssl-dev libelf-dev pkg-config curl wget git bc net-tools"
    
    info_msg "Устанавливаются пакеты: build-essential, libssl-dev, libelf-dev..."
    show_progress 1 3
    
    if apt-get install -y $packages >> "$LOG_FILE" 2>&1; then
        show_progress 3 3
        success_msg "Основные пакеты установлены"
        log "Основные пакеты установлены успешно"
    else
        error_msg "Ошибка при установке пакетов"
        log "ОШИБКА: установка пакетов failed"
        exit 1
    fi
    printf "\n"
    
    step_header "Установка дополнительных пакетов"
    local extra_packages="python3 python3-pip python3-venv systemd-container"
    
    info_msg "Устанавливаются дополнительные пакеты..."
    if apt-get install -y $extra_packages >> "$LOG_FILE" 2>&1; then
        success_msg "Дополнительные пакеты установлены"
        log "Дополнительные пакеты установлены"
    fi
    printf "\n"
}

install_amneziawg() {
    section_header "🔐 УСТАНОВКА AMNEZIAWG"
    
    step_header "Загрузка исходного кода AmneziaWG"
    info_msg "Клонируется репозиторий AmneziaWG..."
    show_progress 1 4
    
    if [ -d "/tmp/amneziawg-linux" ]; then
        info_msg "Каталог существует, обновляется..."
        cd /tmp/amneziawg-linux
        git pull >> "$LOG_FILE" 2>&1
    else
        if git clone https://github.com/amnezia-vpn/amneziawg-linux.git /tmp/amneziawg-linux >> "$LOG_FILE" 2>&1; then
            show_progress 2 4
            success_msg "Исходный код загружен"
            log "AmneziaWG исходный код загружен"
        else
            error_msg "Ошибка при загрузке исходного кода"
            log "ОШИБКА: не удалось загрузить AmneziaWG"
            exit 1
        fi
    fi
    printf "\n"
    
    step_header "Компиляция AmneziaWG"
    info_msg "Компилируется ядро AmneziaWG (может занять несколько минут)..."
    
    cd /tmp/amneziawg-linux
    show_progress 1 5
    
    if make -j$(nproc) >> "$LOG_FILE" 2>&1; then
        show_progress 5 5
        success_msg "Компиляция завершена"
        log "AmneziaWG скомпилирован успешно"
    else
        error_msg "Ошибка компиляции"
        log "ОШИБКА: компиляция AmneziaWG failed"
        exit 1
    fi
    printf "\n"
    
    step_header "Установка модуля ядра"
    info_msg "Устанавливается модуль ядра..."
    
    if make install >> "$LOG_FILE" 2>&1; then
        success_msg "Модуль ядра установлен"
        log "Модуль ядра AmneziaWG установлен"
        
        # Загрузить модуль
        if modprobe amnezia; then
            success_msg "Модуль загружен в ядро"
        else
            warning_msg "Не удалось загрузить модуль (может потребоваться перезагрузка)"
        fi
    else
        error_msg "Ошибка при установке модуля"
        log "ОШИБКА: установка модуля failed"
        exit 1
    fi
    printf "\n"
}

setup_amneziawg_interface() {
    section_header "🔧 НАСТРОЙКА ИНТЕРФЕЙСА AMNEZIAWG"
    
    step_header "Определение интерфейса выхода"
    
    # Автоматическое определение интерфейса
    local outbound_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [ -z "$outbound_interface" ]; then
        warning_msg "Не удалось автоматически определить интерфейс"
        outbound_interface=$(ask_input "Введите название интерфейса выхода (например, eth0, ens0)")
    else
        success_msg "Обнаружен интерфейс: $outbound_interface"
        log "Интерфейс выхода: $outbound_interface"
    fi
    
    step_header "Создание конфигурации AmneziaWG"
    info_msg "Создание директории /etc/amnezia/amneziawg..."
    mkdir -p /etc/amnezia/amneziawg
    
    info_msg "Создание интерфейса awg0..."
    
    # Создать конфиг
    cat > /etc/amnezia/amneziawg/awg0.conf << 'EOF'
[Interface]
PrivateKey = PRIVATE_KEY_HERE
Address = 10.10.8.1/24
ListenPort = 42666
DNS = 8.8.8.8, 8.8.4.4

PostUp = ip rule add from 10.10.8.0/24 table 200 && ip route add default via 0.0.0.0 dev %i table 200
PostUp = iptables -t nat -A POSTROUTING -s 10.10.8.0/24 -o OUTBOUND_IFACE -j MASQUERADE
PostUp = sysctl -w net.ipv4.ip_forward=1

PostDown = ip rule delete from 10.10.8.0/24 table 200
PostDown = ip route delete default via 0.0.0.0 dev %i table 200
PostDown = iptables -t nat -D POSTROUTING -s 10.10.8.0/24 -o OUTBOUND_IFACE -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 10.10.8.2/32
EOF
    
    # Заменить интерфейс в конфиге
    sed -i "s/OUTBOUND_IFACE/$outbound_interface/g" /etc/amnezia/amneziawg/awg0.conf
    
    success_msg "Конфигурация создана"
    log "Конфигурация AmneziaWG создана в /etc/amnezia/amneziawg/awg0.conf"
    printf "\n"
}

install_awg_bot() {
    section_header "🤖 УСТАНОВКА AWG BOT 2.0"
    
    step_header "Создание пользователя бота"
    info_msg "Создаётся пользователь awgbot..."
    
    if ! id -u awgbot > /dev/null 2>&1; then
        useradd -r -s /bin/false -d /opt/awg-bot -m awgbot
        success_msg "Пользователь awgbot создан"
        log "Пользователь awgbot создан"
    else
        info_msg "Пользователь awgbot уже существует"
    fi
    printf "\n"
    
    step_header "Создание директории бота"
    info_msg "Создаётся /opt/awg-bot..."
    mkdir -p /opt/awg-bot
    chown awgbot:awgbot /opt/awg-bot
    chmod 750 /opt/awg-bot
    success_msg "Директория создана"
    printf "\n"
    
    step_header "Загрузка AWG Bot 2.0"
    info_msg "Клонируется репозиторий AWG Bot..."
    
    if git clone https://github.com/JB-SelfCompany/AWG_Bot2.0.git /tmp/awg-bot-repo >> "$LOG_FILE" 2>&1; then
        show_progress 1 3
        success_msg "Репозиторий загружен"
        log "AWG Bot репозиторий загружен"
    else
        error_msg "Ошибка при загрузке репозитория"
        log "ОШИБКА: не удалось загрузить AWG Bot"
        exit 1
    fi
    printf "\n"
    
    step_header "Копирование файлов бота"
    info_msg "Копируются файлы бота в /opt/awg-bot..."
    show_progress 1 2
    
    cp -r /tmp/awg-bot-repo/* /opt/awg-bot/ >> "$LOG_FILE" 2>&1
    chown -R awgbot:awgbot /opt/awg-bot
    
    show_progress 2 2
    success_msg "Файлы скопированы"
    log "Файлы AWG Bot скопированы в /opt/awg-bot"
    printf "\n"
    
    step_header "Установка Python зависимостей"
    info_msg "Установка зависимостей из requirements.txt..."
    
    if [ -f /opt/awg-bot/requirements.txt ]; then
        pip3 install -r /opt/awg-bot/requirements.txt >> "$LOG_FILE" 2>&1
        success_msg "Зависимости установлены"
        log "Python зависимости установлены"
    else
        warning_msg "requirements.txt не найден"
    fi
    printf "\n"
    
    step_header "Создание файла конфигурации"
    info_msg "Создаётся файл .env..."
    
    # Попросить токен и ID
    local bot_token=$(ask_input "Введите Telegram Bot Token (от @botfather)")
    local admin_id=$(ask_input "Введите ваш Telegram ID (от @userinfobot)")
    
    cat > /opt/awg-bot/.env << EOF
# AWG Bot Configuration
BOT_TOKEN=$bot_token
ADMIN_ID=$admin_id
LOG_LEVEL=INFO
DATABASE_PATH=/opt/awg-bot/data.db
WG_CONFIG_PATH=/etc/amnezia/amneziawg/awg0.conf
WG_INTERFACE=awg0
VPN_SUBNET=10.10.8.0/24
VPN_DNS=8.8.8.8,8.8.4.4
EOF
    
    chown awgbot:awgbot /opt/awg-bot/.env
    chmod 600 /opt/awg-bot/.env
    
    success_msg "Конфигурация создана"
    log "Конфиг AWG Bot создан с токеном и ID администратора"
    printf "\n"
}

create_systemd_services() {
    section_header "⚙️  СОЗДАНИЕ SYSTEMD СЕРВИСОВ"
    
    step_header "Создание сервиса AmneziaWG"
    info_msg "Создаётся /etc/systemd/system/awg-quick@.service..."
    
    cat > /etc/systemd/system/awg-quick@.service << 'EOF'
[Unit]
Description=AmneziaWG VPN Service %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/awg-quick up %i
ExecStop=/usr/local/bin/awg-quick down %i
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success_msg "Сервис AmneziaWG создан"
    log "Сервис awg-quick@.service создан"
    printf "\n"
    
    step_header "Создание сервиса AWG Bot"
    info_msg "Создаётся /etc/systemd/system/awg-bot.service..."
    
    cat > /etc/systemd/system/awg-bot.service << 'EOF'
[Unit]
Description=AWG Bot 2.0 Telegram Bot for AmneziaWG
After=network.target awg-quick@awg0.service

[Service]
Type=simple
User=awgbot
WorkingDirectory=/opt/awg-bot
ExecStart=/usr/bin/python3 /opt/awg-bot/main.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=awg-bot
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success_msg "Сервис AWG Bot создан"
    log "Сервис awg-bot.service создан"
    printf "\n"
}

start_services() {
    section_header "🚀 ЗАПУСК СЕРВИСОВ"
    
    step_header "Запуск AmneziaWG"
    info_msg "Запускается сервис awg-quick@awg0..."
    show_progress 1 3
    
    if systemctl start awg-quick@awg0 >> "$LOG_FILE" 2>&1; then
        show_progress 3 3
        success_msg "AmneziaWG запущен"
        log "Сервис awg-quick@awg0 успешно запущен"
    else
        warning_msg "Ошибка при запуске AmneziaWG (может потребоваться перезагрузка)"
        log "ПРЕДУПРЕЖДЕНИЕ: проблема при запуске awg-quick@awg0"
    fi
    printf "\n"
    
    step_header "Запуск AWG Bot"
    info_msg "Запускается сервис awg-bot..."
    show_progress 1 3
    
    if systemctl start awg-bot >> "$LOG_FILE" 2>&1; then
        show_progress 3 3
        success_msg "AWG Bot запущен"
        log "Сервис awg-bot успешно запущен"
    else
        error_msg "Ошибка при запуске AWG Bot"
        log "ОШИБКА: не удалось запустить awg-bot"
    fi
    printf "\n"
    
    step_header "Включение автозагрузки"
    info_msg "Включается автозагрузка сервисов..."
    
    systemctl enable awg-quick@awg0 >> "$LOG_FILE" 2>&1
    systemctl enable awg-bot >> "$LOG_FILE" 2>&1
    
    success_msg "Автозагрузка включена"
    log "Автозагрузка сервисов включена"
    printf "\n"
}

show_status() {
    section_header "📊 СТАТУС УСТАНОВКИ"
    
    step_header "Статус AmneziaWG"
    if systemctl is-active --quiet awg-quick@awg0; then
        success_msg "AmneziaWG работает ✅"
        log "AmneziaWG статус: активен"
    else
        warning_msg "AmneziaWG не активен (может потребоваться перезагрузка)"
        log "AmneziaWG статус: неактивен"
    fi
    
    if ip link show awg0 > /dev/null 2>&1; then
        info_msg "Интерфейс awg0 обнаружен"
        ip addr show awg0 | grep -E "inet " | awk '{print "    IP: " $2}'
    fi
    printf "\n"
    
    step_header "Статус AWG Bot"
    if systemctl is-active --quiet awg-bot; then
        success_msg "AWG Bot работает ✅"
        log "AWG Bot статус: активен"
    else
        warning_msg "AWG Bot не активен"
        log "AWG Bot статус: неактивен"
    fi
    printf "\n"
    
    step_header "Проверка портов"
    info_msg "Проверяется УДП порт 42666..."
    if ss -tulpn 2>/dev/null | grep 42666 > /dev/null; then
        success_msg "Порт 42666 открыт и слушается"
        log "Порт 42666 активен"
    else
        warning_msg "Порт 42666 не обнаружен"
        log "Порт 42666 не найден в активных портах"
    fi
    printf "\n"
}

show_summary() {
    section_header "✅ УСТАНОВКА ЗАВЕРШЕНА"
    
    print_color "$GREEN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$GREEN" "║              🎉 УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА! 🎉                 ║"
    print_color "$GREEN" "╚════════════════════════════════════════════════════════════════╝"
    printf "\n"
    
    print_color "$CYAN" "📊 ПАРАМЕТРЫ AMNEZIAWG:"
    print_color "$WHITE" "  • Интерфейс: awg0"
    print_color "$WHITE" "  • Конфигурация: /etc/amnezia/amneziawg/awg0.conf"
    print_color "$WHITE" "  • Подсеть: 10.10.8.0/24"
    print_color "$WHITE" "  • УДП Порт: 42666"
    print_color "$WHITE" "  • Сервис: awg-quick@awg0.service"
    printf "\n"
    
    print_color "$CYAN" "🤖 ПАРАМЕТРЫ БОТА:"
    print_color "$WHITE" "  • Директория: /opt/awg-bot"
    print_color "$WHITE" "  • Пользователь: awgbot"
    print_color "$WHITE" "  • Конфигурация: /opt/awg-bot/.env"
    print_color "$WHITE" "  • Сервис: awg-bot.service"
    printf "\n"
    
    print_color "$CYAN" "📝 ПОЛЕЗНЫЕ КОМАНДЫ:"
    print_color "$GRAY" "  # Проверить статус сервисов"
    print_color "$WHITE" "  sudo systemctl status awg-quick@awg0"
    print_color "$WHITE" "  sudo systemctl status awg-bot"
    printf "\n"
    
    print_color "$GRAY" "  # Просмотреть логи"
    print_color "$WHITE" "  sudo journalctl -u awg-bot -f"
    print_color "$WHITE" "  sudo journalctl -u awg-quick@awg0 -f"
    printf "\n"
    
    print_color "$GRAY" "  # Редактировать конфигурацию"
    print_color "$WHITE" "  sudo nano /opt/awg-bot/.env"
    printf "\n"
    
    print_color "$GRAY" "  # Просмотреть интерфейс AmneziaWG"
    print_color "$WHITE" "  ip addr show awg0"
    print_color "$WHITE" "  sudo awg show awg0"
    printf "\n"
    
    print_color "$CYAN" "📋 ЛОГ УСТАНОВКИ:"
    print_color "$WHITE" "  $LOG_FILE"
    printf "\n"
    
    # Вычислить время установки
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_color "$CYAN" "⏱️  ВРЕМЯ УСТАНОВКИ:"
    print_color "$WHITE" "  ${minutes}м ${seconds}с"
    printf "\n"
    
    print_color "$YELLOW" "💡 СЛЕДУЮЩИЕ ШАГИ:"
    print_color "$WHITE" "  1. Отредактируйте конфигурацию бота:"
    print_color "$GRAY" "     sudo nano /opt/awg-bot/.env"
    print_color "$WHITE" "  2. Перезагрузитесь для полной активации всех модулей:"
    print_color "$GRAY" "     sudo reboot"
    print_color "$WHITE" "  3. Проверьте логи при возникновении проблем:"
    print_color "$GRAY" "     sudo tail -100 /var/log/awg-bot-install.log"
    printf "\n"
    
    log "═════════════════════════════════════════════════════════════════"
    log "✔ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО"
    log "═════════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Создать директорию логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Очистить старые логи
    > "$LOG_FILE"
    
    # Вывести баннер
    show_banner
    
    # Запустить процесс установки
    check_requirements
    confirm_installation
    install_dependencies
    install_amneziawg
    setup_amneziawg_interface
    install_awg_bot
    create_systemd_services
    start_services
    show_status
    show_summary
}

# Запустить главную функцию
main "$@"

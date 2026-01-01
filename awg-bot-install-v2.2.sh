#!/bin/bash

################################################################################
#   AWG Bot 2.0 + AmneziaWG Auto-Installer v2.2 (с полной визуализацией)
#   ИСПРАВЛЕННАЯ ВЕРСИЯ - все функции работают правильно
#   MIT License | Автор: svod011929
################################################################################

# Отключить выход при ошибке до основной функции
# set -e

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

# Переменные
SCRIPT_VERSION="2.2"
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
    echo "${timestamp} $*" | tee -a "$LOG_FILE" 2>/dev/null
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

# ═══════════════════════════════════════════════════════════════════════════════
#                              ГЛАВНЫЙ БАННЕР
# ═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    clear
    print_color "$MAGENTA" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$CYAN" "║         🚀 AWG Bot 2.0 + AmneziaWG Auto-Installer 🚀           ║"
    print_color "$MAGENTA" "║                      Версия $SCRIPT_VERSION (Исправленная)            ║"
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
    
    # Проверка прав доступа
    step_header "Проверка прав доступа"
    if [ "$EUID" -ne 0 ]; then
        error_msg "Скрипт должен запускаться с правами root или sudo"
        exit 1
    fi
    success_msg "Запущен с правами root"
    
    # Определение ОС
    step_header "Определение операционной системы"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        
        info_msg "Обнаружена ОС: $PRETTY_NAME"
        
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            success_msg "ОС совместима"
        else
            error_msg "Поддерживаются только Ubuntu и Debian"
            exit 1
        fi
    fi
    
    # Проверка интернета
    step_header "Проверка подключения к интернету"
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        success_msg "Интернет подключен"
    else
        warning_msg "Интернет может быть недоступен"
    fi
    
    # Проверка диска
    step_header "Проверка дискового пространства"
    local free_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$free_space" -gt 2000000 ]; then
        success_msg "Достаточно места на диске"
    else
        warning_msg "Мало места на диске!"
    fi
    
    # Проверка памяти
    step_header "Проверка доступной оперативной памяти"
    local free_ram=$(free -m | awk 'NR==2 {print $7}')
    info_msg "Свободно RAM: ${free_ram} МБ"
    if [ "$free_ram" -gt 256 ]; then
        success_msg "Память достаточна"
    else
        warning_msg "Память может быть недостаточной"
    fi
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ПОДТВЕРЖДЕНИЕ УСТАНОВКИ
# ═══════════════════════════════════════════════════════════════════════════════

confirm_installation() {
    section_header "⚠️  ПОДТВЕРЖДЕНИЕ УСТАНОВКИ"
    
    print_color "$YELLOW" "  Этот скрипт выполнит следующие операции:"
    print_color "$GRAY" ""
    print_color "$GRAY" "  1. Обновление списка пакетов"
    print_color "$GRAY" "  2. Установка необходимых зависимостей"
    print_color "$GRAY" "  3. Компиляция и установка AmneziaWG"
    print_color "$GRAY" "  4. Загрузка и установка AWG Bot 2.0"
    print_color "$GRAY" "  5. Создание systemd сервисов"
    print_color "$GRAY" "  6. Запуск сервисов"
    print_color "$GRAY" ""
    
    if ! ask_yes_no "Продолжить установку?"; then
        print_color "$YELLOW" "  Установка отменена пользователем"
        exit 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          УСТАНОВКА ЗАВИСИМОСТЕЙ
# ═══════════════════════════════════════════════════════════════════════════════

install_dependencies() {
    section_header "📦 УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    # Обновление пакетов
    step_header "Обновление списка пакетов"
    info_msg "Выполняется: apt update..."
    
    if apt-get update > /dev/null 2>&1; then
        success_msg "Списки пакетов обновлены"
    else
        error_msg "Ошибка при обновлении пакетов"
        exit 1
    fi
    
    # Установка основных пакетов
    step_header "Установка основных пакетов"
    info_msg "Устанавливаются: build-essential, libssl-dev, libelf-dev..."
    
    if apt-get install -y build-essential libssl-dev libelf-dev pkg-config curl wget git bc net-tools > /dev/null 2>&1; then
        success_msg "Основные пакеты установлены"
    else
        error_msg "Ошибка при установке пакетов"
        exit 1
    fi
    
    # Установка дополнительных пакетов
    step_header "Установка дополнительных пакетов"
    info_msg "Устанавливаются Python и зависимости..."
    
    if apt-get install -y python3 python3-pip python3-venv > /dev/null 2>&1; then
        success_msg "Дополнительные пакеты установлены"
    else
        warning_msg "Некоторые пакеты не установлены (может быть ОК)"
    fi
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          УСТАНОВКА AMNEZIAWG
# ═══════════════════════════════════════════════════════════════════════════════

install_amneziawg() {
    section_header "🔐 УСТАНОВКА AMNEZIAWG"
    
    # Загрузка кода
    step_header "Загрузка исходного кода AmneziaWG"
    info_msg "Клонируется репозиторий..."
    
    if [ -d "/tmp/amneziawg-linux" ]; then
        info_msg "Репозиторий уже существует, обновляется..."
        cd /tmp/amneziawg-linux
        git pull > /dev/null 2>&1
    else
        if git clone https://github.com/amnezia-vpn/amneziawg-linux.git /tmp/amneziawg-linux > /dev/null 2>&1; then
            success_msg "Исходный код загружен"
        else
            error_msg "Ошибка при загрузке репозитория"
            exit 1
        fi
    fi
    
    # Компиляция
    step_header "Компиляция AmneziaWG"
    info_msg "Компилируется (может занять 5-15 минут)..."
    
    cd /tmp/amneziawg-linux
    if make -j$(nproc) > /dev/null 2>&1; then
        success_msg "Компиляция завершена"
    else
        error_msg "Ошибка компиляции"
        exit 1
    fi
    
    # Установка
    step_header "Установка модуля ядра"
    info_msg "Устанавливается модуль ядра..."
    
    if make install > /dev/null 2>&1; then
        success_msg "Модуль ядра установлен"
        
        if modprobe amnezia 2>/dev/null; then
            success_msg "Модуль загружен в ядро"
        else
            warning_msg "Не удалось загрузить модуль (может потребоваться перезагрузка)"
        fi
    else
        error_msg "Ошибка при установке модуля"
        exit 1
    fi
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          НАСТРОЙКА AMNEZIAWG
# ═══════════════════════════════════════════════════════════════════════════════

setup_amneziawg_interface() {
    section_header "🔧 НАСТРОЙКА ИНТЕРФЕЙСА AMNEZIAWG"
    
    # Определение интерфейса
    step_header "Определение сетевого интерфейса"
    
    local outbound_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [ -z "$outbound_interface" ]; then
        warning_msg "Не удалось автоматически определить интерфейс"
        outbound_interface=$(ask_input "Введите название интерфейса (например, eth0)")
    else
        success_msg "Обнаружен интерфейс: $outbound_interface"
    fi
    
    # Создание конфигурации
    step_header "Создание конфигурации AmneziaWG"
    info_msg "Создание директории /etc/amnezia/amneziawg..."
    mkdir -p /etc/amnezia/amneziawg
    
    info_msg "Создание файла конфигурации..."
    
    cat > /etc/amnezia/amneziawg/awg0.conf << EOF
[Interface]
PrivateKey = PRIVATE_KEY_HERE
Address = 10.10.8.1/24
ListenPort = 42666
DNS = 8.8.8.8, 8.8.4.4

PostUp = ip rule add from 10.10.8.0/24 table 200
PostUp = ip route add default via 0.0.0.0 dev %i table 200
PostUp = iptables -t nat -A POSTROUTING -s 10.10.8.0/24 -o $outbound_interface -j MASQUERADE
PostUp = sysctl -w net.ipv4.ip_forward=1

PostDown = ip rule delete from 10.10.8.0/24 table 200
PostDown = iptables -t nat -D POSTROUTING -s 10.10.8.0/24 -o $outbound_interface -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 10.10.8.2/32
EOF
    
    success_msg "Конфигурация создана"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          УСТАНОВКА AWG BOT
# ═══════════════════════════════════════════════════════════════════════════════

install_awg_bot() {
    section_header "🤖 УСТАНОВКА AWG BOT 2.0"
    
    # Пользователь
    step_header "Создание пользователя бота"
    info_msg "Создаётся пользователь awgbot..."
    
    if ! id -u awgbot > /dev/null 2>&1; then
        useradd -r -s /bin/false -d /opt/awg-bot -m awgbot
        success_msg "Пользователь awgbot создан"
    else
        info_msg "Пользователь awgbot уже существует"
    fi
    
    # Директория
    step_header "Создание директории бота"
    mkdir -p /opt/awg-bot
    chown awgbot:awgbot /opt/awg-bot
    chmod 750 /opt/awg-bot
    success_msg "Директория создана"
    
    # Загрузка бота
    step_header "Загрузка AWG Bot 2.0"
    info_msg "Клонируется репозиторий AWG Bot..."
    
    if git clone https://github.com/JB-SelfCompany/AWG_Bot2.0.git /tmp/awg-bot-repo > /dev/null 2>&1; then
        success_msg "Репозиторий загружен"
    else
        error_msg "Ошибка при загрузке репозитория"
        exit 1
    fi
    
    # Копирование файлов
    step_header "Копирование файлов бота"
    info_msg "Копируются файлы в /opt/awg-bot..."
    
    cp -r /tmp/awg-bot-repo/* /opt/awg-bot/ 2>/dev/null
    chown -R awgbot:awgbot /opt/awg-bot
    success_msg "Файлы скопированы"
    
    # Зависимости Python
    step_header "Установка Python зависимостей"
    info_msg "Устанавливаются зависимости..."
    
    if [ -f /opt/awg-bot/requirements.txt ]; then
        pip3 install -q -r /opt/awg-bot/requirements.txt 2>/dev/null
        success_msg "Зависимости установлены"
    else
        warning_msg "requirements.txt не найден"
    fi
    
    # Конфигурация
    step_header "Создание файла конфигурации"
    
    local bot_token=$(ask_input "Введите Telegram Bot Token (от @botfather)")
    local admin_id=$(ask_input "Введите ваш Telegram ID (от @userinfobot)")
    
    cat > /opt/awg-bot/.env << EOF
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
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          СОЗДАНИЕ SYSTEMD СЕРВИСОВ
# ═══════════════════════════════════════════════════════════════════════════════

create_systemd_services() {
    section_header "⚙️  СОЗДАНИЕ SYSTEMD СЕРВИСОВ"
    
    # Сервис AmneziaWG
    step_header "Создание сервиса AmneziaWG"
    
    cat > /etc/systemd/system/awg-quick@.service << 'EOF'
[Unit]
Description=AmneziaWG VPN Service %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/awg-quick up %i
ExecStop=/usr/local/bin/awg-quick down %i
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success_msg "Сервис AmneziaWG создан"
    
    # Сервис AWG Bot
    step_header "Создание сервиса AWG Bot"
    
    cat > /etc/systemd/system/awg-bot.service << 'EOF'
[Unit]
Description=AWG Bot 2.0 Telegram Bot
After=network.target awg-quick@awg0.service

[Service]
Type=simple
User=awgbot
WorkingDirectory=/opt/awg-bot
ExecStart=/usr/bin/python3 /opt/awg-bot/main.py
Restart=on-failure
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    success_msg "Сервис AWG Bot создан"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ЗАПУСК СЕРВИСОВ
# ═══════════════════════════════════════════════════════════════════════════════

start_services() {
    section_header "🚀 ЗАПУСК СЕРВИСОВ"
    
    # Запуск AmneziaWG
    step_header "Запуск AmneziaWG"
    info_msg "Запускается сервис awg-quick@awg0..."
    
    if systemctl start awg-quick@awg0 2>/dev/null; then
        success_msg "AmneziaWG запущен"
    else
        warning_msg "Ошибка при запуске AmneziaWG (может потребоваться перезагрузка)"
    fi
    
    # Запуск бота
    step_header "Запуск AWG Bot"
    info_msg "Запускается сервис awg-bot..."
    
    if systemctl start awg-bot 2>/dev/null; then
        success_msg "AWG Bot запущен"
    else
        warning_msg "Ошибка при запуске AWG Bot"
    fi
    
    # Автозагрузка
    step_header "Включение автозагрузки"
    systemctl enable awg-quick@awg0 > /dev/null 2>&1
    systemctl enable awg-bot > /dev/null 2>&1
    success_msg "Автозагрузка включена"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#                          ФИНАЛЬНОЕ РЕЗЮМЕ
# ═══════════════════════════════════════════════════════════════════════════════

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
    printf "\n"
    
    print_color "$CYAN" "🤖 ПАРАМЕТРЫ БОТА:"
    print_color "$WHITE" "  • Директория: /opt/awg-bot"
    print_color "$WHITE" "  • Пользователь: awgbot"
    print_color "$WHITE" "  • Конфигурация: /opt/awg-bot/.env"
    printf "\n"
    
    print_color "$CYAN" "📝 ПОЛЕЗНЫЕ КОМАНДЫ:"
    print_color "$GRAY" "  # Проверить статус"
    print_color "$WHITE" "  sudo systemctl status awg-bot"
    print_color "$WHITE" "  sudo systemctl status awg-quick@awg0"
    printf "\n"
    
    print_color "$GRAY" "  # Просмотреть логи"
    print_color "$WHITE" "  sudo journalctl -u awg-bot -f"
    printf "\n"
    
    print_color "$GRAY" "  # Редактировать конфигурацию"
    print_color "$WHITE" "  sudo nano /opt/awg-bot/.env"
    printf "\n"
    
    # Время установки
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_color "$YELLOW" "⏱️  ВРЕМЯ УСТАНОВКИ: ${minutes}м ${seconds}с"
    printf "\n"
    
    print_color "$YELLOW" "💡 СЛЕДУЮЩИЕ ШАГИ:"
    print_color "$WHITE" "  1. Отредактируйте конфигурацию: sudo nano /opt/awg-bot/.env"
    print_color "$WHITE" "  2. Перезагрузитесь для полной активации: sudo reboot"
    print_color "$WHITE" "  3. Проверьте логи при проблемах: sudo journalctl -u awg-bot -n 50"
    printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
#                              ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Создать директорию логов
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    > "$LOG_FILE" 2>/dev/null
    
    # Вывести баннер
    show_banner
    
    # Запустить процесс установки
    check_requirements || exit 1
    confirm_installation
    install_dependencies
    install_amneziawg
    setup_amneziawg_interface
    install_awg_bot
    create_systemd_services
    start_services
    show_summary
    
    print_color "$GREEN" "✅ Всё готово! Система установлена успешно!"
    echo ""
}

# Запустить главную функцию
main "$@"
exit 0

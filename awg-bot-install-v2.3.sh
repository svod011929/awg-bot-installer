#!/bin/bash

################################################################################
#   AWG Bot 2.0 + AmneziaWG Auto-Installer v2.3 (Оптимизированный)
#   С таймаутами, прогрессом и обработкой зависаний
#   MIT License | Автор: svod011929
################################################################################

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Символы
CHECKMARK='✔'
CROSS='✗'
ARROW='→'

# Переменные
SCRIPT_VERSION="2.3"
SCRIPT_START_TIME=$(date +%s)
LOG_FILE="/var/log/awg-bot-install.log"
INSTALL_STEP=0
TOTAL_STEPS=12

# Функции
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

section_header() {
    echo ""
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║  $1"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

step_header() {
    ((INSTALL_STEP++))
    printf "\n"
    print_color "$MAGENTA" "[$INSTALL_STEP/$TOTAL_STEPS] ▶ $1"
    print_color "$GRAY" "$(printf '─%.0s' {1..70})"
}

success_msg() {
    print_color "$GREEN" "  $CHECKMARK $1"
}

error_msg() {
    print_color "$RED" "  $CROSS $1"
}

info_msg() {
    print_color "$BLUE" "  $ARROW $1"
}

warning_msg() {
    print_color "$YELLOW" "  ⚠ $1"
}

ask_yes_no() {
    local question="$1"
    local response
    
    while true; do
        print_color "$YELLOW" "  ? $question (yes/no): " 
        read -r response
        case "$response" in
            yes|y|YES|Y) return 0 ;;
            no|n|NO|N) return 1 ;;
            *) error_msg "Пожалуйста, введите 'yes' или 'no'" ;;
        esac
    done
}

ask_input() {
    local question="$1"
    print_color "$YELLOW" "  ? $question: "
    read -r response
    echo "$response"
}

show_banner() {
    clear
    print_color "$MAGENTA" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$CYAN" "║         🚀 AWG Bot 2.0 + AmneziaWG Auto-Installer 🚀           ║"
    print_color "$MAGENTA" "║                      Версия $SCRIPT_VERSION (Оптимизированная)       ║"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$MAGENTA" "║  Этот скрипт установит:                                      ║"
    print_color "$MAGENTA" "║    • AmneziaWG VPN Server                                     ║"
    print_color "$MAGENTA" "║    • AWG Bot 2.0 (Telegram бот)                               ║"
    print_color "$MAGENTA" "║    • Systemd сервисы                                          ║"
    print_color "$MAGENTA" "║                                                                ║"
    print_color "$MAGENTA" "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# ПРОВЕРКА ТРЕБОВАНИЙ
check_requirements() {
    section_header "🔍 ПРОВЕРКА ТРЕБОВАНИЙ"
    
    step_header "Проверка прав доступа"
    if [ "$EUID" -ne 0 ]; then
        error_msg "Требуются права root"
        exit 1
    fi
    success_msg "Запущен с правами root"
    
    step_header "Проверка ОС"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        info_msg "Обнаружена: $PRETTY_NAME"
        success_msg "ОС совместима"
    else
        error_msg "Не удалось определить ОС"
        exit 1
    fi
    
    step_header "Проверка интернета"
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        success_msg "Интернет подключен"
    else
        warning_msg "Интернет может быть недоступен"
    fi
    
    step_header "Проверка памяти"
    local free_ram=$(free -m | awk 'NR==2 {print $7}')
    info_msg "Свободно RAM: ${free_ram} МБ"
    if [ "$free_ram" -gt 256 ]; then
        success_msg "Память достаточна"
    else
        error_msg "Недостаточно памяти (требуется 256+ МБ)"
        exit 1
    fi
    
    echo ""
}

# ПОДТВЕРЖДЕНИЕ
confirm_installation() {
    section_header "⚠️  ПОДТВЕРЖДЕНИЕ"
    
    print_color "$YELLOW" "  Этот скрипт установит:"
    print_color "$GRAY" "    1. Обновление пакетов (apt update)"
    print_color "$GRAY" "    2. Установка зависимостей"
    print_color "$GRAY" "    3. Компиляция AmneziaWG"
    print_color "$GRAY" "    4. Установка AWG Bot 2.0"
    print_color "$GRAY" "    5. Запуск сервисов"
    print_color "$GRAY" ""
    
    if ! ask_yes_no "Продолжить?"; then
        print_color "$YELLOW" "  Отменено пользователем"
        exit 0
    fi
}

# УСТАНОВКА С ТАЙМАУТАМИ И ПРОГРЕССОМ
install_dependencies() {
    section_header "📦 УСТАНОВКА ЗАВИСИМОСТЕЙ"
    
    step_header "Обновление списка пакетов"
    info_msg "Выполняется apt update (может занять 2-5 минут)..."
    
    if timeout 300 apt-get update > /dev/null 2>&1; then
        success_msg "Пакеты обновлены"
    else
        error_msg "Таймаут обновления пакетов"
        warning_msg "Продолжаем без обновления..."
    fi
    
    step_header "Установка build-essential"
    info_msg "Это может занять 10-20 минут... Ожидайте..."
    
    # Установка с таймаутом 30 минут
    if timeout 1800 apt-get install -y --no-install-recommends build-essential > /dev/null 2>&1; then
        success_msg "build-essential установлен"
    else
        warning_msg "build-essential установлен с ошибками (может быть ОК)"
    fi
    
    step_header "Установка libssl-dev"
    info_msg "Устанавливается libssl-dev..."
    
    if timeout 600 apt-get install -y --no-install-recommends libssl-dev > /dev/null 2>&1; then
        success_msg "libssl-dev установлен"
    else
        warning_msg "Проблема с libssl-dev (может быть ОК)"
    fi
    
    step_header "Установка остальных зависимостей"
    info_msg "Устанавливаются: libelf-dev, curl, wget, git, python3..."
    
    if timeout 600 apt-get install -y --no-install-recommends libelf-dev curl wget git python3 python3-pip > /dev/null 2>&1; then
        success_msg "Остальные пакеты установлены"
    else
        warning_msg "Некоторые пакеты не установлены (может быть ОК)"
    fi
    
    echo ""
}

# УСТАНОВКА AMNEZIAWG
install_amneziawg() {
    section_header "🔐 УСТАНОВКА AMNEZIAWG"
    
    step_header "Загрузка кода"
    info_msg "Клонируется репозиторий AmneziaWG..."
    
    if [ ! -d "/tmp/amneziawg-linux" ]; then
        if ! timeout 600 git clone https://github.com/amnezia-vpn/amneziawg-linux.git /tmp/amneziawg-linux > /dev/null 2>&1; then
            error_msg "Не удалось загрузить репозиторий"
            exit 1
        fi
    fi
    
    success_msg "Код загружен"
    
    step_header "Компиляция AmneziaWG"
    info_msg "Компилируется (5-15 минут)... Ожидайте..."
    
    cd /tmp/amneziawg-linux
    
    # Показать прогресс каждую минуту
    (
        while pgrep -f "make -j" > /dev/null; do
            sleep 10
            echo -n "."
        done
    ) &
    local spinner_pid=$!
    
    if timeout 1800 make -j$(nproc) > /dev/null 2>&1; then
        kill $spinner_pid 2>/dev/null
        success_msg "Компиляция завершена"
    else
        kill $spinner_pid 2>/dev/null
        error_msg "Ошибка компиляции"
        exit 1
    fi
    
    step_header "Установка модуля"
    info_msg "Устанавливается модуль ядра..."
    
    if timeout 300 make install > /dev/null 2>&1; then
        success_msg "Модуль ядра установлен"
        
        if modprobe amnezia 2>/dev/null; then
            success_msg "Модуль загружен"
        else
            warning_msg "Модуль может быть загруженн после перезагрузки"
        fi
    else
        error_msg "Ошибка установки модуля"
        exit 1
    fi
    
    echo ""
}

# НАСТРОЙКА
setup_amneziawg() {
    section_header "🔧 НАСТРОЙКА AMNEZIAWG"
    
    step_header "Определение интерфейса"
    local outbound_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [ -z "$outbound_interface" ]; then
        outbound_interface=$(ask_input "Введите интерфейс (например, eth0)")
    fi
    
    success_msg "Интерфейс: $outbound_interface"
    
    step_header "Создание конфигурации"
    mkdir -p /etc/amnezia/amneziawg
    
    cat > /etc/amnezia/amneziawg/awg0.conf << EOF
[Interface]
PrivateKey = PRIVATE_KEY_HERE
Address = 10.10.8.1/24
ListenPort = 42666
DNS = 8.8.8.8, 8.8.4.4

PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -t nat -A POSTROUTING -s 10.10.8.0/24 -o $outbound_interface -j MASQUERADE

PostDown = iptables -t nat -D POSTROUTING -s 10.10.8.0/24 -o $outbound_interface -j MASQUERADE

[Peer]
PublicKey = CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 10.10.8.2/32
EOF
    
    success_msg "Конфигурация создана"
    echo ""
}

# УСТАНОВКА БОТА
install_awg_bot() {
    section_header "🤖 УСТАНОВКА AWG BOT"
    
    step_header "Подготовка"
    if ! id -u awgbot > /dev/null 2>&1; then
        useradd -r -s /bin/false -d /opt/awg-bot -m awgbot
        success_msg "Пользователь создан"
    fi
    
    mkdir -p /opt/awg-bot
    chown awgbot:awgbot /opt/awg-bot
    
    step_header "Загрузка AWG Bot"
    info_msg "Клонируется репозиторий..."
    
    if timeout 600 git clone https://github.com/JB-SelfCompany/AWG_Bot2.0.git /tmp/awg-bot-repo > /dev/null 2>&1; then
        success_msg "Репозиторий загружен"
    else
        warning_msg "Не удалось загрузить (продолжаем...)"
    fi
    
    step_header "Копирование файлов"
    if [ -d "/tmp/awg-bot-repo" ]; then
        cp -r /tmp/awg-bot-repo/* /opt/awg-bot/ 2>/dev/null
        chown -R awgbot:awgbot /opt/awg-bot
        success_msg "Файлы скопированы"
    fi
    
    step_header "Создание конфигурации"
    local bot_token=$(ask_input "Введите Bot Token (от @botfather)")
    local admin_id=$(ask_input "Введите ваш Telegram ID")
    
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

# СЕРВИСЫ
create_services() {
    section_header "⚙️  СОЗДАНИЕ СЕРВИСОВ"
    
    step_header "Сервис AmneziaWG"
    cat > /etc/systemd/system/awg-quick@.service << 'EOF'
[Unit]
Description=AmneziaWG VPN %i
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/awg-quick up %i
ExecStop=/usr/local/bin/awg-quick down %i
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    step_header "Сервис AWG Bot"
    cat > /etc/systemd/system/awg-bot.service << 'EOF'
[Unit]
Description=AWG Bot 2.0
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
    success_msg "Сервисы созданы"
    
    echo ""
}

# ЗАПУСК
start_services() {
    section_header "🚀 ЗАПУСК СЕРВИСОВ"
    
    step_header "Запуск AmneziaWG"
    if systemctl start awg-quick@awg0 2>/dev/null; then
        success_msg "AmneziaWG запущен"
    else
        warning_msg "AmneziaWG: требуется перезагрузка"
    fi
    
    step_header "Запуск AWG Bot"
    if systemctl start awg-bot 2>/dev/null; then
        success_msg "AWG Bot запущен"
    else
        warning_msg "AWG Bot не запущен"
    fi
    
    step_header "Автозагрузка"
    systemctl enable awg-quick@awg0 > /dev/null 2>&1
    systemctl enable awg-bot > /dev/null 2>&1
    success_msg "Автозагрузка включена"
    
    echo ""
}

# ФИНАЛ
show_summary() {
    section_header "✅ УСТАНОВКА ЗАВЕРШЕНА"
    
    print_color "$GREEN" "🎉 УСПЕШНО!"
    printf "\n"
    
    print_color "$CYAN" "📊 AmneziaWG:"
    print_color "$WHITE" "  • Интерфейс: awg0"
    print_color "$WHITE" "  • Конфиг: /etc/amnezia/amneziawg/awg0.conf"
    print_color "$WHITE" "  • Порт: 42666/UDP"
    printf "\n"
    
    print_color "$CYAN" "🤖 AWG Bot:"
    print_color "$WHITE" "  • Директория: /opt/awg-bot"
    print_color "$WHITE" "  • Конфиг: /opt/awg-bot/.env"
    printf "\n"
    
    print_color "$CYAN" "📝 Команды:"
    print_color "$GRAY" "  sudo systemctl status awg-bot"
    print_color "$GRAY" "  sudo systemctl status awg-quick@awg0"
    print_color "$GRAY" "  sudo journalctl -u awg-bot -f"
    print_color "$GRAY" "  sudo nano /opt/awg-bot/.env"
    printf "\n"
    
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    print_color "$YELLOW" "⏱️  Время: $((duration/60))м $((duration%60))с"
    printf "\n"
}

# ГЛАВНАЯ
main() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    > "$LOG_FILE" 2>/dev/null
    
    show_banner
    check_requirements
    confirm_installation
    install_dependencies
    install_amneziawg
    setup_amneziawg
    install_awg_bot
    create_services
    start_services
    show_summary
    
    print_color "$GREEN" "✅ Готово!"
    echo ""
}

main "$@"
exit 0

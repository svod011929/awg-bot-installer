#!/bin/bash

################################################################################
# AWG Bot + AmneziaWG - Скрипт полной автоустановки
# Версия: 2.3
# Описание: Автоматическая установка и настройка AmneziaWG VPN сервера
#           с Telegram ботом управления клиентами
################################################################################

set -euo pipefail

# ============================================================================
# КОНФИГУРАЦИЯ И ПЕРЕМЕННЫЕ
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/awg-bot-install.log"
readonly INSTALL_DIR="/opt/awg-bot"
readonly AWG_REPO="https://github.com/amnezia-vpn/amneziawg-go.git"
readonly BOT_REPO="https://github.com/JB-SelfCompany/AWG_Bot2.0.git"
readonly VENV_PATH="${INSTALL_DIR}/venv"
readonly CONFIG_FILE="${INSTALL_DIR}/.env"
readonly BACKUP_DIR="${INSTALL_DIR}/backups"
readonly AWG_CONFIG_DIR="/etc/amnezia/amneziawg"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# ФУНКЦИИ ЛОГИРОВАНИЯ И ВЫВОДА
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "${LOG_FILE}"
    log "SUCCESS" "$*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "${LOG_FILE}"
    log "ERROR" "$*"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*" | tee -a "${LOG_FILE}"
    log "WARNING" "$*"
}

# ============================================================================
# ФУНКЦИИ ПРОВЕРКИ
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами администратора (sudo)"
        exit 1
    fi
    log_success "Проверка прав суперпользователя пройдена"
}

check_os() {
    local os_type
    if [[ -f /etc/os-release ]]; then
        os_type=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    else
        log_error "Невозможно определить тип операционной системы"
        exit 1
    fi

    case "${os_type}" in
        ubuntu|debian)
            log_success "Обнаружена поддерживаемая ОС: ${os_type}"
            return 0
            ;;
        *)
            log_warning "ОС ${os_type} может быть не полностью поддержана"
            return 0
            ;;
    esac
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

check_disk_space() {
    local required_mb=500
    local available_mb=$(df "${INSTALL_DIR%/*}" 2>/dev/null | awk 'NR==2 {print $4}' || echo "1000")
    
    if [[ ${available_mb} -lt ${required_mb} ]]; then
        log_error "Недостаточно места на диске. Требуется минимум ${required_mb}МБ"
        return 1
    fi
    log_success "Проверка свободного места пройдена (${available_mb}МБ доступно)"
    return 0
}

# ============================================================================
# ФУНКЦИИ УСТАНОВКИ ЗАВИСИМОСТЕЙ
# ============================================================================

install_dependencies() {
    log_info "Установка системных зависимостей..."

    # Обновление репозиториев
    log_info "Обновление пакетов системы..."
    apt-get update -qq || log_error "Ошибка при обновлении пакетов"

    # Базовые зависимости для Go и компиляции
    local deps_build=(
        "build-essential"
        "git"
        "curl"
        "wget"
        "gnupg"
        "lsb-release"
    )

    # Зависимости для Python и бота
    local deps_python=(
        "python3"
        "python3-dev"
        "python3-venv"
        "python3-pip"
    )

    # Сетевые утилиты
    local deps_network=(
        "iproute2"
        "iptables"
        "netcat-openbsd"
    )

    local all_deps=("${deps_build[@]}" "${deps_python[@]}" "${deps_network[@]}")

    for package in "${all_deps[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${package}"; then
            log_info "Установка ${package}..."
            apt-get install -y -qq "${package}" 2>/dev/null || log_warning "Проблема с установкой ${package}"
        fi
    done

    log_success "Системные зависимости успешно установлены"
}

install_golang() {
    log_info "Проверка установки Go..."

    if check_command "go"; then
        local go_version=$(go version | awk '{print $3}')
        log_success "Go уже установлена: ${go_version}"
        return 0
    fi

    log_info "Установка Go..."
    local go_version="1.21.0"
    local go_tarball="go${go_version}.linux-amd64.tar.gz"
    local go_url="https://golang.org/dl/${go_tarball}"

    cd /tmp || return 1
    if ! wget -q "${go_url}" 2>/dev/null; then
        log_error "Ошибка загрузки Go, пробуем альтернативный источник..."
        go_url="https://go.dev/dl/${go_tarball}"
        wget -q "${go_url}" || {
            log_error "Ошибка загрузки Go"
            return 1
        }
    fi

    tar -C /usr/local -xzf "${go_tarball}" || {
        log_error "Ошибка распаковки Go"
        return 1
    }

    # Добавление Go в PATH
    if ! grep -q "export PATH.*go/bin" /etc/profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile
    fi

    export PATH=$PATH:/usr/local/go/bin

    rm -f "/tmp/${go_tarball}"
    log_success "Go успешно установлена"
}

# ============================================================================
# ФУНКЦИИ ИНТЕРАКТИВНОГО ВВОДА
# ============================================================================

prompt_admin_id() {
    local admin_id
    while true; do
        read -p "Введите Telegram ID администратора: " admin_id
        
        # Проверка что это число
        if [[ ${admin_id} =~ ^[0-9]+$ ]] && [[ ${#admin_id} -gt 5 ]]; then
            echo "${admin_id}"
            return 0
        else
            log_warning "Некорректный формат ID. Используйте только цифры (минимум 6 цифр)"
        fi
    done
}

prompt_bot_token() {
    local bot_token
    while true; do
        read -sp "Введите токен Telegram бота: " bot_token
        echo  # Новая строка после скрытого ввода
        
        # Проверка формата токена (примерно: 123456789:ABCDEfghijklmnopqrstuvwxyz)
        if [[ ${bot_token} =~ ^[0-9]{9,10}:[A-Za-z0-9_-]{35,}$ ]]; then
            echo "${bot_token}"
            return 0
        else
            log_warning "Некорректный формат токена. Используйте токен из @BotFather"
        fi
    done
}

prompt_server_ip() {
    local server_ip
    read -p "Введите IP-адрес сервера [автоопределение]: " server_ip
    
    if [[ -z "${server_ip}" ]]; then
        # Автоопределение IP
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "${server_ip}" ]]; then
            server_ip="127.0.0.1"
        fi
    fi
    
    echo "${server_ip}"
}

prompt_vpn_port() {
    local vpn_port="51820"
    read -p "Введите порт для AmneziaWG [${vpn_port}]: " port_input
    
    if [[ -z "${port_input}" ]]; then
        echo "${vpn_port}"
    else
        if [[ ${port_input} =~ ^[0-9]+$ ]] && [[ ${port_input} -gt 1024 ]] && [[ ${port_input} -lt 65535 ]]; then
            echo "${port_input}"
        else
            log_warning "Некорректный порт, используется ${vpn_port}"
            echo "${vpn_port}"
        fi
    fi
}

collect_config() {
    log_info "╔════════════════════════════════════════════════════════════╗"
    log_info "║  Конфигурация AWG Bot + AmneziaWG VPN                      ║"
    log_info "╚════════════════════════════════════════════════════════════╝"
    echo
    
    local admin_id=$(prompt_admin_id)
    local bot_token=$(prompt_bot_token)
    local server_ip=$(prompt_server_ip)
    local vpn_port=$(prompt_vpn_port)
    
    # Вывод подтверждения
    echo
    log_info "Проверьте введённые данные:"
    echo "  📱 Admin ID: ${admin_id}"
    echo "  🤖 Bot Token: ${bot_token:0:20}..."
    echo "  🌐 Server IP: ${server_ip}"
    echo "  🔌 VPN Port: ${vpn_port}"
    echo
    
    read -p "Данные корректны? (y/n): " confirm
    if [[ "${confirm}" != "y" ]]; then
        log_warning "Установка отменена"
        exit 1
    fi
    
    # Сохранение в глобальные переменные
    ADMIN_ID="${admin_id}"
    BOT_TOKEN="${bot_token}"
    SERVER_IP="${server_ip}"
    VPN_PORT="${vpn_port}"
}

# ============================================================================
# ФУНКЦИИ ПОДГОТОВКИ СИСТЕМЫ
# ============================================================================

create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p "${INSTALL_DIR}" || log_error "Ошибка при создании ${INSTALL_DIR}"
    mkdir -p "${BACKUP_DIR}" || log_error "Ошибка при создании ${BACKUP_DIR}"
    mkdir -p "/var/log/awg-bot" || log_error "Ошибка при создании лог-директории"
    mkdir -p "${AWG_CONFIG_DIR}" || log_error "Ошибка при создании конфига AmneziaWG"
    
    log_success "Директории созданы"
}

# ============================================================================
# УСТАНОВКА AMNEZIAWG
# ============================================================================

install_amneziawg() {
    log_info "Начало установки AmneziaWG..."
    
    local awg_build_dir="${INSTALL_DIR}/amneziawg-go"
    
    if [[ -d "${awg_build_dir}" ]]; then
        log_warning "Директория AmneziaWG уже существует, обновление..."
        cd "${awg_build_dir}"
        git pull origin main -q 2>/dev/null || log_warning "Ошибка при обновлении репозитория"
    else
        log_info "Клонирование репозитория AmneziaWG..."
        git clone --depth 1 "${AWG_REPO}" "${awg_build_dir}" 2>&1 | tee -a "${LOG_FILE}" || {
            log_error "Ошибка при клонировании AmneziaWG"
            return 1
        }
    fi
    
    cd "${awg_build_dir}"
    
    log_info "Компиляция AmneziaWG..."
    if ! make 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Ошибка при компиляции AmneziaWG"
        return 1
    fi
    
    # Установка бинарника
    log_info "Копирование бинарника..."
    if [[ -f "amneziawg-go" ]]; then
        cp "amneziawg-go" "/usr/local/bin/amneziawg-go"
        chmod +x "/usr/local/bin/amneziawg-go"
    else
        log_error "Бинарник amneziawg-go не найден"
        return 1
    fi
    
    log_success "AmneziaWG успешно установлена"
}

configure_amneziawg_systemd() {
    log_info "Создание systemd-сервиса для AmneziaWG интерфейса..."
    
    cat > "/etc/systemd/system/amnezia-interface.service" << 'EOF'
[Unit]
Description=AmneziaWG Interface awg0
Before=network-online.target awg-bot.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/amneziawg-go awg0
Restart=on-failure
RestartSec=5s
StartLimitInterval=60s
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=awg-interface

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "/etc/systemd/system/amnezia-interface.service"
    
    # Перезагрузка systemd
    systemctl daemon-reload
    
    # Включение в автозагрузку
    systemctl enable amnezia-interface.service || log_warning "Ошибка при включении amnezia-interface в автозагрузку"
    
    # Запуск сервиса
    systemctl start amnezia-interface.service || log_warning "Ошибка при запуске amnezia-interface"
    
    sleep 2
    
    # Проверка статуса
    if systemctl is-active --quiet amnezia-interface.service; then
        log_success "Сервис amnezia-interface успешно запущен"
    else
        log_warning "Сервис amnezia-interface может не запуститься сразу"
    fi
}

# ============================================================================
# УСТАНОВКА AWG BOT
# ============================================================================

install_awg_bot() {
    log_info "Начало установки AWG Bot..."
    
    local bot_dir="${INSTALL_DIR}/AWG_Bot2.0"
    
    if [[ -d "${bot_dir}" ]]; then
        log_warning "Директория бота уже существует, обновление..."
        cd "${bot_dir}"
        git pull origin main -q 2>/dev/null || log_warning "Ошибка при обновлении репозитория"
    else
        log_info "Клонирование репозитория AWG Bot..."
        git clone "${BOT_REPO}" "${bot_dir}" 2>&1 | tee -a "${LOG_FILE}" || {
            log_error "Ошибка при клонировании AWG Bot"
            return 1
        }
    fi
    
    cd "${bot_dir}"
    
    log_info "Создание виртуального окружения Python..."
    python3 -m venv "${VENV_PATH}" || {
        log_error "Ошибка при создании venv"
        return 1
    }
    
    log_info "Установка зависимостей Python..."
    source "${VENV_PATH}/bin/activate"
    
    # Обновление pip
    pip install --upgrade pip setuptools wheel -q 2>/dev/null || log_warning "Проблема с обновлением pip"
    
    if [[ -f "${bot_dir}/requirements.txt" ]]; then
        pip install -r "${bot_dir}/requirements.txt" -q 2>/dev/null || {
            log_error "Ошибка при установке зависимостей Python"
            return 1
        }
    else
        log_warning "requirements.txt не найден, установка базовых пакетов"
        pip install python-telegram-bot -q 2>/dev/null || log_warning "Проблема с установкой python-telegram-bot"
    fi
    
    deactivate
    
    log_success "AWG Bot успешно установлен"
}

# ============================================================================
# КОНФИГУРИРОВАНИЕ
# ============================================================================

configure_bot() {
    log_info "Конфигурирование AWG Bot..."
    
    local bot_dir="${INSTALL_DIR}/AWG_Bot2.0"
    
    # Создание .env файла с правильными путями
    cat > "${bot_dir}/.env" << EOF
# AWG Bot Configuration
# Сгенерировано автоустановщиком ${TIMESTAMP}

# Telegram Bot Token
BOT_TOKEN=${BOT_TOKEN}

# Administrator Telegram ID
ADMIN_ID=${ADMIN_ID}

# Server Configuration
SERVER_IP=${SERVER_IP}
VPN_PORT=${VPN_PORT}

# Database
DB_PATH=${bot_dir}/data/bot.db

# Logging
LOG_LEVEL=INFO
LOG_FILE=/var/log/awg-bot/bot.log

# AmneziaWG Configuration
AWG_CONFIG_PATH=${AWG_CONFIG_DIR}
AWG_BIN_PATH=/usr/local/bin/amneziawg-go
EOF

    chmod 600 "${bot_dir}/.env"
    
    # Создание директории для данных
    mkdir -p "${bot_dir}/data"
    chmod 700 "${bot_dir}/data"
    
    log_success "Конфигурирование завершено"
}

configure_systemd() {
    log_info "Создание systemd-юнита для бота..."
    
    local bot_dir="${INSTALL_DIR}/AWG_Bot2.0"
    
    cat > "/etc/systemd/system/awg-bot.service" << 'EOF'
[Unit]
Description=AmneziaWG Telegram Management Bot
After=network.target amnezia-interface.service
Wants=network-online.target
Requires=amnezia-interface.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=BOTDIR
Environment="PATH=VENVPATH/bin"
ExecStart=VENVPATH/bin/python main.py
ExecReload=/bin/kill -HUP $MAINPID

# Restart Policy
Restart=on-failure
RestartSec=10s
StartLimitInterval=60s
StartLimitBurst=3

# Security
PrivateTmp=yes
NoNewPrivileges=yes

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=awg-bot

[Install]
WantedBy=multi-user.target
EOF

    # Замена переменных
    sed -i "s|BOTDIR|${bot_dir}|g" "/etc/systemd/system/awg-bot.service"
    sed -i "s|VENVPATH|${VENV_PATH}|g" "/etc/systemd/system/awg-bot.service"
    
    # Перезагрузка systemd
    systemctl daemon-reload
    
    log_success "systemd-юнит создан: /etc/systemd/system/awg-bot.service"
}

# ============================================================================
# ЗАПУСК СЕРВИСОВ
# ============================================================================

start_services() {
    log_info "Запуск сервисов..."
    
    # Включение в автозагрузку
    systemctl enable awg-bot.service || log_error "Ошибка при включении в автозагрузку"
    
    # Запуск сервиса
    systemctl start awg-bot.service || log_error "Ошибка при запуске сервиса"
    
    # Проверка статуса
    sleep 3
    if systemctl is-active --quiet awg-bot.service; then
        log_success "Сервис awg-bot успешно запущен"
    else
        log_warning "Сервис awg-bot может не запуститься сразу, проверьте логи"
        systemctl status awg-bot.service 2>&1 | tee -a "${LOG_FILE}" || true
    fi
}

# ============================================================================
# ТЕСТИРОВАНИЕ
# ============================================================================

test_installation() {
    log_info "Тестирование установки..."
    
    local errors=0
    
    # Проверка бинарника AmneziaWG
    if command -v amneziawg-go &> /dev/null; then
        log_success "✓ AmneziaWG бинарник доступен"
    else
        log_error "✗ AmneziaWG бинарник не найден"
        ((errors++))
    fi
    
    # Проверка интерфейса awg0
    if ip link show awg0 &>/dev/null; then
        log_success "✓ Интерфейс awg0 активен"
    else
        log_warning "⚠ Интерфейс awg0 еще не создан (может создаться позже)"
    fi
    
    # Проверка сервиса amnezia-interface
    if [[ -f "/etc/systemd/system/amnezia-interface.service" ]]; then
        log_success "✓ Сервис amnezia-interface создан"
    else
        log_error "✗ Сервис amnezia-interface не найден"
        ((errors++))
    fi
    
    # Проверка виртуального окружения Python
    if [[ -d "${VENV_PATH}" ]]; then
        log_success "✓ Python venv создано"
    else
        log_error "✗ Python venv не найдено"
        ((errors++))
    fi
    
    # Проверка конфига бота
    local bot_dir="${INSTALL_DIR}/AWG_Bot2.0"
    if [[ -f "${bot_dir}/.env" ]]; then
        log_success "✓ Конфигурация бота создана"
    else
        log_error "✗ Конфигурация бота не найдена"
        ((errors++))
    fi
    
    # Проверка файла systemd-сервиса бота
    if [[ -f "/etc/systemd/system/awg-bot.service" ]]; then
        log_success "✓ Сервис awg-bot зарегистрирован"
    else
        log_error "✗ Сервис awg-bot не найден"
        ((errors++))
    fi
    
    # Проверка директории конфигов AmneziaWG
    if [[ -d "${AWG_CONFIG_DIR}" ]]; then
        log_success "✓ Конфигурационная директория AmneziaWG создана"
    else
        log_error "✗ Конфигурационная директория AmneziaWG не найдена"
        ((errors++))
    fi
    
    return ${errors}
}

# ============================================================================
# ВЫВОД ИНФОРМАЦИИ ПОСЛЕ УСТАНОВКИ
# ============================================================================

print_summary() {
    echo
    log_info "╔════════════════════════════════════════════════════════════╗"
    log_info "║           ✓ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА                    ║"
    log_info "╚════════════════════════════════════════════════════════════╝"
    echo
    echo "📋 Информация об установке:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📁 Директория установки: ${INSTALL_DIR}"
    echo "  🤖 AWG Bot: ${INSTALL_DIR}/AWG_Bot2.0"
    echo "  🔐 AmneziaWG: /usr/local/bin/amneziawg-go"
    echo "  ⚙️  Конфигурация: ${AWG_CONFIG_DIR}"
    echo "  📜 Логи: /var/log/awg-bot/bot.log"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "🔧 Полезные команды:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  # Статус всех сервисов"
    echo "  sudo systemctl status amnezia-interface.service awg-bot.service"
    echo
    echo "  # Просмотр логов интерфейса AmneziaWG"
    echo "  sudo journalctl -u amnezia-interface.service -f"
    echo
    echo "  # Просмотр логов бота в реальном времени"
    echo "  sudo journalctl -u awg-bot.service -f"
    echo
    echo "  # Перезагрузка обоих сервисов"
    echo "  sudo systemctl restart amnezia-interface.service awg-bot.service"
    echo
    echo "  # Просмотр полного лога установки"
    echo "  cat ${LOG_FILE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "🌐 Дополнительно:"
    echo "  • Интерфейс AmneziaWG управляется отдельным systemd-сервисом"
    echo "  • Бот автоматически запустится после создания интерфейса"
    echo "  • Оба сервиса настроены на автозапуск при перезагрузке"
    echo "  • Все логи записываются в journalctl"
    echo "  • При сбое сервисы автоматически перезагружаются"
    echo
}

# ============================================================================
# ОБРАБОТКА ОШИБОК
# ============================================================================

cleanup_on_error() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Установка прервана с кодом ошибки ${exit_code}"
        
        echo
        log_error "╔════════════════════════════════════════════════════════════╗"
        log_error "║           ✗ УСТАНОВКА ЗАВЕРШЕНА С ОШИБКОЙ                 ║"
        log_error "╚════════════════════════════════════════════════════════════╝"
        echo
        log_warning "Для диагностики проверьте лог-файл:"
        echo "  cat ${LOG_FILE}"
        echo
    fi
    
    return ${exit_code}
}

trap cleanup_on_error EXIT

# ============================================================================
# ОСНОВНАЯ ФУНКЦИЯ УСТАНОВКИ
# ============================================================================

main() {
    # Инициализация лог-файла
    mkdir -p "$(dirname "${LOG_FILE}")"
    : > "${LOG_FILE}"
    
    echo
    log_info "╔════════════════════════════════════════════════════════════╗"
    log_info "║     AWG Bot + AmneziaWG VPN - Скрипт установки v2.3       ║"
    log_info "╚════════════════════════════════════════════════════════════╝"
    echo
    
    # Основные проверки
    check_root
    check_os
    check_disk_space
    
    # Сбор конфигурации
    collect_config
    
    # Установка компонентов
    log_info "Начало установки компонентов..."
    create_directories
    install_dependencies
    install_golang
    install_amneziawg
    configure_amneziawg_systemd
    install_awg_bot
    
    # Конфигурирование
    configure_bot
    configure_systemd
    
    # Запуск
    start_services
    
    # Тестирование
    test_installation
    
    # Вывод информации
    trap - EXIT  # Удаление trap'а для успешного завершения
    print_summary
    
    return 0
}

# ============================================================================
# ТОЧКА ВХОДА
# ============================================================================

main "$@"

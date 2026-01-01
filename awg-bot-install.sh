#!/bin/bash

################################################################################
# AWG Bot 2.0 + AmneziaWG Auto-Installer Script (IMPROVED)
#
# Этот скрипт автоматически устанавливает и настраивает:
# - AmneziaWG VPN Server (с управлением клиентами)
# - AWG Bot 2.0 (Telegram бот для управления VPN)
# - Systemd сервис для автозагрузки
#
# Поддержка: Ubuntu 22.04+, Debian 11+
# Автор: svod011929
# GitHub: https://github.com/svod011929/awg-bot-installer
# Лицензия: MIT
#
# Использование: sudo bash awg-bot-install.sh
################################################################################

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ЦВЕТА И СТИЛИ ДЛЯ ВЫВОДА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ПЕРЕМЕННЫЕ КОНФИГУРАЦИИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_REPO="https://github.com/JB-SelfCompany/AWG_Bot2.0.git"
BOT_DIR="/opt/awg-bot"
BOT_USER="awgbot"
BOT_SERVICE="awg-bot"
VENV_DIR="${BOT_DIR}/venv"
LOG_FILE="/var/log/awg-bot-install.log"

# Конфигурация AmneziaWG
AWG_INTERFACE="awg0"
AWG_PORT="42666"
AWG_SUBNET="10.10.8.0/24"
AWG_CONFIG_DIR="/etc/amnezia/amneziawg"

# Переменные для отслеживания прогресса
TOTAL_STEPS=15
CURRENT_STEP=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ФУНКЦИИ ЛОГИРОВАНИЯ И ВЫВОДА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
  echo -e "${GREEN}✔${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
  echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"
}

error() {
  echo -e "${RED}✖${NC} $*" | tee -a "$LOG_FILE" >&2
}

die() {
  error "$*"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 1
}

step() {
  ((CURRENT_STEP++))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "\n${CYAN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $(printf '%3d%%' $percent) $*"
}

progress_bar() {
  local current=$1
  local total=$2
  local width=30
  local percent=$((current * 100 / total))
  local filled=$((current * width / total))
  
  printf "\r${CYAN}["
  printf "%${filled}s" | tr ' ' '='
  printf "%$((width - filled))s" | tr ' ' '-'
  printf "] ${YELLOW}${percent}%%${NC}"
}

divider() {
  echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ПРОВЕРКИ СИСТЕМЫ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_root() {
  step "Проверка прав доступа"
  if [[ $EUID -ne 0 ]]; then
    die "Скрипт должен выполняться от root (используйте: sudo bash awg-bot-install.sh)"
  fi
  success "Обнаружены привилегии root"
}

check_os() {
  step "Определение операционной системы"
  
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    
    case "$OS" in
      ubuntu)
        if [[ $(echo "$VER >= 22.04" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
          success "Ubuntu $VER обнаружена"
        else
          die "Требуется Ubuntu 22.04 или выше, обнаружена версия $VER"
        fi
        ;;
      debian)
        if [[ $(echo "$VER >= 11" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
          success "Debian $VER обнаружена"
        else
          die "Требуется Debian 11 или выше, обнаружена версия $VER"
        fi
        ;;
      *)
        warning "Неизвестная или неподдерживаемая ОС: $OS (установка может не работать корректно)"
        ;;
    esac
  else
    die "Не удалось определить версию ОС"
  fi
}

check_internet() {
  step "Проверка подключения к интернету"
  
  if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    die "Нет доступа в интернет. Проверьте подключение и повторите попытку."
  fi
  success "Интернет-соединение проверено"
}

get_default_interface() {
  ip route | grep default | awk '{print $5}' | head -n 1
}

check_port_available() {
  local port=$1
  
  if ss -tulpn 2>/dev/null | grep -q ":$port "; then
    warning "Порт $port уже используется другим сервисом"
    return 1
  else
    success "Порт $port доступен"
    return 0
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ОБНОВЛЕНИЕ И УСТАНОВКА ЗАВИСИМОСТЕЙ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

update_system() {
  step "Обновление списка пакетов"
  
  apt-get update -y || die "Не удалось обновить список пакетов"
  success "Список пакетов обновлён"
  
  step "Обновление системы"
  
  read -p "Обновить все пакеты системы? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || die "Не удалось обновить систему"
    success "Пакеты обновлены"
  else
    warning "Обновление системы пропущено"
  fi
}

install_dependencies() {
  step "Установка системных зависимостей"
  
  local packages=(
    "curl"
    "wget"
    "git"
    "python3"
    "python3-pip"
    "python3-venv"
    "build-essential"
    "linux-headers-$(uname -r)"
    "iproute2"
    "bc"
    "systemd"
  )
  
  local to_install=()
  
  for package in "${packages[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package"; then
      to_install+=("$package")
    fi
  done
  
  if [[ ${#to_install[@]} -gt 0 ]]; then
    log "Установка пакетов: ${to_install[*]}"
    apt-get install -y "${to_install[@]}" || die "Не удалось установить зависимости"
  fi
  
  success "Все зависимости установлены"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# УСТАНОВКА И КОНФИГУРАЦИЯ AMNEZIAWG
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

install_amneziawg() {
  step "Установка AmneziaWG VPN"
  
  # Проверяем, установлен ли уже
  if command -v awg &>/dev/null; then
    success "AmneziaWG уже установлен"
    return 0
  fi
  
  # Пытаемся добавить PPA для Ubuntu
  if [[ "$OS" == "ubuntu" ]]; then
    log "Попытка добавления PPA AmneziaWG..."
    if command -v add-apt-repository &>/dev/null; then
      add-apt-repository -y ppa:amnezia/ppa &>/dev/null || warning "Не удалось добавить PPA"
      apt-get update -y || warning "Не удалось обновить список пакетов"
    fi
  fi
  
  if apt-get install -y amneziawg &>/dev/null; then
    success "AmneziaWG установлен"
  else
    die "Не удалось установить AmneziaWG. Убедитесь, что репозиторий доступен."
  fi
  
  # Загружаем модуль ядра
  if modprobe amneziawg 2>/dev/null; then
    success "Модуль ядра amneziawg загружен"
  else
    warning "Не удалось загрузить модуль amneziawg (это может быть нормально на некоторых системах)"
  fi
}

configure_amneziawg() {
  step "Конфигурация AmneziaWG"
  
  local OUTGOING_INTERFACE=$(get_default_interface)
  
  if [[ -z "$OUTGOING_INTERFACE" ]]; then
    OUTGOING_INTERFACE="eth0"
    warning "Не удалось автоматически определить интерфейс выхода, используется $OUTGOING_INTERFACE"
  else
    success "Определён интерфейс выхода: $OUTGOING_INTERFACE"
  fi
  
  # Включаем IP forwarding
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/00-amnezia.conf
  sysctl -p /etc/sysctl.d/00-amnezia.conf > /dev/null 2>&1
  success "IP forwarding включён"
  
  # Создаём директорию конфигурации
  mkdir -p "$AWG_CONFIG_DIR"
  chmod 700 "$AWG_CONFIG_DIR"
  
  # Проверяем наличие конфигурации
  if [[ -f "$AWG_CONFIG_DIR/${AWG_INTERFACE}.conf" ]]; then
    warning "Конфигурация AmneziaWG уже существует"
    return 0
  fi
  
  # Генерируем ключи и конфигурацию
  log "Генерация ключей и конфигурации..."
  
  local server_private=$(wg genkey)
  local server_public=$(echo "$server_private" | wg pubkey)
  
  # Создаём конфиг-файл
  cat > "$AWG_CONFIG_DIR/${AWG_INTERFACE}.conf" << EOF
[Interface]
PrivateKey = $server_private
Address = ${AWG_SUBNET}
ListenPort = $AWG_PORT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $OUTGOING_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $OUTGOING_INTERFACE -j MASQUERADE
EOF
  
  chmod 600 "$AWG_CONFIG_DIR/${AWG_INTERFACE}.conf"
  success "Конфигурация AmneziaWG создана"
}

start_amneziawg() {
  step "Запуск сервиса AmneziaWG"
  
  if systemctl enable --now awg-quick@${AWG_INTERFACE} 2>/dev/null; then
    sleep 2
    
    if awg show ${AWG_INTERFACE} &>/dev/null; then
      success "Сервис AmneziaWG запущен и проверен"
    else
      warning "Сервис запущен, но не смог провести проверку интерфейса"
    fi
  else
    warning "Не удалось запустить сервис AmneziaWG"
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# УСТАНОВКА И КОНФИГУРАЦИЯ БОТА
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_bot_user() {
  step "Создание системного пользователя для бота"
  
  if ! id "$BOT_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d "$BOT_DIR" "$BOT_USER" || die "Не удалось создать пользователя $BOT_USER"
    success "Пользователь $BOT_USER создан"
  else
    success "Пользователь $BOT_USER уже существует"
  fi
}

clone_bot_repo() {
  step "Клонирование репозитория AWG Bot"
  
  if [[ -d "$BOT_DIR" ]]; then
    warning "Директория $BOT_DIR уже существует"
    
    if [[ -d "$BOT_DIR/.git" ]]; then
      log "Обновление репозитория..."
      cd "$BOT_DIR"
      git pull origin main 2>/dev/null || warning "Не удалось обновить репозиторий"
    fi
  else
    mkdir -p "$BOT_DIR"
    git clone "$BOT_REPO" "$BOT_DIR" || die "Не удалось клонировать репозиторий"
    success "Репозиторий клонирован"
  fi
}

setup_python_venv() {
  step "Подготовка Python окружения"
  
  cd "$BOT_DIR"
  
  # Создаём виртуальное окружение
  python3 -m venv "$VENV_DIR" || die "Не удалось создать виртуальное окружение"
  success "Виртуальное окружение создано"
  
  # Активируем и обновляем pip
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  
  "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel &>/dev/null || warning "Не удалось обновить pip"
  
  # Устанавливаем зависимости
  if [[ -f "$BOT_DIR/requirements.txt" ]]; then
    log "Установка зависимостей из requirements.txt..."
    "$VENV_DIR/bin/pip" install -r "$BOT_DIR/requirements.txt" 2>&1 | grep -i "error" && warning "Некоторые зависимости не установлены" || success "Зависимости установлены"
  else
    warning "requirements.txt не найден, установка базовых зависимостей..."
    "$VENV_DIR/bin/pip" install python-telegram-bot aiohttp pydantic python-dotenv 2>/dev/null || warning "Не удалось установить зависимости"
  fi
  
  deactivate 2>/dev/null || true
  success "Python окружение подготовлено"
}

setup_bot_config() {
  step "Подготовка конфигурации бота"
  
  local env_file="$BOT_DIR/.env"
  
  if [[ -f "$env_file" ]]; then
    warning "Файл конфигурации уже существует"
    warning "Пожалуйста, отредактируйте $env_file и добавьте токен бота"
    return 0
  fi
  
  # Создаём шаблон .env
  cat > "$env_file" << 'EOF'
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Конфигурация AWG Bot 2.0
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Telegram Bot Token
# Получить у: https://t.me/BotFather
BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN_HERE

# Telegram ID администратора
# Узнать свой ID: https://t.me/userinfobot
ADMIN_ID=YOUR_TELEGRAM_ADMIN_ID_HERE

# Конфигурация AmneziaWG
AWG_INTERFACE=awg0
AWG_CONFIG_PATH=/etc/amnezia/amneziawg/awg0.conf
AWG_PORT=42666

# База данных (опционально)
# DATABASE_URL=sqlite:///./awg_bot.db

# Логирование
LOG_LEVEL=INFO

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ВАЖНО: Никогда не добавляйте этот файл в Git!
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
  
  chmod 600 "$env_file"
  chown "$BOT_USER:$BOT_USER" "$env_file"
  
  warning "Создан шаблон конфигурации в $env_file"
  warning "ВАЖНО: Отредактируйте этот файл и добавьте свои данные перед запуском бота!"
}

fix_bot_permissions() {
  step "Установка прав доступа"
  
  chown -R "$BOT_USER:$BOT_USER" "$BOT_DIR"
  chmod -R 755 "$BOT_DIR"
  chmod 600 "$BOT_DIR/.env" 2>/dev/null || true
  
  # Разрешаем боту читать конфиги AWG
  setfacl -m u:$BOT_USER:rx /etc/amnezia 2>/dev/null || {
    warning "setfacl недоступен, используем альтернативный способ..."
    usermod -a -G root "$BOT_USER" 2>/dev/null || true
  }
  
  success "Права доступа установлены"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SYSTEMD СЕРВИС
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_systemd_service() {
  step "Создание systemd сервиса"
  
  local service_file="/etc/systemd/system/${BOT_SERVICE}.service"
  
  cat > "$service_file" << EOF
[Unit]
Description=AmneziaWG Telegram Management Bot
Documentation=https://github.com/JB-SelfCompany/AWG_Bot2.0
After=network-online.target awg-quick@${AWG_INTERFACE}.service
Wants=network-online.target

[Service]
Type=simple
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=$VENV_DIR/bin/python main.py
Environment="PYTHONUNBUFFERED=1"
EnvironmentFile=-$BOT_DIR/.env
Restart=on-failure
RestartSec=10s
StartLimitInterval=60s
StartLimitBurst=3

# Безопасность
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$BOT_DIR /etc/amnezia

# Логирование
StandardOutput=journal
StandardError=journal
SyslogIdentifier=awg-bot

[Install]
WantedBy=multi-user.target
EOF
  
  chmod 644 "$service_file"
  systemctl daemon-reload
  
  success "Systemd сервис создан"
}

start_bot_service() {
  step "Запуск сервиса бота"
  
  # Проверяем, настроена ли конфигурация
  if grep -q "YOUR_TELEGRAM_BOT_TOKEN" "$BOT_DIR/.env"; then
    warning "Конфигурация бота не завершена (.env не настроена)"
    warning "Сервис не запущен. Пожалуйста:"
    warning "  1. Отредактируйте: sudo nano $BOT_DIR/.env"
    warning "  2. Добавьте токен бота и ID администратора"
    warning "  3. Запустите: sudo systemctl start $BOT_SERVICE"
  else
    if systemctl enable "$BOT_SERVICE" 2>/dev/null; then
      systemctl start "$BOT_SERVICE" 2>/dev/null || warning "Не удалось запустить сервис (проверьте логи)"
      success "Сервис бота запущен"
    else
      warning "Не удалось включить сервис в автозагрузку"
    fi
  fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ВЕРИФИКАЦИЯ И ИТОГИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

verify_installation() {
  step "Проверка установки"
  
  local errors=0
  
  # Проверяем AmneziaWG
  if ! awg show ${AWG_INTERFACE} &>/dev/null; then
    error "Интерфейс AmneziaWG ${AWG_INTERFACE} не найден"
    ((errors++))
  else
    success "Интерфейс AmneziaWG активен"
  fi
  
  # Проверяем директорию бота
  if [[ ! -d "$BOT_DIR" ]]; then
    error "Директория бота не найдена: $BOT_DIR"
    ((errors++))
  else
    success "Директория бота существует"
  fi
  
  # Проверяем Python окружение
  if [[ ! -f "$VENV_DIR/bin/python" ]]; then
    error "Python окружение не найдено"
    ((errors++))
  else
    success "Python окружение готово"
  fi
  
  # Проверяем systemd сервис
  if ! systemctl list-unit-files | grep -q "$BOT_SERVICE"; then
    error "Systemd сервис не найден"
    ((errors++))
  else
    success "Systemd сервис зарегистрирован"
  fi
  
  return $errors
}

show_summary() {
  echo
  divider
  echo -e "${GREEN}${BOLD}   ✔ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА${NC}"
  divider
  echo
  
  echo -e "${CYAN}Параметры AmneziaWG:${NC}"
  echo -e "  ${DIM}•${NC} Интерфейс: ${BOLD}$AWG_INTERFACE${NC}"
  echo -e "  ${DIM}•${NC} Конфиг: ${BOLD}$AWG_CONFIG_DIR/${AWG_INTERFACE}.conf${NC}"
  echo -e "  ${DIM}•${NC} Подсеть: ${BOLD}$AWG_SUBNET${NC}"
  echo -e "  ${DIM}•${NC} Порт: ${BOLD}$AWG_PORT${NC}"
  echo
  
  echo -e "${CYAN}Параметры бота:${NC}"
  echo -e "  ${DIM}•${NC} Каталог: ${BOLD}$BOT_DIR${NC}"
  echo -e "  ${DIM}•${NC} Пользователь: ${BOLD}$BOT_USER${NC}"
  echo -e "  ${DIM}•${NC} Сервис: ${BOLD}$BOT_SERVICE${NC}"
  echo -e "  ${DIM}•${NC} Конфиг: ${BOLD}$BOT_DIR/.env${NC}"
  echo
  
  echo -e "${YELLOW}${BOLD}Следующие шаги:${NC}"
  echo
  echo -e "  ${BOLD}1. Откройте конфигурацию бота:${NC}"
  echo -e "     ${DIM}\$${NC} ${BOLD}sudo nano $BOT_DIR/.env${NC}"
  echo
  echo -e "  ${BOLD}2. Укажите токен бота и ID администратора.${NC}"
  echo
  echo -e "  ${BOLD}3. Запустите/перезагрузите сервис:${NC}"
  echo -e "     ${DIM}\$${NC} ${BOLD}sudo systemctl restart $BOT_SERVICE${NC}"
  echo
  echo -e "  ${BOLD}4. Проверьте статус:${NC}"
  echo -e "     ${DIM}\$${NC} ${BOLD}sudo systemctl status $BOT_SERVICE${NC}"
  echo
  echo -e "  ${BOLD}5. Просмотрите логи:${NC}"
  echo -e "     ${DIM}\$${NC} ${BOLD}sudo journalctl -u $BOT_SERVICE -f${NC}"
  echo
  
  echo -e "${CYAN}Полезные команды:${NC}"
  echo -e "  ${DIM}•${NC} Управление AmneziaWG: ${BOLD}sudo awg show${NC}"
  echo -e "  ${DIM}•${NC} Проверка портов: ${BOLD}sudo ss -tulpn | grep $AWG_PORT${NC}"
  echo -e "  ${DIM}•${NC} Логи установки: ${BOLD}tail -100 $LOG_FILE${NC}"
  echo
  
  divider
  echo -e "${MAGENTA}Лог установки сохранён в: ${BOLD}$LOG_FILE${NC}"
  divider
  echo
}

show_error_summary() {
  echo
  divider
  echo -e "${RED}${BOLD}   ✖ УСТАНОВКА ЗАВЕРШЕНА С ОШИБКАМИ${NC}"
  divider
  echo
  
  echo -e "${YELLOW}Некоторые проверки не пройдены. Проверьте логи:${NC}"
  echo -e "  ${DIM}\$${NC} ${BOLD}tail -50 $LOG_FILE${NC}"
  echo
  
  echo -e "${YELLOW}Для AmneziaWG:${NC}"
  echo -e "  ${DIM}\$${NC} ${BOLD}sudo journalctl -u awg-quick@${AWG_INTERFACE} -n 50${NC}"
  echo
  
  echo -e "${YELLOW}Для бота:${NC}"
  echo -e "  ${DIM}\$${NC} ${BOLD}sudo journalctl -u $BOT_SERVICE -n 50${NC}"
  echo
  
  divider
}

show_banner() {
  clear
  echo -e "${MAGENTA}"
  cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║          AWG Bot 2.0 + AmneziaWG Auto-Installer             ║
║                      Версия 2.0 (Улучшенная)                ║
╠════════════════════════════════════════════════════════════════╣
║  Этот скрипт установит и настроит:                           ║
║   • AmneziaWG VPN Server (с управлением клиентами)          ║
║   • AWG Bot 2.0 (Telegram бот для управления VPN)           ║
║   • Systemd сервисы с автозагрузкой                         ║
╚════════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}"
  
  echo -e "${YELLOW}Требования:${NC}"
  echo -e "  ${DIM}•${NC} Root / sudo доступ"
  echo -e "  ${DIM}•${NC} Ubuntu 22.04+ или Debian 11+"
  echo -e "  ${DIM}•${NC} 512 МБ RAM"
  echo -e "  ${DIM}•${NC} 2 ГБ свободного места на диске"
  echo -e "  ${DIM}•${NC} Открытый UDP порт $AWG_PORT"
  echo -e "  ${DIM}•${NC} Активное интернет-подключение"
  echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ОСНОВНОЙ ПРОЦЕСС УСТАНОВКИ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  show_banner
  
  read -p "$(echo -e ${CYAN})Продолжить установку? (yes/no):$(echo -e ${NC}) " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}Установка отменена пользователем.${NC}"
    exit 0
  fi
  
  # Инициализируем лог-файл
  > "$LOG_FILE"
  
  log "═════════════════════════════════════════════════════════════════"
  log "Начало установки AWG Bot 2.0 + AmneziaWG"
  log "Пользователь: $SUDO_USER"
  log "Дата: $(date)"
  log "═════════════════════════════════════════════════════════════════"
  
  # Запускаем все шаги установки
  check_root
  check_os
  check_internet
  check_port_available "$AWG_PORT"
  
  update_system
  install_dependencies
  
  install_amneziawg
  configure_amneziawg
  start_amneziawg
  
  create_bot_user
  clone_bot_repo
  setup_python_venv
  setup_bot_config
  fix_bot_permissions
  
  create_systemd_service
  start_bot_service
  
  # Верификация и итоги
  if verify_installation; then
    show_summary
    success "Установка завершена успешно!"
    exit 0
  else
    show_error_summary
    warning "Установка завершена с некоторыми ошибками"
    exit 1
  fi
}

# Запускаем основную функцию
main "$@"

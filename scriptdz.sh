#!/bin/bash

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: Скрипт должен быть запущен с правами root (sudo)." >&2
    exit 1
fi

# Функция для валидации диапазона 0-255
validate_range() {
  local num="$1"
  local var_name="$2"  # Имя переменной для более информативного сообщения

  if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: \$$var_name должен быть числом." >&2
    return 1 # Не число
  fi

  if [[ "$num" -lt 0 || "$num" -gt 255 ]]; then
    echo "Ошибка: \$$var_name должен быть в диапазоне 0-255." >&2
    return 1 # Вне диапазона 0-255
  fi

  return 0
}

# Функция для валидации IP префикса
validate_prefix() {
    local prefix="$1"
    # Улучшенная проверка: 1-3 цифры, точка, повторяется 0-2 раза, затем 1-3 цифры
    if ! [[ "$prefix" =~ ^([0-9]{1,3}\.){0,2}[0-9]{1,3}$ ]]; then
      echo "Ошибка: Неверный формат префикса IP-адреса. (Пример: 192.168. или 10)" >&2
      return 1
    fi
    return 0
}

# Функция для валидации имени интерфейса
validate_interface() {
    local interface="$1"
    #  Более точная проверка имени интерфейса (буквы, цифры, точки, тире, подчеркивания)
    if ! [[ "$interface" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Ошибка: Неверный формат имени интерфейса. (Пример: eth0, wlan0)" >&2
        return 1
    fi
    return 0
}

# Обработка аргументов командной строки
PREFIX="$1"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"

# ===== Валидация параметров =====

# PREFIX
if [[ -z "$PREFIX" ]]; then
    echo "Ошибка: \$PREFIX должен быть передан в качестве первого аргумента." >&2
    exit 1
fi
if ! validate_prefix "$PREFIX"; then
    exit 1
fi

# INTERFACE
if [[ -z "$INTERFACE" ]]; then
    echo "Ошибка: \$INTERFACE должен быть передан в качестве второго аргумента." >&2
    exit 1
fi
if ! validate_interface "$INTERFACE"; then
    exit 1
fi

# SUBNET (если передан)
if [[ -n "$SUBNET" ]]; then
  if ! validate_range "$SUBNET" "SUBNET"; then
    exit 1
  fi
fi

# HOST (если передан)
if [[ -n "$HOST" ]]; then
  if ! validate_range "$HOST" "HOST"; then
    exit 1
  fi
fi

# ===== Настройка сканирования =====

SUBNET_START=1
SUBNET_END=255
HOST_START=1
HOST_END=255

if [[ -n "$SUBNET" ]]; then
    SUBNET_START="$SUBNET"
    SUBNET_END="$SUBNET"

    if [[ -n "$HOST" ]]; then
        HOST_START="$HOST"
        HOST_END="$HOST"
    fi
fi

# ===== Сканирование IP-адресов =====

echo "Начинаю сканирование IP-адресов..."

for SUBNET in $(seq "$SUBNET_START" "$SUBNET_END"); do
    for HOST in $(seq "$HOST_START" "$HOST_END"); do
        IP_ADDRESS="${PREFIX}.${SUBNET}.${HOST}"
        echo "[*] Проверяю IP: $IP_ADDRESS"
        if arping -c 3 -i "$INTERFACE" "$IP_ADDRESS" 2> /dev/null; then
            echo "   [+] IP $IP_ADDRESS активен"
        else
            echo "   [-] IP $IP_ADDRESS не отвечает"
        fi
    done
done

echo "Сканирование завершено."

exit 0

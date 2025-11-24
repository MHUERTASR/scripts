#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -f .env ]; then
  source .env
else
  echo "❌ Error: Archivo de configuración .env no encontrado."
  exit 1
fi

start_one_service() {
    local service_id=$1
    local service_name_upper
    service_name_upper=$(echo "$service_id" | tr 'a-z' 'A-Z')

    local dir_var="SERVICE_${service_name_upper}_DIR"
    local cmd_var="SERVICE_${service_name_upper}_COMMAND"
    local name_var="SERVICE_${service_name_upper}_NAME"

    local project_dir="${!dir_var}"
    local start_command="${!cmd_var}"
    local service_name="${!name_var:-$service_id}"

    if [ -z "$project_dir" ] || [ -z "$start_command" ]; then
        echo "❌ Error: No se encontró la configuración para el servicio '$service_id' en .env"
        return 1
    fi

    mkdir -p "$RUN_DIR"
    local pid_file="$RUN_DIR/$service_id.pid"
    local log_file="$RUN_DIR/$service_id.log"

    if [ -f "$pid_file" ]; then
        local pid_check
        pid_check=$(cat "$pid_file")
        if kill -0 "$pid_check" 2>/dev/null; then
            echo "⚠️  El servicio '$service_name' ya está corriendo (PID: $pid_check)."
            return 0
        else
            echo "🧹 Se encontró un PID huérfano ($pid_check). Limpiando..."
            rm "$pid_file"
        fi
    fi

    echo "🚀 Iniciando el servicio '$service_name'..."
    cd "$project_dir" || { echo "❌ Error: No se pudo cambiar al directorio $project_dir"; return 1; }
    
    # nohup bash -c "$start_command" 2>&1 | "$SCRIPT_DIR/logger.sh" "$log_file" &
    nohup bash -c "$start_command" < /dev/null 2>&1 | "$SCRIPT_DIR/logger.sh" "$log_file" &
    echo $! > "$pid_file"

    echo "✅ Servicio '$service_name' iniciado."
    echo "   - PID guardado en: $pid_file"
}

if [ -z "$1" ] || [ "$1" == "all" ]; then
    echo "🔎 Iniciando TODOS los servicios definidos en .env..."
    SERVICES=$(grep '^SERVICE_.*_DIR=' .env | sed 's/SERVICE_\(.*\)_DIR=.*/\1/' | tr 'A-Z' 'a-z')
    
    if [ -z "$SERVICES" ]; then
        echo "⚠️ No se encontraron servicios para iniciar."
        exit 0
    fi
    
    echo "------------------------------------------------"
    for id in $SERVICES; do
        start_one_service "$id"
        echo "⏳ Esperando 2s antes del siguiente servicio..."
        sleep 2
        echo "------------------------------------------------"
    done
    echo "✨ Proceso completado."
else
    start_one_service "$1"
fi
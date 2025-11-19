#!/bin/bash

if [ -f .env ]; then
  source .env
else
  echo "❌ Error: Archivo de configuración .env no encontrado."
  exit 1
fi

if ! command -v ss &> /dev/null; then
    echo "🔎 Comando 'ss' no encontrado. Intentando instalar 'iproute2'..."
    if command -v apt &> /dev/null; then
        apt update && apt install -y iproute2
    elif command -v yum &> /dev/null; then
        yum install -y iproute iproute-tc
    else
        echo "⚠️ No se pudo determinar el gestor de paquetes. Instala 'iproute2' manualmente."
    fi
    
    if ! command -v ss &> /dev/null; then
        echo "❌ Error: La instalación de 'iproute2' falló. El script no puede continuar."
        exit 1
    fi
    echo "✅ Dependencia 'iproute2' instalada."
fi

stop_one_service() {
    local service_id=$1
    local service_name_upper
    service_name_upper=$(echo "$service_id" | tr 'a-z' 'A-Z')

    local name_var="SERVICE_${service_name_upper}_NAME"
    local port_var="SERVICE_${service_name_upper}_PORT"
    local service_name="${!name_var:-$service_id}"
    local service_port="${!port_var}"
    local pid_file="$RUN_DIR/$service_id.pid"
    
    kill_process_safely() {
        local pid=$1
        echo "   ⏳ Enviando señal de parada a PID $pid..."
        kill "$pid" 2>/dev/null # SIGTERM (15) por defecto
        
        for i in {1..5}; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                echo "   ✅ Proceso $pid detenido suavemente."
                return 0
            fi
            sleep 1
        done

        echo "   ⚠️ El proceso $pid no responde. Forzando cierre (kill -9)..."
        kill -9 "$pid" 2>/dev/null
    }

    echo "🛑 Deteniendo el servicio '$service_name'..."
    local stopped=false

    if [ -n "$service_port" ] && command -v ss &> /dev/null; then
        local port_pid
        # Nota: grep -P puede no estar en todos los Linux mínimos, pero en Ubuntu/Debian va bien
        port_pid=$(ss -lntp "sport = :$service_port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -n 1)

        if [ -n "$port_pid" ]; then
            echo "   🔥 Proceso detectado en puerto $service_port."
            kill_process_safely "$port_pid"
            stopped=true
        fi
    fi

    if [ -f "$pid_file" ]; then
        local file_pid
        file_pid=$(cat "$pid_file")
        
        if ps -p "$file_pid" > /dev/null 2>&1; then
             # Solo intentar matar si es DIFERENTE al que acabamos de matar por puerto
             if [ "$file_pid" != "$port_pid" ]; then
                 echo "   📄 Proceso detectado por archivo PID."
                 kill_process_safely "$file_pid"
                 stopped=true
             fi
        fi
        rm "$pid_file"
    fi

    if [ "$stopped" = true ]; then
        echo "✅ Servicio '$service_name' detenido."
    else
        echo "zzz El servicio '$service_name' no parece estar activo."
    fi
}

if [ -z "$1" ] || [ "$1" == "all" ]; then
    echo "🔎 Deteniendo TODOS los servicios definidos en .env..."
    SERVICES=$(grep '^SERVICE_.*_DIR=' .env | sed 's/SERVICE_\(.*\)_DIR=.*/\1/' | tr 'A-Z' 'a-z')

    if [ -z "$SERVICES" ]; then
        echo "⚠️ No se encontraron servicios para detener."
        exit 0
    fi

    echo "------------------------------------------------"
    for id in $SERVICES; do
        stop_one_service "$id"
        echo "------------------------------------------------"
    done
    echo "✨ Proceso completado."
else
    stop_one_service "$1"
fi
#!/bin/bash

if [ -f .env ]; then
  source .env
else
  echo "❌ Error: Archivo de configuración .env no encontrado."
  exit 1
fi

if ! command -v ss &> /dev/null; then
    echo "❌ Error: Instala 'iproute2' (comando ss) para continuar."
    exit 1
fi

if [ -z "$PORTS_TO_CHECK" ]; then
    echo "🔍 Buscando variables que terminen en _PORT..."
    
    DETECTED_VARS=$(compgen -v | grep '_PORT$')
    
    PORTS_TO_CHECK=""
    
    for var_name in $DETECTED_VARS; do
        port_val="${!var_name}"
        
        if [[ "$port_val" =~ ^[0-9]+$ ]]; then
            if [ -z "$PORTS_TO_CHECK" ]; then
                PORTS_TO_CHECK="$port_val"
            else
                PORTS_TO_CHECK="$PORTS_TO_CHECK,$port_val"
            fi
            echo "   > Encontrado: $var_name = $port_val"
        fi
    done
    
    if [ -z "$PORTS_TO_CHECK" ]; then
        echo "⚠️ No se encontraron puertos activos en las variables."
        exit 0
    fi
fi

echo "🔄 Puertos a verificar: $PORTS_TO_CHECK"

IFS=',' read -ra PORT_ARRAY <<< "$PORTS_TO_CHECK"

for port in "${PORT_ARRAY[@]}"; do
  port=$(echo "$port" | xargs)
  
  if [ -z "$port" ]; then continue; fi
  
  pid=$(ss -lntp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -n 1)
  
  if [ -n "$pid" ]; then
    echo "🔥 Puerto $port ocupado por PID $pid. Asesinando..."
    kill -9 "$pid" 2>/dev/null
    echo "   ✅ Eliminado."
  else
    echo "✔️  Puerto $port libre."
  fi
done

echo "✨ Limpieza completada."
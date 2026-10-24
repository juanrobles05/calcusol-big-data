#!/usr/bin/env bash
# Uso: ./publicar.sh TOTAL CORRIDA [ARCHIVO_DE_REINTENTO]
# Ejemplo: ./publicar.sh 10000 r1
TOTAL=${1:-10000}
RUN=${2:-r1}
export TOPIC="calcusol/telemetria"
export RUN
export ENDPOINT=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS \
  --query endpointAddress --output text)

publicar() {
  n=$1
  dev=$(printf "panel-%02d" $(( (n % 20) + 1 )))
  id=$(printf "%s-%06d" "$RUN" "$n")
  irr=$(( RANDOM % 1000 )).$(( RANDOM % 10 ))
  tmp=$(( 15 + RANDOM % 25 )).$(( RANDOM % 10 ))
  pot=$(( RANDOM % 5000 )).$(( RANDOM % 10 ))
  # Cada 25 eventos (4 %) sale mal a propósito, siempre como JSON válido
  if (( n % 25 == 0 )); then
    case $(( (n / 25) % 4 )) in
      0) dev_campo="" ;;                   # falta device_id
      1) irr="9999" ;;                     # irradiancia fuera de rango
      2) tmp='"abc"' ;;                    # temperatura no numerica
      3) pot="-50" ;;                      # potencia negativa
    esac
  fi
  [[ -z "${dev_campo+x}" ]] && dev_campo="\"device_id\":\"$dev\","
  ts=$(date +%s%3N)
  payload=$(printf '{"event_id":"%s",%s"sent_at_ms":%s,"irradiancia_wm2":%s,"temperatura_c":%s,"potencia_w":%s}' \
    "$id" "$dev_campo" "$ts" "$irr" "$tmp" "$pot")
  if aws iot-data publish --endpoint-url "https://$ENDPOINT" \
       --topic "$TOPIC" --qos 1 \
       --cli-binary-format raw-in-base64-out \
       --payload "$payload" >/dev/null 2>&1; then
    echo "$n" >> ok.log
  else
    echo "$n" >> fallo.log
  fi
}
export -f publicar

[ -z "$3" ] && rm -f ok.log fallo.log
echo "inicio: $(date -u +%FT%TZ)"
# Con un tercer argumento (archivo con números), reintenta solo esos eventos
{ if [ -n "$3" ]; then cat "$3"; else seq 1 "$TOTAL"; fi; } | xargs -P 20 -I{} bash -c 'publicar {}'
echo "fin: $(date -u +%FT%TZ)"
echo "publicados OK: $(sort -u ok.log | wc -l)"
echo "fallidos:      $( [ -f fallo.log ] && wc -l < fallo.log || echo 0 )"

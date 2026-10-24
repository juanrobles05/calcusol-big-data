import json
import re
import time
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
eventos = dynamodb.Table("calcusol_eventos")
descartes = dynamodb.Table("calcusol_descartes")

DEVICE_RE = re.compile(r"^panel-(0[1-9]|1[0-9]|20)$")

RANGOS = {
    "irradiancia_wm2": (0, 1500),
    "temperatura_c": (-50, 60),
    "potencia_w": (0, None),
}


def es_numero(v):
    return isinstance(v, (int, Decimal)) and not isinstance(v, bool)


def validar(ev):
    """Devuelve el motivo del descarte, o None si el evento es válido."""
    if not isinstance(ev, dict):
        return "el mensaje no es un objeto JSON"
    for campo in ("event_id", "device_id"):
        v = ev.get(campo)
        if not isinstance(v, str) or not v.strip():
            return f"campo {campo} ausente o vacio"
    if not DEVICE_RE.match(ev["device_id"]):
        return "device_id fuera de panel-01..panel-20"
    if not es_numero(ev.get("sent_at_ms")):
        return "sent_at_ms ausente o no numerico"
    for campo, (minimo, maximo) in RANGOS.items():
        v = ev.get(campo)
        if not es_numero(v):
            return f"{campo} ausente o no numerico"
        if v < minimo or (maximo is not None and v > maximo):
            return f"{campo} fuera de rango"
    return None


def guardar_descarte(message_id, cuerpo, motivo):
    descartes.put_item(Item={
        "message_id": message_id,
        "motivo": motivo,
        "cuerpo": cuerpo[:2000],
        "recibido_ms": int(time.time() * 1000),
    })


def lambda_handler(event, context):
    fallos = []
    for r in event["Records"]:
        mid = r["messageId"]
        try:
            try:
                ev = json.loads(r["body"], parse_float=Decimal)
            except json.JSONDecodeError:
                guardar_descarte(mid, r["body"], "JSON invalido")
                continue
            motivo = validar(ev)
            if motivo:
                guardar_descarte(mid, r["body"], motivo)
                continue
            ahora = int(time.time() * 1000)
            ev["stored_at_ms"] = ahora
            ev["delay_ms"] = ahora - int(ev["sent_at_ms"])
            try:
                eventos.put_item(
                    Item=ev,
                    ConditionExpression="attribute_not_exists(event_id)",
                )
            except ClientError as e:
                if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                    print(f"duplicado ignorado: {ev['event_id']}")
                else:
                    raise
        except Exception as e:
            print(f"error con {mid}: {e}")
            fallos.append({"itemIdentifier": mid})
    return {"batchItemFailures": fallos}

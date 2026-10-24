import os
from collections import Counter

import boto3

db = boto3.client("dynamodb")


def scan_all(tabla, **kw):
    for pagina in db.get_paginator("scan").paginate(TableName=tabla, **kw):
        yield from pagina["Items"]


publicados = 0
if os.path.exists("ok.log"):
    publicados = len(set(open("ok.log").read().split()))

delays = [int(i["delay_ms"]["N"])
          for i in scan_all("calcusol_eventos", ProjectionExpression="delay_ms")]
motivos = Counter(i["motivo"]["S"]
                  for i in scan_all("calcusol_descartes", ProjectionExpression="motivo"))

guardados = len(delays)
descartados = sum(motivos.values())

print(f"Publicados:  {publicados}")
print(f"Guardados:   {guardados}")
print(f"Descartados: {descartados}")
print(f"Cuadra:      {publicados} = {guardados} + {descartados} -> {publicados == guardados + descartados}")

print("\nMotivos de descarte:")
for motivo, n in motivos.most_common():
    print(f"  {n:>5}  {motivo}")

if delays:
    print("\nRetraso envio -> DynamoDB (ms):")
    print(f"  promedio: {sum(delays) / len(delays):.0f}")
    print(f"  maximo:   {max(delays)}")
    print(f"  minimo:   {min(delays)}")

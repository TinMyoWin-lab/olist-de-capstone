#JSONL (JSON Lines) is one complete JSON object per line, with no surrounding [ ] and no commas between lines
import json

orders = []
with open("/home/arsayar/workspace/learning/data-engineering-fundamentals/olist-de-capstone/scripts/week7/week7test.jsonl") as f:
      for line in f:
          line = line.strip()
          if not line:
              continue
          orders.append(json.loads(line))

print(orders[0]["order_id"])
for order in orders:
      print(order["order_id"], order["status"])
import urllib.request
import json
import sys

TOKEN = sys.argv[1]
PROJECT_GID = "1203473983906321"

url = f"https://app.asana.com/api/1.0/projects/{PROJECT_GID}/custom_field_settings?opt_fields=custom_field.name,custom_field.gid"
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {TOKEN}"})

with urllib.request.urlopen(req) as resp:
    data = json.load(resp)

for item in data["data"]:
    cf = item["custom_field"]
    print(f"{cf['gid']:20}  {cf['name']}")

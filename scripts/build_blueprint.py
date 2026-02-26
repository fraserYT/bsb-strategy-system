"""
Builds the updated Make.com blueprint for the IO submission scenario.
Replaces the flat Drive folder creation (modules 12 and 23) with
the full 4-tier find-or-create logic plus io_products DB write.

Run: python3 scripts/build_blueprint.py
"""

import json

BLUEPRINT_PATH = 'make-blueprints/phase-1-io-submission-project-creation.json'

PG_ACCOUNT       = 13330461
PG_ACCOUNT_LABEL = "BitesizeDB (xerothermic-scarlet-cod@europe-north1-001.proxy.sevalla.app:30067/competitive-moccasin-vicuna)"
DRIVE_CONN       = 9173518
SHEETS_CONN      = 8629994
SHARED_DRIVE_ID  = "0AB1AZiOLJI_ZUk9PVA"
CLIENT_PROJECTS  = "1PURGWZSK1gMTJN7GDYogY1Q0_ohsUkht"
SPREADSHEET_ID   = "1tQfpYsQEfpO5XAPzWbkHUJeGWPKITDiSDOhp6GGJ0jA"
METABASE_IO_URL  = 'https://bionic-dashboard-aevhj.kinsta.app/dashboard/3-io-overview?io_reference={{2.`4`}}'


# ── helpers ──────────────────────────────────────────────────────────────────

def pg_mod(mid, spname, label, mapper, interface, flt=None, x=0):
    m = {
        "id": mid,
        "module": "postgres:StoredProcedure",
        "version": 2,
        "parameters": {
            "ignore": False,
            "spname": f'"public"."{spname}"',
            "account": PG_ACCOUNT,
            "isToManageDataInSharedTransaction": True
        },
        "mapper": mapper,
        "metadata": {
            "designer": {"x": x, "y": 300, "name": label},
            "restore": {
                "parameters": {
                    "spname": {"label": f"public.{spname}"},
                    "account": {
                        "data": {"scoped": "true", "connection": "postgres"},
                        "label": PG_ACCOUNT_LABEL
                    }
                }
            },
            "interface": interface
        }
    }
    if flt:
        m["filter"] = flt
    return m


def drive_mod(mid, label, name_expr, parent_expr, flt=None, x=0):
    m = {
        "id": mid,
        "module": "google-drive:createAFolder",
        "version": 4,
        "parameters": {"__IMTCONN__": DRIVE_CONN},
        "mapper": {
            "name": name_expr,
            "folderId": parent_expr,
            "destination": "team",
            "sharedDrive": SHARED_DRIVE_ID,
            "useDomainAdminAccess": False
        },
        "metadata": {
            "designer": {"x": x, "y": 300, "name": label},
            "restore": {
                "expect": {
                    "folderId": {"mode": "edit", "path": []},
                    "destination": {"label": "Google Shared Drive"},
                    "sharedDrive": {"mode": "chose", "label": "Bitesize Bio Shared Drive"},
                    "useDomainAdminAccess": {"label": "No"}
                },
                "parameters": {
                    "__IMTCONN__": {
                        "data": {"scoped": "true", "connection": "google-restricted"},
                        "label": "My Google Restricted connection (fraser@bitesizebio.com)"
                    }
                }
            },
            "parameters": [{
                "name": "__IMTCONN__",
                "type": "account:google-restricted",
                "label": "Connection",
                "required": True
            }],
            "expect": [
                {"name": "destination", "type": "select", "label": "New Drive Location",
                 "required": True, "validate": {"enum": ["drive", "share", "team"]}},
                {"name": "useDomainAdminAccess", "type": "select",
                 "label": "Use Domain Admin Access", "required": True,
                 "validate": {"enum": [True, False]}},
                {"name": "name",     "type": "text",   "label": "New Folder's Name"},
                {"name": "sharedDrive", "type": "select", "label": "Shared Drive", "required": True},
                {"name": "folderId", "type": "folder", "label": "New Folder Location"}
            ]
        }
    }
    if flt:
        m["filter"] = flt
    return m


def setvars_mod(mid, label, variables, x=0):
    interface = [{"name": v["name"], "type": "any", "label": v["name"]} for v in variables]
    return {
        "id": mid,
        "module": "util:SetVariables",
        "version": 1,
        "parameters": {},
        "mapper": {"scope": "roundtrip", "variables": variables},
        "metadata": {
            "designer": {"x": x, "y": 300, "name": label},
            "restore": {
                "expect": {
                    "scope": {"label": "One cycle"},
                    "variables": {"items": [None] * len(variables)}
                }
            },
            "expect": [
                {
                    "name": "variables",
                    "spec": [
                        {"name": "name",  "type": "text", "label": "Variable name",  "required": True},
                        {"name": "value", "type": "any",  "label": "Variable value"}
                    ],
                    "type": "array",
                    "label": "Variables"
                },
                {
                    "name": "scope", "type": "select", "label": "Variable lifetime",
                    "required": True, "validate": {"enum": ["roundtrip", "execution"]}
                }
            ],
            "interface": interface
        }
    }


def flt(name, *cond_groups):
    """Build a filter. Each cond_group is a list of AND conditions; groups are OR'd."""
    return {"name": name, "conditions": list(cond_groups)}


def empty(field):
    return [{"a": field, "b": "", "o": "text:empty"}]


def placeholder_mod(mid):
    return {
        "id": mid,
        "module": "placeholder:Placeholder",
        "version": 1,
        "parameters": {},
        "mapper": {},
        "metadata": {"designer": {"x": 0, "y": 0}}
    }


def router_mod(mid, routes, x=0):
    """Wrap conditional modules in a router with a pass-through branch.
    Prevents the scenario from halting when a filter condition is not met."""
    return {
        "id": mid,
        "module": "builtin:BasicRouter",
        "version": 1,
        "parameters": {},
        "mapper": None,
        "metadata": {"designer": {"x": x, "y": 0}},
        "routes": routes
    }


def rename_module_id(flow, old_id, new_id):
    """Recursively rename a module ID throughout the flow (including nested routes)."""
    for m in flow:
        if m.get('id') == old_id:
            m['id'] = new_id
        if 'routes' in m:
            for route in m['routes']:
                rename_module_id(route.get('flow', []), old_id, new_id)


# ── expressions ──────────────────────────────────────────────────────────────

TIER3_NAME = (
    '{{if(40.`0` = "Live Event"; "Live Events"; '
    'if(40.`0` = "eBlast"; "eBlasts"; '
    'if(40.`0` = "Podcast"; "Podcasts"; '
    'if(40.`0` = "Newsletter Banner"; "Newsletter Banners"; '
    'if(40.`0` = "Website Banner"; "Website Banners"; '
    'if(40.`0` = "Multi-Session Live Event"; "Multi-Session Live Events"; '
    'if(40.`0` = "Article"; "Articles"; '
    'if(40.`0` = "Ebook"; "Ebooks"; '
    'if(40.`0` = "Masterclass"; "Masterclasses"; 40.`0`)))))))))}}')

IO_FOLDER_NAME = '[{{2.`5`}}] {{2.`4`}} {{2.`3`}} {{40.`0`}} ({{32.`Unique ID`}})'

YEAR_EXPR   = '{{formatDate(2.`3`; "YYYY")}}'
TIER1_ID    = '{{ifempty(58.tier1_folder_id; 60.id)}}'
TIER2_ID    = '{{ifempty(58.tier2_folder_id; 61.id)}}'
TIER3_ID    = '{{ifempty(59.product_type_folder_id; 63.id)}}'
TIER4_ID    = '{{ifempty(59.year_folder_id; 64.id)}}'

# ── new modules (replace module 23) ──────────────────────────────────────────
#
# Each conditional Drive/DB module is wrapped in a router (ids 69-74) with a
# pass-through branch (placeholder ids 90-95). This ensures execution always
# continues past the router whether or not the condition was met.
#
# Module ID map:
#   57       SetVariables (per-product vars)
#   58       get_client_folder_info
#   59       get_product_folder_info
#   69/60    Router / Create Tier 1 folder
#   70/61    Router / Create Tier 2 folder
#   71/62    Router / Store Tier 1+2 IDs
#   72/63    Router / Create Tier 3 folder
#   73/64    Router / Create Tier 4 folder
#   74/65    Router / Store Tier 3+4 IDs
#   66       Create IO folder (always)
#   67       Record product in DB (always)
#   68       Write unique ID to Products sheet (always)
#   90-95    Pass-through placeholders inside routers

new_modules = [

    # 57 — per-product variables
    setvars_mod(57, "Set Drive folder variables", [
        {"name": "tier3FolderName", "value": TIER3_NAME},
        {"name": "ioFolderName",    "value": IO_FOLDER_NAME}
    ], x=4800),

    # 58 — look up Tier 1 + 2 folder IDs from DB
    pg_mod(58, "get_client_folder_info", "Look up client folder IDs",
        {"@01:text": "{{2.`5`}}"},
        [
            {"name": "tla",             "type": "text", "label": "tla"},
            {"name": "client_name",     "type": "text", "label": "client_name"},
            {"name": "primary_contact", "type": "text", "label": "primary_contact"},
            {"name": "tier1_folder_id", "type": "text", "label": "tier1_folder_id"},
            {"name": "tier2_folder_id", "type": "text", "label": "tier2_folder_id"}
        ], x=5100),

    # 59 — look up Tier 3 + 4 folder IDs from DB
    pg_mod(59, "get_product_folder_info", "Look up product folder IDs",
        {
            "@01:text": "{{2.`5`}}",
            "@02:text": "{{40.`0`}}",
            "@03:text": YEAR_EXPR
        },
        [
            {"name": "product_type_folder_id", "type": "text", "label": "product_type_folder_id"},
            {"name": "year_folder_id",         "type": "text", "label": "year_folder_id"}
        ], x=5400),

    # Router 69: create Tier 1 if missing
    router_mod(69, [
        {"flow": [drive_mod(60, "Create Tier 1 (company) folder",
            "[{{58.tla}}] {{58.client_name}}",
            CLIENT_PROJECTS,
            flt("Only if Tier 1 folder missing", empty("{{58.tier1_folder_id}}")),
            x=5700)]},
        {"flow": [placeholder_mod(90)]}
    ], x=5700),

    # Router 70: create Tier 2 if missing
    router_mod(70, [
        {"flow": [drive_mod(61, "Create Tier 2 (contact) folder",
            "[{{2.`5`}}] {{58.primary_contact}}",
            TIER1_ID,
            flt("Only if Tier 2 folder missing", empty("{{58.tier2_folder_id}}")),
            x=6000)]},
        {"flow": [placeholder_mod(91)]}
    ], x=6000),

    # Router 71: store Tier 1+2 IDs if either was just created
    router_mod(71, [
        {"flow": [pg_mod(62, "update_client_folder_ids", "Store Tier 1+2 folder IDs",
            {
                "@01:text": "{{2.`5`}}",
                "@02:text": TIER1_ID,
                "@03:text": TIER2_ID
            },
            [{"name": "update_client_folder_ids", "type": "boolean", "label": "update_client_folder_ids"}],
            flt("Only if Tier 1 or Tier 2 was missing",
                empty("{{58.tier1_folder_id}}"),
                empty("{{58.tier2_folder_id}}")),
            x=6300)]},
        {"flow": [placeholder_mod(92)]}
    ], x=6300),

    # Router 72: create Tier 3 if missing
    router_mod(72, [
        {"flow": [drive_mod(63, "Create Tier 3 (product type) folder",
            "[{{2.`5`}}] {{57.tier3FolderName}}",
            TIER2_ID,
            flt("Only if Tier 3 folder missing", empty("{{59.product_type_folder_id}}")),
            x=6600)]},
        {"flow": [placeholder_mod(93)]}
    ], x=6600),

    # Router 73: create Tier 4 if missing
    router_mod(73, [
        {"flow": [drive_mod(64, "Create Tier 4 (year) folder",
            YEAR_EXPR,
            TIER3_ID,
            flt("Only if Tier 4 folder missing", empty("{{59.year_folder_id}}")),
            x=6900)]},
        {"flow": [placeholder_mod(94)]}
    ], x=6900),

    # Router 74: store Tier 3+4 IDs if either was just created
    router_mod(74, [
        {"flow": [pg_mod(65, "upsert_product_folder", "Store Tier 3+4 folder IDs",
            {
                "@01:text": "{{2.`5`}}",
                "@02:text": "{{40.`0`}}",
                "@03:text": YEAR_EXPR,
                "@04:text": TIER3_ID,
                "@05:text": TIER4_ID
            },
            [{"name": "upsert_product_folder", "type": "text", "label": "upsert_product_folder"}],
            flt("Only if Tier 3 or Tier 4 was missing",
                empty("{{59.product_type_folder_id}}"),
                empty("{{59.year_folder_id}}")),
            x=7200)]},
        {"flow": [placeholder_mod(95)]}
    ], x=7200),

    # 66 — create IO folder (always)
    drive_mod(66, "Create IO folder",
        IO_FOLDER_NAME,
        TIER4_ID,
        None, x=7500),

    # 67 — record product in DB
    pg_mod(67, "upsert_io_product", "Record product in DB",
        {
            "@01:text": "{{2.`4`}}",
            "@02:text": "{{40.`0`}}",
            "@03:text": "{{40.`1`}}",
            "@04:text": "{{32.`Unique ID`}}",
            "@05:text": "{{66.id}}"
        },
        [{"name": "upsert_io_product", "type": "integer", "label": "upsert_io_product"}],
        None, x=7800),

    # 68 — write unique_id back to Products sheet col E
    {
        "id": 68,
        "module": "google-sheets:updateRow",
        "version": 2,
        "parameters": {"__IMTCONN__": SHEETS_CONN},
        "mapper": {
            "from": "share",
            "mode": "select",
            "values": {"4": "{{32.`Unique ID`}}"},
            "sheetId": "Products",
            "rowNumber": "{{17.__ROW_NUMBER__}}",
            "spreadsheetId": f"/{SPREADSHEET_ID}",
            "includesHeaders": True,
            "valueInputOption": "USER_ENTERED"
        },
        "metadata": {
            "designer": {"x": 8100, "y": 300, "name": "Write unique ID to Products sheet"},
            "restore": {
                "expect": {
                    "from":  {"label": "Shared with me"},
                    "mode":  {"label": "Search by path"},
                    "sheetId": {"label": "Products"},
                    "spreadsheetId": {"path": ["IO Submissions"]},
                    "includesHeaders": {
                        "label": "Yes",
                        "nested": [{
                            "name": "values",
                            "spec": [
                                {"name": "0", "type": "text", "label": "Product Type (A)"},
                                {"name": "1", "type": "text", "label": "Product name (B)"},
                                {"name": "2", "type": "text", "label": "Related IO (C)"},
                                {"name": "3", "type": "text", "label": "Company Name (D)"},
                                {"name": "4", "type": "text", "label": "Unique ID (E)"}
                            ],
                            "type": "collection",
                            "label": "Values"
                        }]
                    },
                    "valueInputOption": {"mode": "chose", "label": "User entered"}
                },
                "parameters": {
                    "__IMTCONN__": {
                        "data": {"scoped": "true", "connection": "google"},
                        "label": "My Google connection (fraser@bitesizebio.com)"
                    }
                }
            },
            "parameters": [{
                "name": "__IMTCONN__",
                "type": "account:google",
                "label": "Connection",
                "required": True
            }]
        }
    }
]

# ── apply changes ─────────────────────────────────────────────────────────────

with open(BLUEPRINT_PATH) as f:
    data = json.load(f)

flow = data['flow']

# 0. Fix placeholder ID conflicts: existing router uses 65+66 as placeholder IDs,
#    which clash with new modules 65+66. Rename them to 80+81.
rename_module_id(flow, 65, 80)
rename_module_id(flow, 66, 81)

# 1. Remove module 12 (old flat Drive folder creation)
flow[:] = [m for m in flow if m.get('id') != 12]

# 2. Module 10: remove Drive link write-back (col S, field "18")
for m in flow:
    if m.get('id') == 10:
        m['mapper']['values'].pop('18', None)

# 3. Module 54: store Metabase IO dashboard link instead of Drive link
for m in flow:
    if m.get('id') == 54:
        m['mapper']['@03:text'] = METABASE_IO_URL

# 4. Module 41: strip deliverables to product type only
for m in flow:
    if m.get('id') == 41:
        m['mapper']['value'] = '- {{40.`0`}}'

# 5. Module 47: add Metabase IO dashboard link to goal notes
for m in flow:
    if m.get('id') == 47:
        m['mapper']['data']['notes'] += '\n\nFull IO details: ' + METABASE_IO_URL

# 6. Replace module 23 with new modules 57-68 (wrapped in routers where conditional)
for i, m in enumerate(flow):
    if m.get('id') == 23:
        flow[i:i+1] = new_modules
        print(f"Replaced module 23 at index {i} with {len(new_modules)} new modules")
        break
else:
    print("WARNING: module 23 not found in top-level flow")

with open(BLUEPRINT_PATH, 'w') as f:
    json.dump(data, f, indent=2)

print("Blueprint written.")

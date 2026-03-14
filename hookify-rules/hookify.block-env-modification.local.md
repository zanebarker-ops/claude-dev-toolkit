---
name: block-env-modification
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env$|\.env\.local$|\.env\.production$
---

🛑 **Protected file modification blocked!**

`.env` files are protected and must never be overwritten by Claude.

**Why:** Environment files contain sensitive credentials and local configuration that varies per developer.

**What to do:**
1. Ask the user to manually edit the `.env` file
2. Provide the exact values/changes needed
3. User will copy-paste or edit themselves

See `docs/reference/configuration/environments.md` for environment variable documentation.

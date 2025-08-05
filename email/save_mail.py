#!/usr/bin/env python3
import sys
from datetime import datetime
from pathlib import Path
import re

MAIL_DIR = Path("/opt/email/mailstore")
LOG_DIR = Path("/opt/email/logs")
MAIL_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

try:
    raw_data = sys.stdin.buffer.read()

    raw_text = raw_data.decode('utf-8', errors='ignore')

    m = re.search(r'^To:\s*(.*?@[^>\s]+)', raw_text, re.IGNORECASE | re.MULTILINE)
    to_address = m.group(1).strip().lower() if m else 'unknown@unknown'
    to_address = to_address.strip('"').strip().lower()

    save_dir = MAIL_DIR / to_address.replace("@", "_at_")
    save_dir.mkdir(parents=True, exist_ok=True)

    filename = datetime.utcnow().strftime('%Y%m%d%H%M%S') + ".eml"
    with open(save_dir / filename, "wb") as f:
        f.write(raw_data)

except Exception as e:
    with open(LOG_DIR / "save_mail_error.log", "a") as errlog:
        errlog.write(f"{datetime.utcnow()}: {str(e)}\n")
    sys.exit(1)

sys.exit(0)

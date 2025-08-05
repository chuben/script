from flask import Flask, request, render_template_string, abort
from email import policy
from email.parser import BytesParser
from aiosmtpd.controller import Controller
from pathlib import Path
from datetime import datetime
import logging
from werkzeug.serving import run_simple

MAIL_DIR = Path("mailstore")
MAIL_DIR.mkdir(exist_ok=True)

class CatchAllHandler:
    async def handle_DATA(self, server, session, envelope):
        timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")

        recipients = envelope.rcpt_tos
        message = BytesParser().parsebytes(envelope.original_content)

        for to_addr in recipients:
            to_addr = to_addr.lower()
            sanitized = to_addr.replace("@", "_at_")
            user_dir = MAIL_DIR / sanitized
            user_dir.mkdir(exist_ok=True)

            msg_id = message.get("Message-ID", "")
            msg_id = msg_id.replace("<", "").replace(">", "").replace("/", "_")
            filename = f"{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{msg_id}.eml"
            filepath = user_dir / filename

            with open(filepath, "wb") as f:
                f.write(envelope.original_content)

            print(f"[+] Saved mail for {to_addr} at {filepath}")

        return "250 Message accepted for delivery"

    async def handle_RCPT(self, server, session, envelope, address, rcpt_options):
        envelope.rcpt_tos.append(address)
        return '250 OK'

def extract_html_from_msg(msg):
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            if content_type == "text/html":
                payload = part.get_payload(decode=True)
                charset = part.get_content_charset() or "utf-8"
                try:
                    return payload.decode(charset, errors="replace")
                except Exception:
                    continue
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                charset = part.get_content_charset() or "utf-8"
                return f"<pre>{payload.decode(charset, errors='replace')}</pre>"
    else:
        payload = msg.get_payload(decode=True)
        charset = msg.get_content_charset() or "utf-8"
        return payload.decode(charset, errors="replace")

app = Flask(__name__)

@app.route("/Mail")
def view_mail():
    token = request.args.get('token')
    if not token or token != "2088":
        abort(403, description="无效 token")

    email = request.args.get("mail")
    if not email:
        return "Missing ?Mail= param"
    num = int(request.args.get("num", "-1"))

    folder = MAIL_DIR / email.replace("@", "_at_").lower()
    if not folder.exists():
        return f"No email found for {email}"

    eml_files = sorted(folder.glob("*.eml"))
    eml_file = eml_files[num]

    with open(eml_file, "rb") as f:
        msg = BytesParser(policy=policy.default).parse(f)
        html = extract_html_from_msg(msg)

    return render_template_string(html)

if __name__ == '__main__':
    handler = CatchAllHandler()
    controller = Controller(handler, hostname="0.0.0.0", port=25)
    controller.start()
    logging.warning("[*] SMTP server running on port 25 (Catch-All Enabled)")
    run_simple("0.0.0.0", 2088, app, use_reloader=False, use_debugger=False)
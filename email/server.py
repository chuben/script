#!/usr/bin/env python3
from flask import Flask, request, render_template_string, abort
from email import policy
from email.parser import BytesParser
from pathlib import Path

MAIL_DIR = Path("/opt/email/mailstore")
MAIL_DIR.mkdir(exist_ok=True)

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
    app.run('0.0.0.0', 2088)
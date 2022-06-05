from datetime import datetime
from flask import Flask, Response, request

app = Flask(__name__)

@app.route("/", methods=["GET"])
def _():
    headers = "\n".join([f"{k}={v}" for k, v in request.headers.items()])
    return Response(
        f"{datetime.now().isoformat()}\n\n{headers}",
        mimetype="text/plain",
    )

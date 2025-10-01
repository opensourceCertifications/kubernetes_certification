"""Tiny REST API that saves messages in MySQL for the cluster demo."""

from __future__ import annotations

import datetime as dt
import os
from typing import Any, List

import mysql.connector
from flask import Flask, jsonify, request

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "mysql.database.svc.cluster.local")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_NAME = os.environ.get("DB_NAME", "testdb")
DB_USER = os.environ.get("DB_USER", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "password123")
TABLE_NAME = os.environ.get("DB_TABLE", "messages")
MAX_RESULTS = int(os.environ.get("DB_MAX_RESULTS", "10"))


def get_connection() -> mysql.connector.connection.MySQLConnection:
    """Open a database connection using the in-cluster service DNS."""
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )


def ensure_table_exists(cursor: mysql.connector.cursor.MySQLCursor) -> None:
    """Create the messages table on first use so inserts never fail."""
    cursor.execute(
        f"""
        CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
            id INT AUTO_INCREMENT PRIMARY KEY,
            submitted_at DATETIME NOT NULL,
            message TEXT NOT NULL
        ) ENGINE=InnoDB
        """
    )


def fetch_recent(cursor: mysql.connector.cursor.MySQLCursor) -> List[dict[str, Any]]:
    """Return the newest N rows for the UI."""
    cursor.execute(
        f"SELECT submitted_at, message FROM {TABLE_NAME} ORDER BY submitted_at DESC LIMIT %s",
        (MAX_RESULTS,),
    )
    rows = cursor.fetchall()
    return [
        {"submitted_at": row[0].isoformat(sep=" ", timespec="seconds"), "message": row[1]}
        for row in rows
    ]


@app.after_request
def add_cors_headers(response):
    """Allow the static frontend to call the API from a different origin."""
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
    return response


@app.route("/healthz", methods=["GET"])
def healthcheck() -> Any:
    return {"status": "ok"}


@app.route("/readyz", methods=["GET"])
def readiness() -> Any:
    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                ensure_table_exists(cursor)
        return {"status": "ready"}
    except Exception as exc:  # pragma: no cover
        return {"status": "error", "detail": str(exc)}, 500


@app.route("/entries", methods=["OPTIONS"])
def entries_options() -> Any:
    return ("", 204)


@app.route("/entries", methods=["GET"])
def list_entries() -> Any:
    with get_connection() as conn:
        with conn.cursor() as cursor:
            ensure_table_exists(cursor)
            entries = fetch_recent(cursor)
    return jsonify(entries)


@app.route("/entries", methods=["POST"])
def create_entry() -> Any:
    payload = request.get_json(silent=True) or {}
    message = (payload.get("message") or "").strip()
    if not message:
        return {"error": "message is required"}, 400

    submitted_at = dt.datetime.utcnow()

    with get_connection() as conn:
        with conn.cursor() as cursor:
            ensure_table_exists(cursor)
            cursor.execute(
                f"INSERT INTO {TABLE_NAME} (submitted_at, message) VALUES (%s, %s)",
                (submitted_at, message),
            )
            conn.commit()
            entries = fetch_recent(cursor)
    return jsonify(entries), 201


if __name__ == "__main__":  # pragma: no cover
    app.run(host="0.0.0.0", port=8080)

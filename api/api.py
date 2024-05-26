import os

import sqlalchemy
from flask import Flask
from google.cloud.alloydb.connector import Connector

app = Flask(__name__)
connector = Connector()


def getconn():
    conn = connector.connect(
        "projects/cloud-computing-2024-424511/locations/europe-west1/clusters/alloydb-cluster/instances/alloydb-instance",
        "pg8000",
        user="alloydb_user",
        password="alloydb_password",
        db="postgres",
    )
    return conn


pool = sqlalchemy.create_engine(
    "postgresql+pg8000://",
    creator=getconn,
)


@app.route("/", methods=["GET"])
def main():
    return "Hello, respect-weather API!"


@app.route("/data", methods=["GET"])
def get_data():

    with pool.connect() as db_conn:
        result = db_conn.execute(sqlalchemy.text("SELECT * from entries")).fetchall()

        for row in result:
            pass

    return str(row)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

import pandas_gbq

# import sqlalchemy
from flask import Flask, make_response, request

# from google.cloud.alloydb.connector import Connector

app = Flask(__name__)
# connector = Connector()


# def getconn():
#     conn = connector.connect(
#         "projects/cloud-computing-2024-424511/locations/europe-west1/clusters/alloydb-cluster/instances/alloydb-instance",
#         "pg8000",
#         user="alloydb_user",
#         password="alloydb_password",
#         db="postgres",
#     )
#     return conn


# pool = sqlalchemy.create_engine(
#     "postgresql+pg8000://",
#     creator=getconn,
# )


@app.route("/", methods=["GET"])
def main():
    return "Hello, Respect Weather API!"


@app.route("/forecasts", methods=["GET"])
def get_data():
    longitude = request.args.get("longitude", type=float)
    latitude = request.args.get("latitude", type=float)
    publication_date = request.args.get("publication_date")

    min_latitude = int(latitude)
    max_latitude = int(latitude) + 1

    min_longitude = int(longitude)
    max_longitude = int(longitude) + 1

    query = f"""
    SELECT
    *
    FROM `meteo_dataset.gefs`
    WHERE time = '{publication_date} 00:00:00 UTC'
    and latitude in ({min_latitude}, {max_latitude})
    and longitude in ({min_longitude}, {max_longitude})
    order by time, valid_time
    """

    df = pandas_gbq.read_gbq(query, progress_bar_type=None)

    csv_data = df.to_csv(index=False)
    response = make_response(csv_data)
    response.headers["Content-Type"] = "text/csv"

    return response


# @app.route("/data", methods=["GET"])
# def get_data():

#     with pool.connect() as db_conn:
#         result = db_conn.execute(sqlalchemy.text("SELECT * from entries")).fetchall()

#         for row in result:
#             pass

#     return str(row)


if __name__ == "__main__":
    # app.run(host="0.0.0.0", port=8080)
    app.run()

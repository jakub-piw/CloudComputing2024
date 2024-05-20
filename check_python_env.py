import getpass
import sys
import urllib.request
import os
import xarray as xr
import numpy as np
import pandas as pd
import pandas_gbq

# from pyspark.sql import SparkSession
# import pyspark.pandas as ps

# spark = SparkSession.builder.master("yarn").appName("spark-bigquery-demo").getOrCreate()

print('This job is running as "{}".'.format(getpass.getuser()))
print(sys.executable, sys.version_info)

urllib.request.urlretrieve(
    "https://noaa-gefs-pds.s3.amazonaws.com/gefs.20240520/00/atmos/pgrb2ap5/geavg.t00z.pgrb2a.0p50.f000",
    "test.grib2",
)


longitude = np.concatenate(
    [
        np.linspace(0, 45, 91),
        np.linspace(300, 359.5, 120),
    ]
)
latitude = np.linspace(30, 90, 121)
coords = np.array([[x0, y0] for x0 in longitude for y0 in latitude])
coords = pd.DataFrame(coords).drop_duplicates().to_numpy()
lon = xr.DataArray(coords[:, 0], dims="idx")
lat = xr.DataArray(coords[:, 1], dims="idx")

filter_by_keys_list = [
    {"typeOfLevel": "depthBelowLandLayer"},
    {"typeOfLevel": "heightAboveGround", "level": 2},
    {"typeOfLevel": "heightAboveGround", "level": 10},
    {"typeOfLevel": "atmosphereSingleLayer"},
    {"typeOfLevel": "meanSea"},
    {"typeOfLevel": "pressureFromGroundLayer"},
    {"typeOfLevel": "surface"},
]

surface = (
    pd.concat(
        [
            xr.open_dataset(
                "test.grib2",
                engine="cfgrib",
                filter_by_keys=filter_by_keys,
                indexpath="",
            )
            .drop_vars(
                [
                    "step",
                    "surface",
                    "pressureFromGroundLayer",
                    "meanSea",
                    "atmosphereSingleLayer",
                    "atmosphere",
                    "heightAboveGround",
                    "depthBelowLandLayer",
                    "nominalTop",
                    "unknown",
                    "icetk",
                    "level",
                ],
                errors="ignore",
            )
            .sel(longitude=lon, latitude=lat)
            .to_dataframe()
            .pipe(lambda df: df.assign(number=-1) if "number" not in df.columns else df)
            .set_index(["longitude", "latitude", "number", "time", "valid_time"])
            for filter_by_keys in filter_by_keys_list
        ],
        axis=1,
    )
    .reset_index()
    .assign(
        longitude=lambda x: np.where(
            x["longitude"] > 180, x["longitude"] - 360, x["longitude"]
        )
    )
    .assign(
        tp=np.nan,
        tcc=np.nan,
    )
    .loc[
        :,
        [
            "time",
            "valid_time",
            "latitude",
            "longitude",
            "number",
            "u10",
            "v10",
            "tp",
            "tcc",
            "t2m",
            "prmsl",
        ],
    ]
)
print(surface)
print(surface.columns)
pandas_gbq.to_gbq(surface, 'meteo_dataset.gefs')
# ps.from_pandas(surface).to_spark().write.format('bigquery') \
#   .option('table', 'meteo_dataset.gefs') \
#   .save()
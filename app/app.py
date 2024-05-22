import pandas_gbq
import streamlit as st

st.title("Hello Respect123")
df = pandas_gbq.read_gbq(
    "SELECT * FROM `meteo_dataset.gefs` WHERE time = '2024-05-22' and longitude = 24 and latitude = 34",
    progress_bar_type=None,
)
st.write(df)

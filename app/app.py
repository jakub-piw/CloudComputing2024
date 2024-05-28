import datetime as dt
import os

import pandas as pd
import streamlit as st
from modules import get_weather_forecast, login

# constants
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
locations = pd.read_csv(os.path.join(BASE_DIR, "locations.csv"), index_col="id")


# configuration
st.set_page_config(
    page_title="Respect Weather",
    page_icon="🌍",
    layout="wide",
)
if "publication_date" not in st.session_state:
    st.session_state.publication_date = dt.date.today()


# header
st.title("Respect Weather 🌍")
login()


# location
location = st.selectbox(
    "Select location:",
    options=locations["location"].tolist(),
    index=st.session_state.get("location_id", 876),
    placeholder="Location...",
    label_visibility="collapsed",
)
location_id = int(locations[locations["location"] == location].index[0])
latitiude = locations.at[location_id, "latitude"]
longitude = locations.at[location_id, "longitude"]


# main box
main_box = st.container(border=True)

col1, col2 = main_box.columns([12, 2])
col1.markdown("#### " + location)
col2.toggle("Favourite ⭐", value=False)

weather_forecast = get_weather_forecast(latitiude, longitude)
main_box.dataframe(weather_forecast)

col1, col2 = main_box.columns([10, 2])
col2.date_input(
    "Publication date",
    min_value=dt.date(2024, 5, 25),
    max_value=dt.date.today(),
    key="publication_date",
)


# favorites
def favClick(location_id):
    if not location_id in locations.index:
        return
    st.session_state["location_id"] = location_id


st.subheader("Favorites ⭐")
st.button(locations.at[876, "location"], on_click=favClick, args=(876,))
st.button(locations.at[955, "location"], on_click=favClick, args=(955,))

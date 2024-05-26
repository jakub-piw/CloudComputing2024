import datetime as dt
import os

import google_auth_oauthlib.flow
import streamlit as st
from googleapiclient.discovery import build

st.set_page_config(
    page_title="Respect Weather",
    page_icon="🌍",
    layout="wide",
)

st.title("Respect Weather 🌍")


flow = google_auth_oauthlib.flow.Flow.from_client_secrets_file(
    os.path.join((os.path.abspath(os.path.dirname(__file__))), "credentials.json"),
    scopes=["openid", "https://www.googleapis.com/auth/userinfo.email"],
)
flow.redirect_uri = "http://localhost:8080"
auth_uri, state = flow.authorization_url()
html_content = f"""
<div style="display: flex; justify-content: left;">
    <a href="{auth_uri}" target="_self" style="background-color: #fff'; color: #000; text-decoration: none; text-align: center; font-size: 16px; cursor: pointer; padding: 8px 12px; border-radius: 4px; display: flex; align-items: center;">
        <img src="https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9z_hELisAlapwE9LUPh6fcXIfb5vwpbMl4xl9H9TRFPc5NOO8Sb3VSgIBrfRYvW6cUA" alt="Google logo" style="margin-right: 8px; width: 20px; height: 20px; background-color: white; border: 2px solid white; border-radius: 4px;">
        Sign in with Google
    </a>
</div>
"""
auth_code = st.query_params.get("code")
st.query_params.clear()
if auth_code:
    flow.fetch_token(code=auth_code)
    credentials = flow.credentials
    user_info_service = build(
        serviceName="oauth2",
        version="v2",
        credentials=credentials,
    )
    user_info = user_info_service.userinfo().get().execute()

    st.markdown("Logged in as: " + user_info.get("email") + " 🎉")
else:
    st.markdown(html_content, unsafe_allow_html=True)


def onClick(selection_input):
    if selection_input == "A":
        st.session_state["selection"] = 0
    if selection_input == "B":
        st.session_state["selection"] = 1


if "selection" not in st.session_state:
    st.session_state["selection"] = 0

location = st.selectbox(
    "Select location:",
    options=["Warsaw", "Lodz", "Poznan"],
    index=st.session_state["selection"],
    placeholder="Location...",
    label_visibility="collapsed",
)

main_box = st.container(border=True)

col1, col2 = main_box.columns([12, 2])
col1.subheader(location)
col2.toggle("Favourite ⭐", value=False)

for i in range(4):
    cols = main_box.columns(4)
    for col in cols:
        weather_card = col.container(border=True, height=145)
        weather_card.markdown("**2024-05-27**")
        weather_card_cols = weather_card.columns(2)
        weather_card_cols[0].markdown("🌤️")
        weather_card_cols[1].markdown("🌧️ 10 mm")
        weather_card_cols = weather_card.columns(2)
        weather_card_cols[0].markdown("🌡️ 10°C")
        weather_card_cols[1].markdown("💨 10 km/h")

# ☀️, 🌤️, 🌥️, ☁️, 🌦️, 🌧️,

col1, col2 = main_box.columns([10, 2])
col2.date_input(
    "Publication date",
    value=dt.date(2024, 5, 27),
    min_value=None,
    max_value=None,
    key=None,
)


st.subheader("Favorites ⭐")
st.button("A", on_click=onClick, args=("A",))
st.button("B", on_click=onClick, args=("B",))

import os

import google_auth_oauthlib.flow
import streamlit as st
from googleapiclient.discovery import build


def login():
    flow = google_auth_oauthlib.flow.Flow.from_client_secrets_file(
        os.path.join(os.path.abspath(os.path.dirname(__file__)), "credentials.json"),
        scopes=["openid", "https://www.googleapis.com/auth/userinfo.email"],
    )
    flow.redirect_uri = "http://localhost:8080"

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
        st.session_state["email"] = user_info.get("email")
        print(user_info)

    email = st.session_state.get("email")
    if email is not None:
        st.markdown("Logged in as: " + email + " 🎉")
    else:
        auth_uri, state = flow.authorization_url()
        html_content = f"""
        <div style="display: flex; justify-content: left;">
            <a href="{auth_uri}" target="_self" style="background-color: #fff'; color: #000; text-decoration: none; text-align: center; font-size: 16px; cursor: pointer; padding: 8px 12px; border-radius: 4px; display: flex; align-items: center;">
                <img src="https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9z_hELisAlapwE9LUPh6fcXIfb5vwpbMl4xl9H9TRFPc5NOO8Sb3VSgIBrfRYvW6cUA" alt="Google logo" style="margin-right: 8px; width: 20px; height: 20px; background-color: white; border: 2px solid white; border-radius: 4px;">
                Sign in with Google
            </a>
        </div>
        """
        st.markdown(html_content, unsafe_allow_html=True)

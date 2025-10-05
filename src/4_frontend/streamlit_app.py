# streamlit_app.py
import streamlit as st
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
import json
import plotly.express as px
# import matplotlib.pyplot as plt
# import altair as alt

# -------------------------------
# 1️⃣ Connect to Snowflake
# -------------------------------
def create_snowflake_session():
    def get_config(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            config = json.load(f)
        return config
    def get_config_snowflake():
        GLOBAL_CONFIG_PATH = "market_config.json"
        config = get_config(GLOBAL_CONFIG_PATH)
        config_snowflake = config["snowflake"]
        return config_snowflake

    config_snowflake = get_config_snowflake()
    connection_params = {
        "user": config_snowflake["user"],
        "password" : config_snowflake["password"],
        "account": config_snowflake["account"],
        # "authenticator": "externalbrowser",
        # "role": "ACCOUNTADMIN",
        "warehouse": config_snowflake["warehouse"],
        "database": config_snowflake["database"],
        "schema": "ANALYTICS"
    }
    return Session.builder.configs(connection_params).create()

session = create_snowflake_session()

# -------------------------------
# 2️⃣ Load Data
# -------------------------------
# @st.cache_data(ttl=600)  # cache data for 10 min
# def load_data(symbol=None):
#     table = session.table("SIGNAL_EXTRACTION_DB.ANALYTICS.PREDICTED_PRICES")
#     if symbol:
#         table = table.filter(col("SYMBOL") == symbol)
#     df = table.select(
#         "DATE", "SYMBOL", "NEXT_DAY_CLOSE", "PREDICTED_CLOSE"
#     ).sort(col("DATE").asc()).to_pandas()
#     return df

@st.cache_data(ttl=600)
def load_data(symbol, start_date, end_date):
    # Ensure they are datetime.date
    if isinstance(start_date, pd.Timestamp):
        start_date = start_date.date()
    if isinstance(end_date, pd.Timestamp):
        end_date = end_date.date()
        
    table = session.table("SIGNAL_EXTRACTION_DB.ANALYTICS.PREDICTED_PRICES") \
                   .filter(col("SYMBOL") == symbol) \
                   .filter((col("DATE") >= start_date) & (col("DATE") <= end_date))
    
    df = table.select("DATE", "SYMBOL", "NEXT_DAY_CLOSE", "PREDICTED_CLOSE") \
              .sort(col("DATE").asc()).to_pandas()
    return df

# -------------------------------
# 3️⃣ Sidebar controls
# -------------------------------
st.sidebar.title("Controls")
symbol_list = session.table("SIGNAL_EXTRACTION_DB.ANALYTICS.PREDICTED_PRICES").select("SYMBOL").distinct().to_pandas()["SYMBOL"].tolist()
selected_symbol = st.sidebar.selectbox("Select Symbol", symbol_list)

# Date range slider
# Get min/max dates from the table
date_df = session.table("SIGNAL_EXTRACTION_DB.ANALYTICS.PREDICTED_PRICES") \
                 .select("DATE").sort(col("DATE").asc()).to_pandas()
min_date = pd.to_datetime("2025-01-01")  # default start date
max_date = pd.to_datetime(date_df["DATE"].max())

start_date, end_date = st.sidebar.date_input(
    "Select Date Range",
    value=[min_date, max_date],
    min_value=min_date,
    max_value=max_date
)

# -------------------------------
# 4️⃣ Load filtered data
# -------------------------------
# df = load_data(selected_symbol)
df = load_data(selected_symbol, start_date, end_date)

st.title(f"Price Prediction Dashboard: {selected_symbol}")
st.write(f"Showing data from {start_date} to {end_date}")

# -------------------------------
# 5️⃣ Line chart: Actual vs Predicted Close
# -------------------------------
fig = px.line(
    df,
    x="DATE",
    y=["NEXT_DAY_CLOSE", "PREDICTED_CLOSE"],
    labels={"value": "Price", "DATE": "Date", "variable": "Legend"},
    title=f"Actual vs Predicted Close Price for {selected_symbol}"
)
st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# 5️⃣ Line chart: Actual vs Predicted Close
# -------------------------------

# plt.figure(figsize=(10, 5))
# plt.plot(df["DATE"], df["NEXT_DAY_CLOSE"], label="Actual Close")
# plt.plot(df["DATE"], df["PREDICTED_CLOSE"], label="Predicted Close")
# plt.xlabel("Date")
# plt.ylabel("Price")
# plt.title(f"Actual vs Predicted Close: {selected_symbol}")
# plt.legend()
# st.pyplot(plt)

# -------------------------------
# 5️⃣ Line chart: Actual vs Predicted Close
# -------------------------------

# df["DATE"] = pd.to_datetime(df["DATE"])
# df["NEXT_DAY_CLOSE"] = df["NEXT_DAY_CLOSE"].astype(float)
# df["PREDICTED_CLOSE"] = df["PREDICTED_CLOSE"].astype(float)

# chart = alt.Chart(df).transform_fold(
#     ["NEXT_DAY_CLOSE", "PREDICTED_CLOSE"],
#     as_=["Type", "Price"]
# ).mark_line().encode(
#     x="DATE:T",
#     y="Price:Q",
#     color="Type:N",
#     tooltip=["DATE", "Type", "Price"]
# ).interactive()

# st.altair_chart(chart, use_container_width=True)

# -------------------------------
# 6️⃣ Show raw data
# -------------------------------
st.subheader("Underlying Data")
st.dataframe(df)

# -------------------------------
# 7️⃣ Optional: Add Metrics
# -------------------------------
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import numpy as np

if not df.empty:
    rmse = np.sqrt(mean_squared_error(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"]))
    mae = mean_absolute_error(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"])
    r2 = r2_score(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"])
    
    st.subheader("Model Performance Metrics")
    st.metric("RMSE", f"{rmse:.3f}")
    st.metric("MAE", f"{mae:.3f}")
    st.metric("R²", f"{r2:.3f}")

# -------------------------------
# 8️⃣ Optional: Future SHAP explainability integration
# -------------------------------
st.subheader("Feature Explainability (Coming Soon)")
st.text("You can add SHAP bar/waterfall plots here per prediction row.")

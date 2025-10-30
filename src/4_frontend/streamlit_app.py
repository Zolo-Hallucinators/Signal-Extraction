# streamlit_app.py
import streamlit as st
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
import json
import plotly.express as px
# import matplotlib.pyplot as plt
# import altair as alt
from datetime import date, timedelta, datetime

# -------------------------------
# Global Variables
# -------------------------------

GLOBAL_MARKET_TABLE = "SIGNAL_EXTRACTION_DB.ANALYTICS.PREDICTED_MARKET_DATA"
GLOBAL_NEWS_TABLE = "SIGNAL_EXTRACTION_DB.ANALYTICS.NEWS_ARTICLES_SENTIMENT_RANKED"

# -------------------------------
# Connect to Snowflake
# -------------------------------
def create_snowflake_session():
    def get_config(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            config = json.load(f)
        return config
    def get_config_snowflake(GLOBAL_CONFIG_PATH):
        config = get_config(GLOBAL_CONFIG_PATH)
        config_snowflake = config["snowflake"]
        return config_snowflake

    GLOBAL_CONFIG_PATH = "streamlit_config.json"
    config_snowflake = get_config_snowflake(GLOBAL_CONFIG_PATH)
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
# Load Data
# -------------------------------
@st.cache_data(ttl=600)
def load_market_data(symbol, start_date, end_date):
    # Ensure they are datetime.date
    if isinstance(start_date, pd.Timestamp):
        start_date = start_date.date()
    if isinstance(end_date, pd.Timestamp):
        end_date = end_date.date()
        
    table = session.table(GLOBAL_MARKET_TABLE) \
                   .filter(col("SYMBOL") == symbol) \
                   .filter((col("DATE") >= start_date) & (col("DATE") <= end_date))
    
    df = table.select("DATE", "SYMBOL", "NEXT_DAY_CLOSE", "PREDICTED_NEXT_DAY_CLOSE") \
              .sort(col("DATE").asc()).to_pandas()
    return df

# -------------------------------
# Sidebar controls
# -------------------------------
st.sidebar.title("Controls")
# Symbol Selector
symbol_list = session.table(GLOBAL_MARKET_TABLE).select("SYMBOL").distinct().to_pandas()["SYMBOL"].tolist()
selected_symbol = st.sidebar.selectbox("Select Symbol:", symbol_list)

# Entity Auto Select
entity_symbol_map = {
    'ORCL': 'Oracle',
    'PLTR': 'Palantir'
}
selected_entity = entity_symbol_map[selected_symbol]

# Date range Selector
date_df = session.table(GLOBAL_MARKET_TABLE) \
                 .select("DATE").sort(col("DATE").asc()).to_pandas()

min_date = pd.to_datetime("2025-09-01")  # default start date
max_date = pd.to_datetime(date_df["DATE"].max())
start_date, end_date = st.sidebar.date_input(
    "Select Date Range:",
    value=[min_date, max_date],
    min_value=min_date,
    max_value=max_date
)

# Drill Down Date Selector
default_date = pd.to_datetime("2025-10-25")
drill_down_date = st.sidebar.date_input(
    "Select Drill Down Date:",
    value=default_date
)

# -------------------------------
# Load filtered data
# -------------------------------
market_df = load_market_data(selected_symbol, start_date, end_date)

st.title(f"Price Analytics: {selected_symbol}")
st.write(f"Chosen Date Range: {start_date} to {end_date}")
st.write(f"Chosen Drill Down Date: {drill_down_date}")

# -------------------------------
# Line chart: Actual vs Predicted Close
# -------------------------------
st.subheader(f"Actual vs Predicted Close Price: {selected_symbol}")
fig = px.line(
    market_df,
    x="DATE",
    y=["NEXT_DAY_CLOSE", "PREDICTED_NEXT_DAY_CLOSE"],
    labels={"value": "Price", "DATE": "Date (Slider)", "variable": "Legend"},
    # title=f"Actual vs Predicted Close Price for {selected_symbol}",
    markers = True,
    # color_discrete_sequence=px.colors.qualitative.Set2
)
# fig.update_layout(
#     dragmode="select",   # or 'lasso'
#     hovermode="closest"
# )
# for trace in fig.data:
#     trace.update(
#         selected=dict(marker=dict(size=12, color="red")),
#         unselected=dict(marker=dict(opacity=0.5))
#     )
# Add date range slider
fig.update_layout(
    xaxis=dict(
        rangeslider=dict(visible=True),  # 👈 Enables the slider
        type="date"
    ),
    legend_title_text="Type",
    hovermode="x unified"
)
    
st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# Price Explainability
# -------------------------------
st.header(f"Price Explainability: {selected_symbol} on {drill_down_date}")
price_explainability_query = f"""
    SELECT *
    FROM {GLOBAL_MARKET_TABLE}
    WHERE SYMBOL = '{selected_symbol}'
      AND DATE = '{drill_down_date}'
"""
price_explainability_df = session.sql(price_explainability_query).to_pandas()
# print(price_explainability_df)

# --- Pretty print the single row ---
if price_explainability_df.empty:
    st.warning("No data found for this symbol and date.")
else:
    # Since you expect exactly one row, convert to dict
    row_dict = price_explainability_df.iloc[0].to_dict()

    st.subheader("📊 Indicators")
    st.json(row_dict)  # Streamlit pretty JSON-style output
    
    st.subheader("📊 Price Explainability")
    explainability_json = row_dict["EXPLAINABILITY"]
    # --- Step 1: Parse the JSON string ---
    try:
        explainability_dict = json.loads(explainability_json)
    except Exception as e:
        st.error(f"Failed to parse EXPLAINABILITY JSON: {e}")
        explainability_dict = {}

    # --- Step 2: Convert to DataFrame ---
    explain_df = pd.DataFrame(list(explainability_dict.items()), columns=["Feature", "Value"])
    
    # Optional: sort by absolute importance or value
    explain_df["abs_value"] = explain_df["Value"].abs()
    explain_df = explain_df.sort_values("abs_value", ascending=True)
    
    # --- Step 3: Plot a horizontal bar chart ---
    fig = px.bar(
        explain_df,
        x="Value",
        y="Feature",
        orientation="h",
        title="Feature Contribution (Explainability)",
        labels={"Value": "Impact", "Feature": "Feature Name"},
    )
    
    # Optional: Add color gradient for easier interpretation | Add inline text (absolute value labels)
    fig.update_traces(
        marker_color=explain_df["Value"],
        marker_colorscale="RdBu",
        marker_line_width=0.5,
        text=explain_df["abs_value"].round(2),  # show rounded absolute values
        textposition="inside",  # text inside the bar
        insidetextanchor="middle",
        textfont=dict(color="white", size=10)
    )
    fig.update_layout(
        height=800,
        yaxis=dict(title="", tickfont=dict(size=10)),
        xaxis=dict(title="Feature Impact on Prediction"),
        margin=dict(l=150, r=20, t=60, b=40)
    )
    
    # --- Step 4: Display in Streamlit ---
    st.plotly_chart(fig, use_container_width=True)

# -------------------------------
# Model Performance
# -------------------------------
st.subheader("📊 Model Performance Summary")

st.markdown(
    """
    <div style="
        background-color:#111827;
        border: 1px solid #333;
        border-radius: 10px;
        padding: 20px;
        color: #E5E7EB;
        font-family: 'Segoe UI', sans-serif;
        box-shadow: 0px 2px 4px rgba(0,0,0,0.2);
        line-height:1.6;
    ">

    <h4 style="color:#60A5FA;">🧠 GradientBoostingRegressor Results</h4>
    <p><b style="color:#FFD700;">RMSE:</b> 10.3324</p>
    <p><b>MAE:</b> 9.5678</p>
    <p><b>R²:</b> -4.6813</p>
    <p><b>MAPE:</b> 5.24%</p>

    <hr style="border:0.5px solid #333; margin:15px 0;">

    <h5 style="color:#60A5FA;">📈 Validation Performance Summary</h5>
    <table style="width:100%; border-collapse:collapse; margin-top:10px;">
        <thead style="background-color:#1F2937;">
            <tr>
                <th style="text-align:left; padding:8px;">Dataset</th>
                <th style="text-align:left; padding:8px;">Window</th>
                <th style="text-align:left; padding:8px;">RMSE</th>
                <th style="text-align:left; padding:8px;">MAPE</th>
                <th style="text-align:left; padding:8px;">R²</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td style="padding:8px;">Train</td>
                <td style="padding:8px;">All Train</td>
                <td style="padding:8px;">0.9747</td>
                <td style="padding:8px;">2.8127</td>
                <td style="padding:8px;">0.9995</td>
            </tr>
            <tr style="background-color:#1F2937;">
                <td style="padding:8px;">Validation</td>
                <td style="padding:8px;">Avg</td>
                <td style="padding:8px;">2.3153</td>
                <td style="padding:8px;">5.2253</td>
                <td style="padding:8px;">0.1119</td>
            </tr>
        </tbody>
    </table>
    </div>
    """,
    unsafe_allow_html=True
)


# -------------------------------
# Sentiment Explainability
# -------------------------------
st.header(f"Sentiment Explainability: {selected_symbol} on {drill_down_date}")
sentiment_explainability_query = f"""
    SELECT *
    FROM {GLOBAL_NEWS_TABLE}
    WHERE ENTITY_NAME = '{selected_entity}'
      AND PUBLISHED_DATE = '{drill_down_date}'
"""
sentiment_explainability_df = session.sql(sentiment_explainability_query).to_pandas()
# print(price_explainability_df)

# --- Pretty print the single row ---
if sentiment_explainability_df.empty:
    st.warning("No data found for this symbol and date.")
else:
    # Since you expect exactly one row, convert to dict
    sentiment_row_dict = sentiment_explainability_df.iloc[0].to_dict()

    # st.subheader("Raw Output")
    # st.json(sentiment_row_dict) #DEBUG

    # Extract article IDs
    article_ids = [v for k, v in sentiment_row_dict.items() if k.startswith("RANK_")]
    
    # Fetch data from Snowflake
    articles_df = (
        session.table("SIGNAL_EXTRACTION_DB.STAGING.NEWS_ARTICLES_FEATURES")
        .filter(col("ARTICLE_ID").isin(article_ids))
        .select(
            "ARTICLE_ID",
            "TITLE",
            "DESCRIPTION",
            "AUTHOR",
            "URL",
            "PUBLISHED_AT_UTC",
            "SENTIMENT_IMPACT_SCORE",
            "EVENT_TYPE",
            "NEWS_RELIABILITY",
            "RELEVANCE_CLASS",
            "NOVELTY_CLASS",
            "SECTOR"
        )
        .to_pandas()
    )
    # st.dataframe(articles_df) #DEBUG
    
    rank_colors = ["#FFD700", "#C0C0C0", "#CD7F32", "#87CEFA", "#90EE90"]  # gold → green

    # st.subheader(f"📰 Top 5 News Driving Sentiment for {sentiment_row_dict['ENTITY_NAME']} on {sentiment_row_dict['PUBLISHED_DATE']}")
    # for i, rank in enumerate(["RANK_1", "RANK_2", "RANK_3", "RANK_4", "RANK_5"], start=1):
    #     article_id = sentiment_row_dict[rank]
    #     row = articles_df[articles_df["ARTICLE_ID"] == article_id]
        
    #     if row.empty:
    #         continue
        
    #     r = row.iloc[0]
    #     title = r["TITLE"]
    #     description = r["DESCRIPTION"]
    #     author = r["AUTHOR"] if r["AUTHOR"] else "Unknown Author"
    #     url = r["URL"]
    #     published_at = r["PUBLISHED_AT_UTC"]
    #     sentiment = round(r["SENTIMENT_IMPACT_SCORE"], 3) if r["SENTIMENT_IMPACT_SCORE"] else None
    #     event_type = r["EVENT_TYPE"]
    #     reliability = r["NEWS_RELIABILITY"]
    #     relevance = r["RELEVANCE_CLASS"]
    #     novelty = r["NOVELTY_CLASS"]
    #     sector = r["SECTOR"]

        # --- Build UI Card ---
        # with st.container():
        #      st.markdown(
        #         f"""
        #         <div style="
        #             background-color:{rank_colors[i-1]};
        #             padding: 18px;
        #             border-radius: 15px;
        #             margin-bottom: 15px;
        #             color:black;
        #             box-shadow: 0px 3px 8px rgba(0,0,0,0.25);
        #         ">
        #             <h4 style="margin-bottom:5px;">🏆 Rank {i}: {title}</h4>
        #             <p style="font-size:13px; margin-bottom:8px; font-style:italic;">✍️ {author}</p>
        #             <p style="font-size:14px; margin-bottom:10px;">{description}</p>
        #             <a href="{url}" target="_blank" style="
        #                 display:inline-block;
        #                 background-color:#1E90FF;
        #                 color:white;
        #                 padding:8px 15px;
        #                 border-radius:8px;
        #                 text-decoration:none;
        #                 font-weight:600;
        #                 font-size:13px;
        #                 transition: all 0.3s ease;
        #             " onmouseover="this.style.backgroundColor='#0b70d0'" 
        #               onmouseout="this.style.backgroundColor='#1E90FF'">
        #                 🔗 Read Full Article
        #             </a>
        #         </div>
        #         """,
        #         unsafe_allow_html=True
        #     )
        # Subheader for context
    st.subheader(f"📰 Top 5 News Driving Sentiment for: {sentiment_row_dict['ENTITY_NAME']} on {sentiment_row_dict['PUBLISHED_DATE']}")

    rank_colors = ["#ffeaa7", "#fab1a0", "#81ecec", "#74b9ff", "#55efc4"]  # optional: 1 color per rank
    
    for i, rank in enumerate(["RANK_1", "RANK_2", "RANK_3", "RANK_4", "RANK_5"], start=1):
        article_id = sentiment_row_dict.get(rank)
        if not article_id:
            continue
    
        row = articles_df[articles_df["ARTICLE_ID"] == article_id]
        if row.empty:
            continue
    
        r = row.iloc[0]
        title = r.get("TITLE", "Untitled Article")
        description = r.get("DESCRIPTION", "No description available.")
        author = r.get("AUTHOR", "Unknown Author")
        url = r.get("URL", "#")
        published_at = r.get("PUBLISHED_AT_UTC", "N/A")
        sentiment = r.get("SENTIMENT_IMPACT_SCORE", None)
        event_type = r.get("EVENT_TYPE", "Unknown")
        reliability = r.get("NEWS_RELIABILITY", "Unknown")
        relevance = r.get("RELEVANCE_CLASS", "Unknown")
        novelty = r.get("NOVELTY_CLASS", "Unknown")
        sector = r.get("SECTOR", "Unknown")
    
        # --- Article UI Card ---
        with st.container():
             st.markdown(
                f"""
                <div style="
                    background-color:{rank_colors[i-1]};
                    padding: 18px;
                    border-radius: 15px;
                    margin-bottom: 15px;
                    color:black;
                    box-shadow: 0px 3px 8px rgba(0,0,0,0.25);
                ">
                    <h4 style="margin-bottom:5px;">🏆 Rank {i}: {title}</h4>
                    <p style="font-size:12px; margin-bottom:8px;"><b>Published:</b> {published_at}</p>
                    <p style="font-size:13px; margin-bottom:8px; font-style:italic;">✍️ {author}</p>
                    <p style="font-size:14px; margin-bottom:10px;">{description}</p>
                    <a href="{url}" target="_blank" style="
                        display:inline-block;
                        background-color:#1E90FF;
                        color:white;
                        padding:8px 15px;
                        border-radius:8px;
                        text-decoration:none;
                        font-weight:600;
                        font-size:13px;
                        transition: all 0.3s ease;
                    " onmouseover="this.style.backgroundColor='#0b70d0'" 
                      onmouseout="this.style.backgroundColor='#1E90FF'">
                        🔗 Read Full Article
                    </a>
                """,
                unsafe_allow_html=True
            )
    
        # --- Expandable sentiment metadata ---
        with st.expander("🧠 View Sentiment & Classification Details"):
            st.markdown(f"""
            **Sentiment Impact Score:** {sentiment if sentiment is not None else "N/A"}  
            **Event Type:** {event_type}  
            **News Reliability:** {reliability}  
            **Relevance Class:** {relevance}  
            **Novelty Class:** {novelty}  
            **Sector:** {sector}
            """)
        # Close the card container
        st.markdown("</div>", unsafe_allow_html=True)


# -------------------------------
# Show raw data
# -------------------------------
st.header("📈 Underlying Chart Data")
st.dataframe(market_df)

# # -------------------------------
# # 7️⃣ Optional: Add Metrics
# # -------------------------------
# from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
# import numpy as np

# if not df.empty:
#     rmse = np.sqrt(mean_squared_error(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"]))
#     mae = mean_absolute_error(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"])
#     r2 = r2_score(df["NEXT_DAY_CLOSE"], df["PREDICTED_CLOSE"])
    
#     st.subheader("Model Performance Metrics")
#     st.metric("RMSE", f"{rmse:.3f}")
#     st.metric("MAE", f"{mae:.3f}")
#     st.metric("R²", f"{r2:.3f}")

# # -------------------------------
# # 8️⃣ Optional: Future SHAP explainability integration
# # -------------------------------
# st.subheader("Feature Explainability (Coming Soon)")
# st.text("You can add SHAP bar/waterfall plots here per prediction row.")

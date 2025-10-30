# 🚀 Signal Extraction ML Pipeline
*A Snowflake-powered end-to-end machine learning pipeline for financial signal generation and prediction.*

---

![Python](https://img.shields.io/badge/Python-3.9%2B-blue)
![Snowflake](https://img.shields.io/badge/Snowflake-Data%20Cloud-lightblue)
![Machine Learning](https://img.shields.io/badge/ML-XGBoost-green)
![Gradient Regressor](https://img.shields.io/badge/ML-Gradient%20Regressor-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-Active-success)

---

## 📖 Overview

This project was developed as part of the **Snowflake Hackathon - The Dev Primere League**, focusing on building a complete **data ingestion → transformation → prediction → visualization** pipeline.  
It leverages **Snowflake’s Data Cloud**, **Snowpark**, and **Python ML libraries** to extract meaningful trading signals from financial and news data.

The goal: **generate predictive buy/sell signals** by combining **market price movements** and **news sentiment analysis** — all within a scalable Snowflake architecture.

---

## 🧠 Features

✅ **Automated Data Ingestion**
- Fetches stock price data via [Alpha Vantage API](https://www.alphavantage.co/)  
- Collects related financial news via [News API](https://newsapi.org/)

✅ **Feature generation (price & sentiment)**  
- Technical indicators: EMA, RSI, MACD and additional momentum/volatility features derived from price time series.  
- News/sentiment features: polarity, subjectivity, entity-level signals, recency and source weighting for each article.

✅ **Explainability for price & sentiment**  
- Model- and feature-level explanations (SHAP / feature importance) for both price indicators and sentiment inputs(aritcle impact analysis), surfaced per prediction to justify signals.

✅ **Backtest engine**  
- Event-driven backtester that simulates trade execution, transaction costs, PnL, Sharpe, drawdown and other portfolio metrics to validate strategy profitability.

✅ **Fully automated orchestration**  
- End-to-end scheduling using Snowflake Tasks & Streams (Airflow-compatible) to automate ingestion → transform → training → scoring → backtests on a configurable cadence.

✅ **ML pipeline & sentiment classification**  
- Training and inference with XGBoost and GradientRegressor implemented in Snowpark/Python.  
- AI_CLASSIFY used for news sentiment labeling and an annotated dataset maintained for live news to improve and validate classifiers.

✅ **Visualization layer**  
- Streamlit application for interactive dashboards: signal explorer, explainability overlays, backtest results, and model performance monitoring.

---

## 🧰 Tech Stack

| Layer | Technology | Purpose |
|-------|-------------|----------|
| **Data Storage** | Snowflake (**SIGNAL_EXTRACTION_DB**) | Centralized data warehouse |
| **Compute** | Snowflake Warehouse (**COMPUTE_WH**) | Scalable compute for ETL + ML |
| **Ingestion** | Python, REST APIs | Pulls stock + news data |
| **Transformation** | Snowflake SQL, Snowpark | Data cleaning and feature creation |
| **ML** | Python (XGBoost, Pandas), Snowflake Libs | Model training & prediction |
| **Visualization** | Streamlit | Application & Reporing layer |

---

## 🎬 Submission & Showcase Resources

- Idea Submission PPT (5 Oct 2025): [View PPT](https://docs.google.com/presentation/d/1A272S39itsuTwZJN7cSLmhS9Qb8TdQCz/edit?usp=drive_link&ouid=111214650582844966665&rtpof=true&sd=true)  
- Demo video submission record (5 Oct 2025): [Watch here](https://docs.google.com/spreadsheets/d/13Ox-XF97oV5iL6ayVca-iZSWQKuh_CHZ2eAQudx7dWA/edit?usp=drive_link)  
- Pitch deck / PPT (30 Oct 2025): [View PPT](https://docs.google.com/document/d/1c9Qy6GgJpTSRA4xQ8zxRiReXrwkVUUJwiLLs-sSE3p8/edit?usp=drive_link)  
- Streamlit Dashboard/Application (30 Oct 2025): [View here](https://app.snowflake.com/us-east-1/lac70367/#/streamlit-apps/SIGNAL_EXTRACTION_DB.UTILS.AINREU5NXYDJBG2Y)


## 🧩 Architecture

[![Architecture](./docs/Diagrams/Architecture-and-Flow-Diagram.png)](./docs/Diagrams/Architecture-and-Flow-Diagram.png)

## 🗂️ Use Case & Repository Structure

<details>
<summary>🧑‍💼 <b>Use Case Diagram</b> (click to expand)</summary>

[![Use Case Diagram](./docs/media/UseCase-1.png)](./docs/media/UseCase-1.png)
</details>

---

<details>
<summary>🗂️ <b>Repository Structure</b> (click to expand)</summary>

```
📦 signal-extraction-ml-pipeline
├── 📁 src/
│   ├── 1_ingestion/
│   │   ├── 1_ingest_market_api.ipynb
│   │   ├── 1_ingest_news_api.ipynb
│   │   ├── market_config.json
│   │   └── news_config.json
│   ├── 2_transformation_and_feature_engineering/
│   │   └── 1_transformation_and_feature_engineering_market_data.sql
│   ├── 3_ml/
│   │   ├── 1_analyze_news_data.ipynb
│   │   ├── 1_predict_market_data.ipynb
│   │   ├── environment.yml
│   │   └── market_config.json
│   ├── 4_frontend/
│   │   ├── streamlit_app.py
│   │   ├── environment.yml
│   │   └── market_config.json
│   └── infra/
├── 📁 docs/
├── requirements.txt
├── README.md
└── LICENSE
```
</details>

---

## ⚙️ Setup & Installation

### 1️⃣ **Prerequisites**
- Python 3.9+
- Snowflake account with appropriate roles
- Alpha Vantage & News API keys
- Snowflake Python Connector installed

### 2️⃣ **Clone the Repository**
```bash
git clone https://github.com/<your-username>/signal-extraction-ml-pipeline.git
cd signal-extraction-ml-pipeline
```

### 3️⃣ **Install Dependencies**
```bash
pip install -r requirements.txt
```

### 4️⃣ **Configure Environment**
Edit `configs/snowflake_config.json`:
```json
{
  "account": "XXXXXX",
  "user": "YOUR_USERNAME",
  "password": "YOUR_PASSWORD",
  "role": "ACCOUNTADMIN",
  "warehouse": "COMPUTE_WH",
  "database": "SIGNAL_EXTRACTION_DB",
  "schema": "RAW"
}
```

### 5️⃣ **Run Pipeline**
```bash
# Infra Setup
execute infra/{code}
# Ingestion Execution
python src/1_ingestion/1_ingest_market_api.ipynb
python src/1_ingestion/1_ingest_news_api.py
# Transformation & Feature Generation Execution
execute 2_transformation_and_feature_engineering/1_transform_and_feature_engineering_market_data.sql
python 2_transformation_and_feature_engineering/1_generate_news_articles_features.ipynb
# ML Execution
python src/3_ml/1_analyze_news_data.sql
python src/3_ml/1_predict_market_data.ipynb
python src/3_ml/2_backtest_market_data.ipynb
# Visualization Application Setup
python src/4_frontend/streamlit_app.py
```

---

## 📊 Prediction Outputs
### Price Prediction
| Symbol | Date | Predicted Signal | Confidence |
|--------|------|------------------|-------------|
| AAPL | 2025-10-01 | **Buy** | 0.87 |
| ORCL | 2025-10-01 | **Sell** | 0.78 |
| TSLA | 2025-10-01 | **Hold** | 0.65 |
### Sentiment Analysis
[TODO]

---

## 📊 Visualization Outputs
[TODO]

---

## 🧑‍💻 Author

**Aravind Suresh**  
Data Engineer @ GE Aerospace | ML & Cloud Enthusiast  
📍 [LinkedIn](https://www.linkedin.com/in/aravind-suresh8) • [GitHub](https://github.com/aravxdev)

**Abirami Sadasivam**  
SDE @ VISA | ML & Cloud Enthusiast  
📍 [LinkedIn](https://linkedin.com/in/abirami-sadasivam) • [GitHub](https://github.com/abixdev)

**Sidhanth LS**  
Data Scientist @ Freshworks  
📍 [LinkedIn](https://linkedin.com/in/sidhantls) • [GitHub](https://github.com/xxx)

---

## 🪶 License

This project is licensed under the [MIT License](LICENSE).

---

## 🏁 Acknowledgments

Special thanks to:
- **Snowflake** for its developer ecosystem  
- **Alpha Vantage** and **News API** for financial data sources  
- **Hackathon Mentors** and collaborators for their support ([Snowflake - The Dev Premiere League](https://vision.hack2skill.com/event/gcc-dev-premier-league-2025))

---

⭐ *If you like this project, give it a star on GitHub — your support keeps it growing!*

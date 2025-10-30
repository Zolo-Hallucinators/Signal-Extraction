import numpy as np
import pandas as pd


def _ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def _rsi(close: pd.Series, period: int = 14) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0.0)
    loss = -delta.clip(upper=0.0)
    avg_gain = gain.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    rs = avg_gain / (avg_loss.replace(0, np.nan))
    rsi = 100 - (100 / (1 + rs))
    return rsi


def _macd(close: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9) -> tuple[pd.Series, pd.Series, pd.Series]:
    ema_fast = _ema(close, fast)
    ema_slow = _ema(close, slow)
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    hist = macd_line - signal_line
    return macd_line, signal_line, hist


def _rolling_volatility(close: pd.Series, window: int) -> pd.Series:
    returns = close.pct_change()
    return returns.rolling(window=window, min_periods=window).std()


def apply_close_based_features(df: pd.DataFrame, close_col: str = "CLOSE_DERIVED") -> pd.DataFrame:
    """
    Compute close-based features in-place on df using the provided close column.

    Expected output columns (created/updated if present in df):
      - MA_5, MA_10, MA_20, MA_50
      - EMA_12, EMA_26
      - RSI_14
      - MACD, MACD_SIGNAL, MACD_HISTOGRAM
      - VOLATILITY_5D, VOLATILITY_10D, VOLATILITY_20D
      - CLOSE_LAG_1, CLOSE_LAG_2, CLOSE_LAG_3, CLOSE_LAG_5
      - ROLLING_MAX_20, ROLLING_MIN_20
      - DISTANCE_FROM_HIGH_20, DISTANCE_FROM_LOW_20

    Any non-close-based features (e.g., volume or ATR) should be handled by the caller
    (e.g., forward-filled for future rows).
    """
    if close_col not in df.columns:
        raise KeyError(f"Expected close column '{close_col}' not found in DataFrame")

    close = df[close_col]

    # Simple moving averages
    df["MA_5"] = close.rolling(window=5, min_periods=5).mean()
    df["MA_10"] = close.rolling(window=10, min_periods=10).mean()
    df["MA_20"] = close.rolling(window=20, min_periods=20).mean()
    df["MA_50"] = close.rolling(window=50, min_periods=50).mean()

    # Exponential moving averages
    df["EMA_12"] = _ema(close, 12)
    df["EMA_26"] = _ema(close, 26)

    # RSI
    df["RSI_14"] = _rsi(close, 14)

    # MACD
    macd_line, signal_line, hist = _macd(close, 12, 26, 9)
    df["MACD"] = macd_line
    df["MACD_SIGNAL"] = signal_line
    df["MACD_HISTOGRAM"] = hist

    # Volatility (rolling std of returns)
    df["VOLATILITY_5D"] = _rolling_volatility(close, 5)
    df["VOLATILITY_10D"] = _rolling_volatility(close, 10)
    df["VOLATILITY_20D"] = _rolling_volatility(close, 20)

    # Lags
    df["CLOSE_LAG_1"] = close.shift(1)
    df["CLOSE_LAG_2"] = close.shift(2)
    df["CLOSE_LAG_3"] = close.shift(3)
    df["CLOSE_LAG_5"] = close.shift(5)

    # Rolling extrema and distances
    roll_max_20 = close.rolling(window=20, min_periods=20).max()
    roll_min_20 = close.rolling(window=20, min_periods=20).min()
    df["ROLLING_MAX_20"] = roll_max_20
    df["ROLLING_MIN_20"] = roll_min_20
    df["DISTANCE_FROM_HIGH_20"] = (roll_max_20 - close) / roll_max_20.replace(0, np.nan)
    df["DISTANCE_FROM_LOW_20"] = (close - roll_min_20) / roll_min_20.replace(0, np.nan)

    return df

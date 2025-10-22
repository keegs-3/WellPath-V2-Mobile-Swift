#!/usr/bin/env python3
"""
Insert test biometric data directly to Supabase via REST API
Uses exact biometric names from biometrics_base table
"""

import random
import uuid
from datetime import datetime, timedelta
import json

# User details
USER_ID = "8B79CE33-02B8-4F49-8268-3204130EFA82"
BASE_DATE = datetime(2025, 10, 16, 5, 15, 41)

# Biometric types with typical values and units - MATCHING DATABASE NAMES
BIOMETRIC_TYPES = {
    "VO2 Max": {"value": 55.0, "unit": "mL/kg/min"},
    "Resting Heart Rate": {"value": 65.0, "unit": "bpm"},
    "HRV": {"value": 45.0, "unit": "ms"},
    "Blood Pressure (Systolic)": {"value": 120.0, "unit": "mmHg"},
    "Blood Pressure (Diastolic)": {"value": 80.0, "unit": "mmHg"},
    "Weight": {"value": 75.0, "unit": "kg"},
    "Bodyfat": {"value": 20.0, "unit": "%"},
    "BMI": {"value": 23.5, "unit": "kg/m²"},
    "Steps/Day": {"value": 8000.0, "unit": "steps"},
    "Total Sleep": {"value": 7.5, "unit": "hours"},
    "Deep Sleep": {"value": 1.5, "unit": "hours"},
    "REM Sleep": {"value": 1.8, "unit": "hours"},
}

def generate_value(base_value, variance_pct=0.25):
    """Generate a value with given variance percentage"""
    variance = base_value * variance_pct
    return base_value + random.uniform(-variance, variance)

def generate_date(base_date, months_ago):
    """Generate a date N months ago from base date"""
    return base_date - timedelta(days=30 * months_ago)

# Generate all records
records = []
for biometric_name, info in BIOMETRIC_TYPES.items():
    base_value = info["value"]
    unit = info["unit"]

    # Generate 3 data points: current, 3 months ago, 6 months ago
    for months_ago in [0, 3, 6]:
        value = generate_value(base_value)
        date = generate_date(BASE_DATE, months_ago)

        record = {
            "id": str(uuid.uuid4()),
            "user_id": USER_ID,
            "biometric_name": biometric_name,
            "value": round(value, 1),
            "unit": unit,
            "recorded_at": date.isoformat() + "+00:00",
            "source": "manual"
        }
        records.append(record)

print(json.dumps(records, indent=2))

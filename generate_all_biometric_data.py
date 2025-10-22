#!/usr/bin/env python3
"""
Generate test biometric data for all biometric types
Creates 3 data points for each biometric: current, 3 months ago, 6 months ago
With 25% randomness applied to each value
"""

import random
import uuid
from datetime import datetime, timedelta

# User details
USER_ID = "8B79CE33-02B8-4F49-8268-3204130EFA82"

# Base date (current)
BASE_DATE = datetime(2025, 10, 16, 5, 15, 41)

# Biometric types with typical values and units
BIOMETRIC_TYPES = {
    "VO2 Max": {"value": 55.0, "unit": "mL/kg/min"},
    "Resting Heart Rate": {"value": 65.0, "unit": "bpm"},
    "Heart Rate Variability": {"value": 45.0, "unit": "ms"},
    "Systolic Blood Pressure": {"value": 120.0, "unit": "mmHg"},
    "Diastolic Blood Pressure": {"value": 80.0, "unit": "mmHg"},
    "Body Weight": {"value": 75.0, "unit": "kg"},
    "Body Fat Percentage": {"value": 20.0, "unit": "%"},
    "BMI": {"value": 23.5, "unit": "kg/m²"},
    "Lean Mass": {"value": 60.0, "unit": "kg"},
    "Active Energy": {"value": 500.0, "unit": "kcal"},
    "Steps": {"value": 8000.0, "unit": "steps"},
    "Walking Running Distance": {"value": 6.0, "unit": "km"},
    "Flights Climbed": {"value": 10.0, "unit": "flights"},
    "Sleep Duration": {"value": 7.5, "unit": "hours"},
    "Deep Sleep": {"value": 1.5, "unit": "hours"},
    "REM Sleep": {"value": 1.8, "unit": "hours"},
    "Sleep Efficiency": {"value": 85.0, "unit": "%"},
}

def generate_value(base_value, variance_pct=0.25):
    """Generate a value with given variance percentage"""
    variance = base_value * variance_pct
    return base_value + random.uniform(-variance, variance)

def generate_date(base_date, months_ago):
    """Generate a date N months ago from base date"""
    return base_date - timedelta(days=30 * months_ago)

def generate_sql_statements():
    """Generate SQL INSERT statements for all biometric data"""
    print("-- Generated Biometric Test Data")
    print(f"-- User ID: {USER_ID}")
    print(f"-- Base Date: {BASE_DATE.isoformat()}")
    print()

    for biometric_name, info in BIOMETRIC_TYPES.items():
        base_value = info["value"]
        unit = info["unit"]

        print(f"-- {biometric_name}")

        # Generate 3 data points: current, 3 months ago, 6 months ago
        for months_ago in [0, 3, 6]:
            value = generate_value(base_value)
            date = generate_date(BASE_DATE, months_ago)
            record_id = str(uuid.uuid4())

            sql = f"""INSERT INTO patient_biometric_readings (id, user_id, biometric_name, value, unit, recorded_at, source, created_at, updated_at)
VALUES ('{record_id}', '{USER_ID}', '{biometric_name}', {value:.1f}, '{unit}', '{date.isoformat()}+00:00', 'manual', NOW(), NOW());"""
            print(sql)

        print()

if __name__ == "__main__":
    generate_sql_statements()

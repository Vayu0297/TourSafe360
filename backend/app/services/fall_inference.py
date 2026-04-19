"""
TourSafe360 v2 — Fall Detection Inference Service
Bridges FastAPI backend with the trained FallEquipmentNet model
"""
import sys
sys.path.append('/home/srh/TourSafe360ML')

import asyncio
from concurrent.futures import ThreadPoolExecutor
import numpy as np

_engine = None
_executor = ThreadPoolExecutor(max_workers=2)

def _load_engine():
    global _engine
    try:
        from fall_detection_v2 import RealTimeFallEngine
        _engine = RealTimeFallEngine('/home/srh/TourSafe360ML/exports/fall_equipment_net.pt')
        print("✅ Fall detection engine loaded")
    except Exception as e:
        print(f"⚠️ Fall engine load failed: {e}")
        _engine = None

def _predict_sync(sensor_data: dict) -> dict:
    global _engine
    if _engine is None:
        _load_engine()
    if _engine is None:
        return {"fall_detected": False, "error": "Model not loaded"}
    try:
        return _engine.process_sensor_reading(
            sensor_data.get('ax', 0), sensor_data.get('ay', 0), sensor_data.get('az', 9.8),
            sensor_data.get('gx', 0), sensor_data.get('gy', 0), sensor_data.get('gz', 0),
            sensor_data.get('mx', 20), sensor_data.get('my', 10), sensor_data.get('mz', 45),
            sensor_data.get('baro', 1013), sensor_data.get('hr', 72), sensor_data.get('spo2', 98),
            sensor_data.get('zone', 'mountain')
        )
    except Exception as e:
        return {"fall_detected": False, "error": str(e)}

async def predict_fall(sensor_data: dict) -> dict:
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(_executor, _predict_sync, sensor_data)
    return result or {"fall_detected": False, "status": "buffering"}

# Load on import
_load_engine()

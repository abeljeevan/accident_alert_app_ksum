"""Reference API for the Accident Alert Smart Emergency Corridor demo.

Ambulance assignment and signal priority are simulated. This service does not
dispatch real vehicles or control traffic infrastructure.
"""
from datetime import datetime, timezone
from threading import Lock
from uuid import uuid4

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Accident Alert Emergency Corridor API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

class IncidentIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    occurred_at: datetime | None = None
    severity: str = "Emergency"

_lock = Lock()
_incidents: list[dict] = []
_ambulances = ["AMB-01", "AMB-02", "AMB-03"]

@app.get("/health")
def health():
    return {"status": "ok", "mode": "simulation"}

@app.post("/api/emergency-corridors")
def create_corridor(incident: IncidentIn):
    with _lock:
        available = next((a for a in _ambulances if not any(i["ambulance_id"] == a and i["status"] == "active" for i in _incidents)), None)
        record = {
            "incident_id": str(uuid4()),
            "latitude": incident.latitude,
            "longitude": incident.longitude,
            "occurred_at": (incident.occurred_at or datetime.now(timezone.utc)).isoformat(),
            "severity": incident.severity,
            "ambulance_id": available or "DEMO-AMB-01",
            "status": "active",
            "simulated": True,
            "message": "Demo dispatch assignment; vehicle movement and signal priority are simulated.",
        }
        _incidents.insert(0, record)
        return record

@app.get("/api/emergency-corridors")
def list_corridors():
    with _lock:
        return {"incidents": list(_incidents)}

@app.post("/api/emergency-corridors/{incident_id}/complete")
def complete_corridor(incident_id: str):
    with _lock:
        for incident in _incidents:
            if incident["incident_id"] == incident_id:
                incident["status"] = "completed"
                return incident
    return {"error": "incident not found"}

# Emergency Corridor API (simulation)

This optional FastAPI service accepts GPS incident reports and exposes them to a simple dashboard client through `GET /api/emergency-corridors`. It assigns a demo ambulance identifier in memory. Assignment, vehicle movement, and traffic signal priority are simulated; it does not dispatch a real ambulance or control signals. Data is lost when the process restarts.

Run on a trusted development network:

```powershell
py -m pip install -r backend/requirements.txt
py -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Start Flutter with `--dart-define=CORRIDOR_API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000`. Use the computer's reachable LAN address for a physical Android device. If unset or unreachable, the app labels the corridor as simulated and keeps its local dashboard available.

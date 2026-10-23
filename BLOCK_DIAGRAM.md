# System Architecture - Block Diagram

## Visual Block Diagram

```mermaid
graph TB
    subgraph UI["USER INTERFACE LAYER"]
        UI1["Home Page<br/>(Start/Stop Detection)"]
        UI2["Contacts Manager<br/>(Emergency Contacts)"]
        UI3["Crash Reports<br/>(XAI Insights)"]
        UI4["Hospital Map<br/>(Route Visualization)"]
        UI5["Edge AI Test<br/>(Manual Testing)"]
    end

    subgraph Backend["BACKEND LAYER"]
        B1["Sensor Manager<br/>(100 Hz Sampling)"]
        B2["Feature Extractor<br/>(19 Features)"]
        B3["Emergency Handler<br/>(SMS + GPS)"]
        B4["Contact Store<br/>(Local Storage)"]
        B5["Hospital Service<br/>(Finder)"]
        B6["Routing Service<br/>(OSRM API)"]
        B7["PDF Generator<br/>(Crash Reports)"]
        B8["Log Store<br/>(Event History)"]
    end

    subgraph AI["AI MODEL LAYER"]
        AI1["Edge AI Detector<br/>(On-Device Inference)"]
        AI2["Layer 1: Shake Filter"]
        AI3["Layer 2: Random Forest<br/>(100 Trees, 14.74 MB)"]
        AI4["Layer 3: Confidence Check<br/>(≥75% Threshold)"]
        AI5["Feature Importance<br/>Analyzer (XAI)"]
    end

    subgraph DB["DATABASE LAYER"]
        DB1["Local Storage<br/>• Contacts<br/>• Logs<br/>• Reports<br/>• Preferences"]
        DB2["Model Assets<br/>• RF Model (JSON)<br/>• Feature Importance<br/>• Metadata"]
    end

    subgraph Deploy["DEPLOYMENT ENVIRONMENT"]
        D1["Mobile Devices<br/>iOS 12+ / Android 6.0+<br/>Flutter 3.x / Dart 3.x"]
        D2["External APIs<br/>• OSRM Routing<br/>• Overpass API<br/>• SMS Service<br/>• Maps API"]
    end

    UI1 --> B1
    UI2 --> B4
    UI3 --> B8
    UI4 --> B5
    UI5 --> AI1

    B1 --> B2
    B2 --> AI1
    AI1 --> AI2
    AI2 --> AI3
    AI3 --> AI4
    AI4 --> B3
    AI4 --> AI5
    B3 --> B4
    B3 --> B5
    B5 --> B6
    AI5 --> B7
    
    B4 --> DB1
    B8 --> DB1
    AI3 --> DB2
    AI5 --> DB2
    
    B5 --> D2
    B6 --> D2
    B3 --> D2
    
    D1 -.-> UI
    D1 -.-> Backend
    
    classDef uiStyle fill:#E3F2FD,stroke:#1976D2,stroke-width:2px
    classDef backendStyle fill:#FFF3E0,stroke:#F57C00,stroke-width:2px
    classDef aiStyle fill:#F3E5F5,stroke:#7B1FA2,stroke-width:2px
    classDef dbStyle fill:#E8F5E9,stroke:#388E3C,stroke-width:2px
    classDef deployStyle fill:#FFF9C4,stroke:#F57F17,stroke-width:2px
    
    class UI1,UI2,UI3,UI4,UI5 uiStyle
    class B1,B2,B3,B4,B5,B6,B7,B8 backendStyle
    class AI1,AI2,AI3,AI4,AI5 aiStyle
    class DB1,DB2 dbStyle
    class D1,D2 deployStyle
```

---

## Layer Descriptions

### 🔵 **User Interface Layer**
- **Home Page**: Main interface for starting/stopping accident detection
- **Contacts Manager**: Configure emergency contacts for SMS alerts
- **Crash Reports**: View past accidents with XAI explanations
- **Hospital Map**: Visualize nearby hospitals and routes
- **Edge AI Test**: Manual testing interface for developers

### 🟠 **Backend Layer**
- **Sensor Manager**: Collects accelerometer, gyroscope, GPS data at 100 Hz
- **Feature Extractor**: Generates 19 ML features from 2-second sliding windows
- **Emergency Handler**: Dispatches SMS alerts with GPS coordinates
- **Contact Store**: Manages emergency contact information locally
- **Hospital Service**: Finds nearby hospitals using Overpass API
- **Routing Service**: Calculates optimal routes using OSRM API
- **PDF Generator**: Creates crash reports with XAI insights
- **Log Store**: Maintains event history and false alarm logs

### 🟣 **AI Model Layer**
- **Edge AI Detector**: Main orchestrator for on-device ML inference
- **Layer 1 - Shake Filter**: Quick pattern-based pre-filter
- **Layer 2 - Random Forest**: 100-tree classifier (14.74 MB model)
- **Layer 3 - Confidence Check**: Validates predictions with ≥75% threshold
- **Feature Importance Analyzer**: Generates XAI explanations

### 🟢 **Database Layer**
- **Local Storage**: Contacts, logs, reports, user preferences (Hive/SharedPreferences)
- **Model Assets**: RF model JSON, feature importance CSV, metadata

### 🟡 **Deployment Environment**
- **Mobile Devices**: iOS 12+, Android 6.0+, Flutter 3.x, Dart 3.x
- **External APIs**: OSRM routing, Overpass hospital data, SMS service, Maps API

---

## Data Flow

```
Sensors (100Hz) → Feature Extraction (19 features) → 3-Layer Detection 
    → Decision (REAL/FAKE) → Emergency Response (SMS + Routing)
```

---

## Export Options

To export this diagram as an image:
1. **Online**: Visit https://mermaid.live/ and paste the code above
2. **VS Code**: Use "Markdown Preview Mermaid Support" extension
3. **CLI**: Use `mmdc -i BLOCK_DIAGRAM.md -o block_diagram.png` (requires mermaid-cli)

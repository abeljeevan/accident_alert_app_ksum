# Model Performance Metrics Visualization

## 📊 Diagram 1: Simple Confusion Matrix

```mermaid
graph TB
    subgraph CM[" "]
        direction LR
        
        TN["TRUE NEGATIVE<br/><br/>309<br/><br/>93.07%"]
        FP["FALSE POSITIVE<br/><br/>23<br/><br/>6.93%"]
        FN["FALSE NEGATIVE<br/><br/>103<br/><br/>79.23%"]
        TP["TRUE POSITIVE<br/><br/>27<br/><br/>20.77%"]
    end
    
    classDef tnStyle fill:#4CAF50,stroke:#2E7D32,stroke-width:4px,color:#fff,font-size:16px
    classDef tpStyle fill:#2196F3,stroke:#1565C0,stroke-width:4px,color:#fff,font-size:16px
    classDef fpStyle fill:#FF9800,stroke:#E65100,stroke-width:4px,color:#fff,font-size:16px
    classDef fnStyle fill:#F44336,stroke:#C62828,stroke-width:4px,color:#fff,font-size:16px
    
    class TN tnStyle
    class TP tpStyle
    class FP fpStyle
    class FN fnStyle
```

**Legend:**
- 🟢 **Green**: Correctly identified FAKE (True Negative)
- 🔵 **Blue**: Correctly identified REAL (True Positive)
- 🟠 **Orange**: FAKE predicted as REAL (False Positive)
- 🔴 **Red**: REAL predicted as FAKE (False Negative)

---

## 📈 Diagram 2: Performance Metrics

```mermaid
graph LR
    ACC["ACCURACY<br/><br/>72.73%"]
    PREC["PRECISION<br/><br/>54.00%"]
    REC["RECALL<br/><br/>20.77%"]
    SPEC["SPECIFICITY<br/><br/>93.07%"]
    F1["F1-SCORE<br/><br/>30.00%"]
    
    classDef goodStyle fill:#4CAF50,stroke:#2E7D32,stroke-width:4px,color:#fff,font-size:18px
    classDef poorStyle fill:#F44336,stroke:#C62828,stroke-width:4px,color:#fff,font-size:18px
    classDef neutralStyle fill:#2196F3,stroke:#1565C0,stroke-width:4px,color:#fff,font-size:18px
    
    class ACC,SPEC goodStyle
    class REC,F1 poorStyle
    class PREC neutralStyle
```

**Performance Rating:**
- 🟢 **Green**: Good performance (>70%)
- 🔴 **Red**: Needs improvement (<40%)
- 🔵 **Blue**: Moderate performance (40-70%)

---

## 📊 Diagram 3: Metric Formulas

```mermaid
graph TB
    A["ACCURACY<br/>TP + TN / Total<br/>336 / 462"]
    B["PRECISION<br/>TP / TP + FP<br/>27 / 50"]
    C["RECALL<br/>TP / TP + FN<br/>27 / 130"]
    D["SPECIFICITY<br/>TN / TN + FP<br/>309 / 332"]
    E["F1-SCORE<br/>2 × P × R / P + R<br/>2 × 0.54 × 0.21 / 0.75"]
    
    classDef formulaStyle fill:#9C27B0,stroke:#6A1B9A,stroke-width:3px,color:#fff,font-size:14px
    
    class A,B,C,D,E formulaStyle
```

**Color Legend:**
- 🟢 **Green (TN)**: True Negatives - Correctly identified false alarms
- 🔵 **Blue (TP)**: True Positives - Correctly identified real accidents
- 🟠 **Orange (FP)**: False Positives - Incorrectly flagged as accidents
- 🔴 **Red (FN)**: False Negatives - Missed real accidents

---

## � Confusion Matrix Table

|  | **Predicted FAKE** | **Predicted REAL** | **Total** |
|---|---|---|---|
| **Actual FAKE** | 309 (TN) ✓ | 23 (FP) ✗ | 332 |
| **Actual REAL** | 103 (FN) ✗ | 27 (TP) ✓ | 130 |
| **Total** | 412 | 50 | **462** |

---

## 📊 Summary Table

| Metric | Value | Formula | Meaning |
|--------|-------|---------|---------|
| **Accuracy** | 72.73% | (TP+TN) / Total | Overall correctness |
| **Precision** | 54.00% | TP / (TP+FP) | Accuracy of REAL predictions |
| **Recall** | 20.77% | TP / (TP+FN) | Detection rate of actual accidents |
| **Specificity** | 93.07% | TN / (TN+FP) | False alarm prevention rate |
| **F1-Score** | 30.00% | 2×(P×R) / (P+R) | Harmonic mean of P & R |

Where:
- **TP** (True Positive) = 27
- **TN** (True Negative) = 309
- **FP** (False Positive) = 23
- **FN** (False Negative) = 103

---

## 🎯 Key Insights

✅ **Strengths:**
- High specificity (93.07%) - Excellent false alarm prevention
- Good accuracy (72.73%) - Reliable overall performance
- Low false positive rate (6.93%) - Minimal unnecessary alerts

⚠️ **Weaknesses:**
- Low recall (20.77%) - Misses many real accidents
- Low F1-score (30%) - Imbalance between precision and recall
- High false negative rate (79.23%) - Conservative detection

**Design Philosophy:** The model prioritizes **user trust** (low false alarms) over **maximum sensitivity** (high recall). This is appropriate for a safety-critical app where frequent false alarms would lead users to disable the feature.

---

## 📥 How to Export as Image

**Option 1 - Online (Recommended):**
1. Visit https://mermaid.live/
2. Copy any diagram code from above
3. Paste it into the editor
4. Click "Download PNG" or "Download SVG"

**Option 2 - VS Code:**
1. Install "Markdown Preview Mermaid Support" extension
2. Open this file and click "Open Preview"
3. Right-click the diagram to save as image

**Option 3 - Command Line:**
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i MODEL_METRICS_VISUALIZATION.md -o metrics.png
```

The diagrams are now **simplified and readable** with larger fonts and clearer layouts!

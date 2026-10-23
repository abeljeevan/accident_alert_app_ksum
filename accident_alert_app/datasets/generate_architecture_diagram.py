"""
Generate System Architecture Diagram for Accident Alert App
Creates a professional visual representation of the system components and data flow
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle
import matplotlib.lines as mlines

# Create figure
fig, ax = plt.subplots(1, 1, figsize=(16, 12))
ax.set_xlim(0, 10)
ax.set_ylim(0, 12)
ax.axis('off')

# Color scheme
COLOR_SENSOR = '#E3F2FD'      # Light blue
COLOR_ML = '#FFF3E0'          # Light orange
COLOR_PROCESS = '#F3E5F5'     # Light purple
COLOR_OUTPUT = '#E8F5E9'      # Light green
COLOR_EXTERNAL = '#FFF9C4'    # Light yellow
COLOR_ARROW = '#424242'       # Dark gray

def draw_box(ax, x, y, width, height, text, color, icon=''):
    """Draw a rounded box with text"""
    box = FancyBboxPatch(
        (x, y), width, height,
        boxstyle="round,pad=0.1",
        facecolor=color,
        edgecolor='#424242',
        linewidth=2
    )
    ax.add_patch(box)
    
    # Add icon if provided
    if icon:
        ax.text(x + width/2, y + height*0.65, icon, 
                fontsize=20, ha='center', va='center')
        ax.text(x + width/2, y + height*0.3, text,
                fontsize=9, ha='center', va='center', 
                weight='bold', wrap=True)
    else:
        ax.text(x + width/2, y + height/2, text,
                fontsize=9, ha='center', va='center', 
                weight='bold', wrap=True)

def draw_arrow(ax, x1, y1, x2, y2, label='', style='->'):
    """Draw an arrow between two points"""
    arrow = FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle=style,
        color=COLOR_ARROW,
        linewidth=2,
        mutation_scale=20
    )
    ax.add_patch(arrow)
    
    if label:
        mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
        ax.text(mid_x, mid_y, label,
                fontsize=7, ha='center', va='bottom',
                bbox=dict(boxstyle='round,pad=0.3', 
                         facecolor='white', 
                         edgecolor='none', 
                         alpha=0.8))

# Title
ax.text(5, 11.5, 'Accident Alert App - System Architecture',
        fontsize=18, weight='bold', ha='center')
ax.text(5, 11.1, 'Edge AI-Based Real-Time Accident Detection & Emergency Response',
        fontsize=12, ha='center', style='italic', color='#666')

# ==================== LAYER 1: SENSOR INPUT ====================
ax.text(0.3, 10.3, '1. SENSOR INPUT LAYER', fontsize=11, weight='bold', color='#1976D2')

# Sensors
draw_box(ax, 0.5, 9.2, 1.3, 0.8, 'Accelerometer\n(3-axis)', COLOR_SENSOR, '📱')
draw_box(ax, 2.0, 9.2, 1.3, 0.8, 'Gyroscope\n(3-axis)', COLOR_SENSOR, '🔄')
draw_box(ax, 3.5, 9.2, 1.3, 0.8, 'GPS\n(Location)', COLOR_SENSOR, '📍')

# Sensor Manager
draw_box(ax, 1.5, 8.0, 2.0, 0.8, 'Sensor Manager\n100 Hz Sampling', COLOR_PROCESS)

draw_arrow(ax, 1.15, 9.2, 2.0, 8.8, '100 Hz')
draw_arrow(ax, 2.65, 9.2, 2.5, 8.8, '100 Hz')
draw_arrow(ax, 4.15, 9.2, 3.0, 8.8, '1 Hz')

# ==================== LAYER 2: FEATURE EXTRACTION ====================
ax.text(0.3, 7.5, '2. FEATURE EXTRACTION', fontsize=11, weight='bold', color='#E65100')

# Buffer
draw_box(ax, 0.5, 6.3, 1.5, 0.8, 'Sliding Window\nBuffer (2s)', COLOR_PROCESS, '🗂️')

# Feature Extractor
draw_box(ax, 2.5, 6.3, 2.0, 0.8, 'Feature Extractor\n19 ML Features', COLOR_ML, '⚙️')

draw_arrow(ax, 2.5, 8.0, 1.5, 7.1, '8D raw')
draw_arrow(ax, 2.0, 6.7, 2.5, 6.7, '')

# Feature list (small)
feature_text = (
    'Features:\n'
    '• Impact (X,Y,Z, Magnitude)\n'
    '• Speed (Pre, Post, Change)\n'
    '• Rotation (X,Y,Z, Magnitude)\n'
    '• Temporal (Duration, Secondary)\n'
    '• Context (GPS, Time, Motion)'
)
ax.text(5.2, 6.7, feature_text, fontsize=6, 
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF3E0', 
                 edgecolor='#FF6F00', linewidth=1.5),
        verticalalignment='center', family='monospace')

# ==================== LAYER 3: 3-LAYER DETECTION ====================
ax.text(0.3, 5.8, '3. THREE-LAYER DETECTION SYSTEM', fontsize=11, weight='bold', color='#6A1B9A')

# Layer 1: Shake Filter
draw_box(ax, 0.5, 4.3, 1.8, 0.8, 'Layer 1:\nShake Pattern Filter', COLOR_PROCESS, '🤚')

# Layer 2: Random Forest
draw_box(ax, 2.5, 4.3, 2.2, 0.8, 'Layer 2:\nRandom Forest ML\n(100 Trees, 14.74 MB)', COLOR_ML, '🌲')

# Layer 3: Confidence
draw_box(ax, 5.0, 4.3, 1.8, 0.8, 'Layer 3:\nConfidence Check\n(≥75%)', COLOR_PROCESS, '✓')

draw_arrow(ax, 3.5, 6.3, 1.4, 5.1, '19D features')
draw_arrow(ax, 2.3, 4.7, 2.5, 4.7, 'Pass')
draw_arrow(ax, 4.7, 4.7, 5.0, 4.7, 'REAL/FAKE\n+ confidence')

# ML Model details
ml_details = (
    'Random Forest Classifier:\n'
    '──────────────────────\n'
    '• 100 Decision Trees\n'
    '• 47,918 Nodes\n'
    '• Max Depth: 15\n'
    '• Accuracy: 72.73%\n'
    '• Specificity: 93.07%\n'
    '• Size: 14.74 MB JSON\n'
    '• Inference: <50ms'
)
ax.text(7.5, 4.7, ml_details, fontsize=6,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF3E0',
                 edgecolor='#FF6F00', linewidth=1.5),
        verticalalignment='center', family='monospace')

# ==================== DECISION POINT ====================
# Decision Diamond
decision_x, decision_y = 3.8, 3.2
decision_points = [
    (decision_x, decision_y + 0.4),
    (decision_x + 0.4, decision_y),
    (decision_x, decision_y - 0.4),
    (decision_x - 0.4, decision_y)
]
diamond = mpatches.Polygon(decision_points, 
                          facecolor='#FFEB3B', 
                          edgecolor='#F57F17', 
                          linewidth=2)
ax.add_patch(diamond)
ax.text(decision_x, decision_y, 'REAL\nAccident?',
        fontsize=8, ha='center', va='center', weight='bold')

draw_arrow(ax, 5.9, 4.3, decision_x, decision_y + 0.4, '')

# ==================== LAYER 4: RESPONSE MODULES ====================
ax.text(0.3, 2.5, '4. EMERGENCY RESPONSE', fontsize=11, weight='bold', color='#1B5E20')

# FALSE branch
draw_box(ax, 0.5, 1.0, 1.5, 0.8, 'Log Event\n(False Alarm)', COLOR_OUTPUT, '📝')
draw_arrow(ax, decision_x - 0.3, decision_y - 0.2, 1.5, 1.8, 'FALSE', '<-')

# REAL branch - multiple outputs
draw_box(ax, 3.0, 1.0, 1.5, 0.8, 'Emergency SMS\n+ GPS Location', COLOR_OUTPUT, '📱')
draw_box(ax, 5.0, 1.0, 1.5, 0.8, 'Hospital Finder\n+ Smart Routing', COLOR_OUTPUT, '🏥')
draw_box(ax, 7.0, 1.0, 1.5, 0.8, 'PDF Crash Report\n+ XAI Explanation', COLOR_OUTPUT, '📄')

draw_arrow(ax, decision_x + 0.3, decision_y - 0.2, 3.75, 1.8, 'REAL', '->')
draw_arrow(ax, 3.75, 1.8, 3.75, 1.8, '')  # Fan out
draw_arrow(ax, decision_x + 0.3, decision_y - 0.2, 5.75, 1.8, 'REAL')
draw_arrow(ax, decision_x + 0.3, decision_y - 0.2, 7.75, 1.8, 'REAL')

# ==================== LAYER 5: EXTERNAL SERVICES ====================
ax.text(0.3, 0.5, '5. EXTERNAL SERVICES & APIS', fontsize=11, weight='bold', color='#F57F00')

# External services
draw_box(ax, 3.2, -0.5, 1.2, 0.6, 'OSRM API\n(Routing)', COLOR_EXTERNAL, '🗺️')
draw_box(ax, 4.6, -0.5, 1.2, 0.6, 'Overpass API\n(Hospitals)', COLOR_EXTERNAL, '🏥')
draw_box(ax, 6.0, -0.5, 1.2, 0.6, 'SMS Service', COLOR_EXTERNAL, '💬')
draw_box(ax, 7.4, -0.5, 1.2, 0.6, 'Maps API', COLOR_EXTERNAL, '🌍')

draw_arrow(ax, 5.75, 1.0, 4.0, 0.1, '', '<->')
draw_arrow(ax, 5.75, 1.0, 5.2, 0.1, '', '<->')
draw_arrow(ax, 3.75, 1.0, 6.6, 0.1, '', '<->')
draw_arrow(ax, 7.75, 1.0, 8.0, 0.1, '', '<->')

# ==================== SIDE PANEL: ADDITIONAL FEATURES ====================
side_features = (
    '📊 Additional Features:\n'
    '════════════════════\n'
    '🎤 Voice AI Assistant\n'
    '   • Speech recognition\n'
    '   • Voice commands\n'
    '   • TTS feedback\n\n'
    '🔄 Background Service\n'
    '   • 24/7 monitoring\n'
    '   • Auto-restart\n'
    '   • Battery optimized\n\n'
    '👥 Contact Manager\n'
    '   • Emergency contacts\n'
    '   • Quick actions\n\n'
    '📈 Activity Logs\n'
    '   • SQLite storage\n'
    '   • Detection history\n\n'
    '🌓 Dark Mode Support\n'
    '   • System theme\n'
    '   • OLED optimized\n\n'
    '🔒 Privacy:\n'
    '   • On-device only\n'
    '   • No cloud data\n'
    '   • Offline capable'
)
ax.text(9.7, 7.5, side_features, fontsize=6,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#E8F5E9',
                 edgecolor='#2E7D32', linewidth=2),
        verticalalignment='center', family='monospace')

# ==================== PERFORMANCE METRICS ====================
metrics_text = (
    '⚡ Performance Metrics:\n'
    '═══════════════════\n'
    '• Model Load: 850ms\n'
    '• Feature Extract: 8ms\n'
    '• RF Inference: 47ms\n'
    '• Total Latency: <100ms\n'
    '• Memory: 28 MB\n'
    '• Battery: 2.8%/hour\n'
    '• CPU Usage: 4-6%'
)
ax.text(9.7, 2.8, metrics_text, fontsize=6,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#E1F5FE',
                 edgecolor='#01579B', linewidth=2),
        verticalalignment='center', family='monospace')

# ==================== LEGEND ====================
legend_elements = [
    mpatches.Patch(facecolor=COLOR_SENSOR, edgecolor='#424242', label='Sensor Components'),
    mpatches.Patch(facecolor=COLOR_ML, edgecolor='#424242', label='ML/AI Components'),
    mpatches.Patch(facecolor=COLOR_PROCESS, edgecolor='#424242', label='Processing Logic'),
    mpatches.Patch(facecolor=COLOR_OUTPUT, edgecolor='#424242', label='Output/Response'),
    mpatches.Patch(facecolor=COLOR_EXTERNAL, edgecolor='#424242', label='External APIs'),
]
ax.legend(handles=legend_elements, loc='lower left', fontsize=7, frameon=True)

# Add watermark
ax.text(5, 0.1, 'Edge AI ⚡ On-Device Processing ⚡ Privacy-First Design',
        fontsize=8, ha='center', style='italic', color='#666',
        bbox=dict(boxstyle='round,pad=0.3', facecolor='white', 
                 edgecolor='none', alpha=0.7))

# Save figure
plt.tight_layout()
output_path = 'system_architecture.png'
plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"✅ System architecture diagram saved to: {output_path}")

# Create dark mode version
plt.style.use('dark_background')
fig2, ax2 = plt.subplots(1, 1, figsize=(16, 12))
ax2.set_xlim(0, 10)
ax2.set_ylim(0, 12)
ax2.axis('off')

# Dark color scheme
DARK_SENSOR = '#1E3A5F'
DARK_ML = '#5F3A1E'
DARK_PROCESS = '#3A1E5F'
DARK_OUTPUT = '#1E5F3A'
DARK_EXTERNAL = '#5F5F1E'

def draw_box_dark(ax, x, y, width, height, text, color, icon=''):
    box = FancyBboxPatch(
        (x, y), width, height,
        boxstyle="round,pad=0.1",
        facecolor=color,
        edgecolor='#00BCD4',
        linewidth=2
    )
    ax.add_patch(box)
    
    if icon:
        ax.text(x + width/2, y + height*0.65, icon, 
                fontsize=20, ha='center', va='center')
        ax.text(x + width/2, y + height*0.3, text,
                fontsize=9, ha='center', va='center', 
                weight='bold', wrap=True, color='white')
    else:
        ax.text(x + width/2, y + height/2, text,
                fontsize=9, ha='center', va='center', 
                weight='bold', wrap=True, color='white')

# Repeat structure with dark colors
ax2.text(5, 11.5, 'Accident Alert App - System Architecture',
        fontsize=18, weight='bold', ha='center', color='#00BCD4')
ax2.text(5, 11.1, 'Edge AI-Based Real-Time Accident Detection & Emergency Response',
        fontsize=12, ha='center', style='italic', color='#AAA')

# Layer headers
ax2.text(0.3, 10.3, '1. SENSOR INPUT LAYER', fontsize=11, weight='bold', color='#42A5F5')
ax2.text(0.3, 7.5, '2. FEATURE EXTRACTION', fontsize=11, weight='bold', color='#FF9800')
ax2.text(0.3, 5.8, '3. THREE-LAYER DETECTION SYSTEM', fontsize=11, weight='bold', color='#AB47BC')
ax2.text(0.3, 2.5, '4. EMERGENCY RESPONSE', fontsize=11, weight='bold', color='#66BB6A')
ax2.text(0.3, 0.5, '5. EXTERNAL SERVICES & APIS', fontsize=11, weight='bold', color='#FFA726')

# Redraw all boxes with dark theme
draw_box_dark(ax2, 0.5, 9.2, 1.3, 0.8, 'Accelerometer\n(3-axis)', DARK_SENSOR, '📱')
draw_box_dark(ax2, 2.0, 9.2, 1.3, 0.8, 'Gyroscope\n(3-axis)', DARK_SENSOR, '🔄')
draw_box_dark(ax2, 3.5, 9.2, 1.3, 0.8, 'GPS\n(Location)', DARK_SENSOR, '📍')
draw_box_dark(ax2, 1.5, 8.0, 2.0, 0.8, 'Sensor Manager\n100 Hz Sampling', DARK_PROCESS)

draw_box_dark(ax2, 0.5, 6.3, 1.5, 0.8, 'Sliding Window\nBuffer (2s)', DARK_PROCESS, '🗂️')
draw_box_dark(ax2, 2.5, 6.3, 2.0, 0.8, 'Feature Extractor\n19 ML Features', DARK_ML, '⚙️')

draw_box_dark(ax2, 0.5, 4.3, 1.8, 0.8, 'Layer 1:\nShake Pattern Filter', DARK_PROCESS, '🤚')
draw_box_dark(ax2, 2.5, 4.3, 2.2, 0.8, 'Layer 2:\nRandom Forest ML\n(100 Trees, 14.74 MB)', DARK_ML, '🌲')
draw_box_dark(ax2, 5.0, 4.3, 1.8, 0.8, 'Layer 3:\nConfidence Check\n(≥75%)', DARK_PROCESS, '✓')

draw_box_dark(ax2, 0.5, 1.0, 1.5, 0.8, 'Log Event\n(False Alarm)', DARK_OUTPUT, '📝')
draw_box_dark(ax2, 3.0, 1.0, 1.5, 0.8, 'Emergency SMS\n+ GPS Location', DARK_OUTPUT, '📱')
draw_box_dark(ax2, 5.0, 1.0, 1.5, 0.8, 'Hospital Finder\n+ Smart Routing', DARK_OUTPUT, '🏥')
draw_box_dark(ax2, 7.0, 1.0, 1.5, 0.8, 'PDF Crash Report\n+ XAI Explanation', DARK_OUTPUT, '📄')

draw_box_dark(ax2, 3.2, -0.5, 1.2, 0.6, 'OSRM API\n(Routing)', DARK_EXTERNAL, '🗺️')
draw_box_dark(ax2, 4.6, -0.5, 1.2, 0.6, 'Overpass API\n(Hospitals)', DARK_EXTERNAL, '🏥')
draw_box_dark(ax2, 6.0, -0.5, 1.2, 0.6, 'SMS Service', DARK_EXTERNAL, '💬')
draw_box_dark(ax2, 7.4, -0.5, 1.2, 0.6, 'Maps API', DARK_EXTERNAL, '🌍')

output_path_dark = 'system_architecture_dark.png'
plt.savefig(output_path_dark, dpi=300, bbox_inches='tight', facecolor='#1a1a1a')
print(f"✅ Dark mode architecture diagram saved to: {output_path_dark}")

print("\n🎨 Architecture diagrams generated successfully!")
print("   1. Light theme: system_architecture.png")
print("   2. Dark theme: system_architecture_dark.png")

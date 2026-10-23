#!/usr/bin/env python3
"""
Convert HARDWARE_SOFTWARE_REQUIREMENTS.md to professional Word document.
Uses python-docx library to create formatted .docx file.
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import re

def add_heading_with_style(doc, text, level):
    """Add heading with proper styling."""
    heading = doc.add_heading(text, level=level)
    heading.paragraph_format.space_before = Pt(12)
    heading.paragraph_format.space_after = Pt(8)
    
    # Apply color to heading
    for run in heading.runs:
        if level == 1:
            run.font.size = Pt(24)
            run.font.bold = True
            run.font.color.rgb = RGBColor(31, 78, 121)
        elif level == 2:
            run.font.size = Pt(16)
            run.font.bold = True
            run.font.color.rgb = RGBColor(31, 78, 121)
        elif level == 3:
            run.font.size = Pt(13)
            run.font.bold = True
            run.font.color.rgb = RGBColor(31, 78, 121)
    
    return heading

def set_cell_border(cell, **kwargs):
    """Set cell border properties."""
    tcPr = cell._element.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    
    for edge in ('top', 'left', 'bottom', 'right'):
        edge_data = kwargs.get(edge)
        if edge_data:
            edge_el = OxmlElement(f'w:{edge}')
            edge_el.set(qn('w:val'), 'single')
            edge_el.set(qn('w:sz'), '12')
            edge_el.set(qn('w:space'), '0')
            edge_el.set(qn('w:color'), '000000')
            tcBorders.append(edge_el)
    
    tcPr.append(tcBorders)

def create_requirements_document():
    """Create the main requirements document."""
    doc = Document()
    
    # Set document margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1)
        section.bottom_margin = Inches(1)
        section.left_margin = Inches(1.25)
        section.right_margin = Inches(1.25)
    
    # Title
    title = doc.add_paragraph()
    title_run = title.add_run("HARDWARE AND SOFTWARE REQUIREMENTS")
    title_run.font.size = Pt(24)
    title_run.font.bold = True
    title_run.font.color.rgb = RGBColor(0, 0, 0)
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_after = Pt(6)
    
    # Subtitle
    subtitle = doc.add_paragraph()
    subtitle_run = subtitle.add_run("Accident Alert App: Edge AI-Based Real-Time Vehicle Accident Detection System")
    subtitle_run.font.size = Pt(12)
    subtitle_run.font.italic = True
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.paragraph_format.space_after = Pt(24)
    
    # Add horizontal line
    doc.add_paragraph("_" * 80).paragraph_format.space_after = Pt(12)
    
    # Section 1: Development Hardware Requirements
    add_heading_with_style(doc, "1. DEVELOPMENT HARDWARE REQUIREMENTS", 1)
    
    add_heading_with_style(doc, "1.1 Developer's Workstation (Minimum)", 2)
    
    specs_min = [
        ("Processor:", "Multi-core processor: Intel Core i5 (8th Gen) or AMD Ryzen 5 2600, 3.0+ GHz clock speed, 4+ cores, TDP: 65W+"),
        ("Memory:", "RAM: 8 GB minimum, DDR4 2400+ MHz preferred, 12-16 GB recommended"),
        ("Storage:", "SSD: 256 GB NVMe or SATA SSD (minimum), 512 GB recommended, 400+ MB/s write speed, 50 GB free space"),
        ("Display:", "Resolution: 1920×1080 (Full HD), 2560×1440 (QHD) or higher recommended, Dual monitors highly recommended"),
        ("Additional Hardware:", "Keyboard and Mouse/Trackpad, USB 3.0 ports: 2+, Gigabit Ethernet or 802.11ac Wi-Fi"),
    ]
    
    for label, description in specs_min:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    doc.add_paragraph()  # Spacing
    
    add_heading_with_style(doc, "1.2 Developer's Workstation (Recommended)", 2)
    
    specs_rec = [
        ("Processor:", "Intel Core i7 (10th Gen+) or AMD Ryzen 7 3700X, 3.6+ GHz, 8+ cores"),
        ("Memory:", "RAM: 16-32 GB DDR4, 3200+ MHz speed"),
        ("Storage:", "NVMe SSD: 1 TB, Primary C: drive 256 GB, Secondary 500+ GB, Backup 1 TB external SSD"),
        ("GPU:", "Discrete GPU (NVIDIA/AMD) optional, Accelerates Android emulator and PDF rendering"),
        ("Display:", "Dual 2560×1440 displays or single 4K (3840×2160)"),
        ("Network:", "Gigabit Ethernet, 802.11ac Wi-Fi 6 (Wi-Fi 6E)"),
    ]
    
    for label, description in specs_rec:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    # Section 2: Development Software Requirements
    doc.add_paragraph()
    add_heading_with_style(doc, "2. DEVELOPMENT SOFTWARE REQUIREMENTS", 1)
    
    add_heading_with_style(doc, "2.1 Operating System (Development Machine)", 2)
    
    os_reqs = [
        ("Windows Development:", "Windows 10 Pro (Build 19041+) or Windows 11 Pro, 64-bit, Admin privileges, Virtualization enabled in BIOS"),
        ("macOS Development:", "macOS 11 (Big Sur) or later (12+ recommended), 64-bit, Xcode 13+"),
        ("Linux Development:", "Ubuntu 20.04 LTS or later (22.04 recommended), 64-bit, Kernel 5.0+"),
    ]
    
    for label, description in os_reqs:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    doc.add_paragraph()
    
    add_heading_with_style(doc, "2.2 Core Development Tools", 2)
    
    tools = [
        ("Flutter SDK:", "Version 3.10+, Dart 3.8+ bundled, Stable channel"),
        ("IDE - Visual Studio Code:", "Version 1.75+, Extensions: Flutter, Dart, Awesome Flutter Snippets, Pubspec Assist, Code Runner"),
        ("Alternative IDEs:", "Android Studio (4.2+), IntelliJ IDEA (2022.1+)"),
    ]
    
    for label, description in tools:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    # Section 3: End-User Hardware Requirements
    doc.add_paragraph()
    add_heading_with_style(doc, "3. END-USER HARDWARE REQUIREMENTS", 1)
    
    add_heading_with_style(doc, "3.1 Minimum Hardware Requirements (Basic Functionality)", 2)
    
    add_heading_with_style(doc, "Android Devices:", 3)
    
    android_min = [
        "OS Version: Android 5.0 (API 21) or higher",
        "Processor: ARM v7 (32-bit) or ARM64 (64-bit), 1.0+ GHz",
        "RAM: 2 GB minimum",
        "Storage: 100 MB free space (app ~50 MB)",
        "Sensors: Accelerometer (3-axis), Gyroscope (3-axis), Barometer (optional)",
        "GPS/GNSS: Required (standard GPS, A-GPS capable)",
        "Network: 2G/3G connectivity for SMS",
        "Battery: 2500 mAh minimum",
    ]
    
    for item in android_min:
        p = doc.add_paragraph(item, style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.75)
        p.paragraph_format.space_after = Pt(4)
    
    doc.add_paragraph()
    add_heading_with_style(doc, "iOS Devices:", 3)
    
    ios_min = [
        "OS Version: iOS 12.0 or higher (iOS 14+ recommended)",
        "Processor: Apple A9 or later (iPhone 6s or newer)",
        "RAM: 2 GB minimum (3+ GB recommended)",
        "Storage: 100 MB free space",
        "Sensors: Accelerometer, Gyroscope (all modern iPhones)",
        "GPS/GNSS: Required",
        "Cellular: Required for SMS alerts",
        "Battery: 2000 mAh minimum",
    ]
    
    for item in ios_min:
        p = doc.add_paragraph(item, style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.75)
        p.paragraph_format.space_after = Pt(4)
    
    doc.add_paragraph()
    
    add_heading_with_style(doc, "3.2 Recommended Hardware Requirements (Optimal Experience)", 2)
    
    add_heading_with_style(doc, "Android Devices:", 3)
    
    android_rec = [
        "OS Version: Android 10 or higher (Android 12+ preferred)",
        "Processor: Snapdragon 765 or higher, 2.0+ GHz",
        "RAM: 4 GB or more",
        "Storage: 200+ MB free space",
        "Sensors: Accelerometer, Gyroscope, Magnetometer, Proximity sensor",
        "Display: 1080p or higher resolution",
        "GPS/GNSS: Multi-system (GPS + GLONASS + Galileo + BeiDou)",
        "Network: 4G LTE or 5G capable",
        "Battery: 4000 mAh or larger",
        "Device Examples: Pixel 5+, Samsung Galaxy S20+, OnePlus 8+",
    ]
    
    for item in android_rec:
        p = doc.add_paragraph(item, style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.75)
        p.paragraph_format.space_after = Pt(4)
    
    doc.add_paragraph()
    add_heading_with_style(doc, "iOS Devices:", 3)
    
    ios_rec = [
        "OS Version: iOS 15 or higher",
        "Processor: Apple A12 Bionic or newer (iPhone XS or newer)",
        "RAM: 4 GB or more",
        "Storage: 200+ MB free space",
        "Display: Retina display or higher",
        "GPS/GNSS: Dual-frequency GPS",
        "Network: 4G LTE or 5G capable",
        "Battery: 3500 mAh or larger",
        "Device Examples: iPhone 12 Pro+, iPhone 13+, iPhone 14+",
    ]
    
    for item in ios_rec:
        p = doc.add_paragraph(item, style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.75)
        p.paragraph_format.space_after = Pt(4)
    
    # Section 4: End-User Software Requirements
    doc.add_paragraph()
    add_heading_with_style(doc, "4. END-USER SOFTWARE REQUIREMENTS", 1)
    
    add_heading_with_style(doc, "4.1 Operating System Support", 2)
    
    os_support = [
        ("Android:", "Minimum: Android 5.0 (API 21), Target: Android 13 (API 33), Bitness: 32-bit & 64-bit"),
        ("iOS:", "Minimum: iOS 12.0, Target: iOS 14.0+, Architecture: arm64 (64-bit)"),
        ("Web:", "Chrome/Chromium 90+, Firefox 88+, Safari 14+, Edge 90+, Screen: 320px minimum (1024px+ recommended)"),
    ]
    
    for label, description in os_support:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    doc.add_paragraph()
    
    add_heading_with_style(doc, "4.2 Network and Connectivity", 2)
    
    network = [
        ("Mobile Network:", "2G/3G minimum for SMS, 4G LTE recommended, 5G optional, Offline capability for core detection"),
        ("Wi-Fi:", "Optional for APIs, Bandwidth: 1+ Mbps for Overpass/OSRM queries"),
        ("GPS Connectivity:", "GPS/GNSS receiver active, Warm start: 2-10 seconds, Cold start: 30-60 seconds"),
    ]
    
    for label, description in network:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    # Section 5: Third-Party Services
    doc.add_paragraph()
    add_heading_with_style(doc, "5. THIRD-PARTY SERVICES AND APIS", 1)
    
    add_heading_with_style(doc, "5.1 External API Requirements", 2)
    
    apis = [
        ("Overpass API:", "Hospital discovery, OpenStreetMap, Free, 99%+ uptime, 10 req/min rate limit, Offline fallback included"),
        ("OSRM Routing:", "Route optimization, Open-source, Free, 99%+ uptime, No rate limit specified, Fallback: direct distance"),
        ("SMS Gateway:", "Native Android/iOS API, Cost per SMS with telecom provider, No additional setup required"),
    ]
    
    for label, description in apis:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    doc.add_paragraph()
    
    add_heading_with_style(doc, "5.2 Optional Cloud Services", 2)
    
    cloud = [
        "Firebase: Authentication, Crashlytics, Analytics (50k events/day free tier)",
        "Google Maps API: Optional future enhancement, Cost: Pay-per-use, Alternative: OSRM for free routing",
    ]
    
    for item in cloud:
        p = doc.add_paragraph(item, style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.75)
        p.paragraph_format.space_after = Pt(4)
    
    # Section 6: Performance Requirements
    doc.add_paragraph()
    add_heading_with_style(doc, "6. PERFORMANCE REQUIREMENTS", 1)
    
    add_heading_with_style(doc, "6.1 Application Performance Targets", 2)
    
    perf = [
        ("Memory:", "Initial Launch: <50 MB, Peak: <80 MB, Target: <200 MB"),
        ("CPU Usage:", "Idle: <2%, Detection: <40% spike, ML Inference: <20%"),
        ("Battery:", "24-hour monitoring: <15% drain, Emergency 5-min: <5%"),
        ("Storage:", "App: ~50 MB, Logs/Data: <100 MB, ML Model: 14.74 MB"),
    ]
    
    for label, description in perf:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    doc.add_paragraph()
    
    add_heading_with_style(doc, "6.2 Network Performance Targets", 2)
    
    net_perf = [
        ("API Response Time:", "Overpass API: <2s, OSRM Routing: <1s, SMS Delivery: <10s"),
        ("Data Usage:", "Per Alert: ~50 KB, Per Hour (idle): <1 MB, Per Day: <50 MB"),
    ]
    
    for label, description in net_perf:
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.left_indent = Inches(0.5)
        run = p.add_run(label + " ")
        run.bold = True
        p.add_run(description)
        p.paragraph_format.space_after = Pt(6)
    
    # Add footer
    doc.add_paragraph()
    doc.add_paragraph("_" * 80).paragraph_format.space_after = Pt(12)
    
    footer_info = [
        "Requirements Compiled By: Development Team",
        "Last Updated: March 25, 2026",
        "Version: 1.0 | Status: Production-Ready",
    ]
    
    for line in footer_info:
        p = doc.add_paragraph(line)
        p.paragraph_format.space_after = Pt(4)
        for run in p.runs:
            run.font.size = Pt(10)
            run.font.italic = True
    
    # Save document
    output_path = r'c:\accident_alert_app_ermap\HARDWARE_SOFTWARE_REQUIREMENTS.docx'
    doc.save(output_path)
    print(f"✓ Document created successfully: {output_path}")
    print(f"✓ File size: {__import__('os').path.getsize(output_path) / 1024:.1f} KB")

if __name__ == "__main__":
    create_requirements_document()

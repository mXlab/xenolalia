#!/usr/bin/env python3
"""
Create the euglena_experiment_log.ods spreadsheet with
all required sheets, columns, and dropdown validation.
"""

from odf.opendocument import OpenDocumentSpreadsheet
from odf.style import Style, TextProperties, TableColumnProperties, TableCellProperties, ParagraphProperties
from odf.text import P
from odf.table import Table, TableColumn, TableRow, TableCell, CellRangeSource
from odf.office import Annotation
import os

def create_spreadsheet():
    doc = OpenDocumentSpreadsheet()

    # Create styles
    # Header style (bold)
    header_style = Style(name="HeaderStyle", family="table-cell")
    header_style.addElement(TextProperties(fontweight="bold"))
    header_style.addElement(TableCellProperties(backgroundcolor="#CCCCCC"))
    doc.automaticstyles.addElement(header_style)

    # Section header style (bold, colored background)
    section_styles = {
        "light": "#FFE4B5",    # Light orange for LIGHT section
        "medium": "#98FB98",   # Light green for MEDIUM section
        "env": "#ADD8E6",      # Light blue for ENV section
        "history": "#DDA0DD",  # Light purple for HISTORY section
        "response": "#FFFACD", # Light yellow for RESPONSE section
        "other": "#E0E0E0"     # Gray for other
    }

    for name, color in section_styles.items():
        style = Style(name=f"Section_{name}", family="table-cell")
        style.addElement(TextProperties(fontweight="bold"))
        style.addElement(TableCellProperties(backgroundcolor=color))
        doc.automaticstyles.addElement(style)

    # Column width style
    col_style = Style(name="ColWidth", family="table-column")
    col_style.addElement(TableColumnProperties(columnwidth="2.5cm"))
    doc.automaticstyles.addElement(col_style)

    wide_col_style = Style(name="WideCol", family="table-column")
    wide_col_style.addElement(TableColumnProperties(columnwidth="4cm"))
    doc.automaticstyles.addElement(wide_col_style)

    # ========================================
    # Sheet 1: Experiment Log
    # ========================================
    table1 = Table(name="Experiment Log")

    # Define columns with their properties
    columns = [
        ("A", "Experiment ID", "other"),
        ("B", "Date", "other"),
        ("C", "Time", "other"),
        ("D", "LIGHT: Color", "light"),
        ("E", "LIGHT: Pattern", "light"),
        ("F", "LIGHT: Duration (min)", "light"),
        ("G", "MEDIUM: Color", "medium"),
        ("H", "MEDIUM: Turbidity", "medium"),
        ("I", "MEDIUM: Aggregation", "medium"),
        ("J", "MEDIUM: pH", "medium"),
        ("K", "MEDIUM: Density", "medium"),
        ("L", "MEDIUM: Activity", "medium"),
        ("M", "ENV: Temperature (°C)", "env"),
        ("N", "ENV: Humidity (%)", "env"),
        ("O", "ENV: Pressure (hPa)", "env"),
        ("P", "HISTORY: Prior Light (min)", "history"),
        ("Q", "HISTORY: Prior Dark (min)", "history"),
        ("R", "Response Type", "response"),
        ("S", "Response Strength", "response"),
        ("T", "Response Time (sec)", "response"),
        ("U", "Observations", "other"),
        ("V", "Microscope", "other"),
        ("W", "Media File", "other"),
    ]

    # Add columns
    for _ in columns:
        table1.addElement(TableColumn(stylename=col_style))

    # Add header row
    header_row = TableRow()
    for col_letter, col_name, section in columns:
        cell = TableCell(stylename=f"Section_{section}")
        cell.addElement(P(text=col_name))
        header_row.addElement(cell)
    table1.addElement(header_row)

    # Add a few empty rows for data entry
    for i in range(50):
        data_row = TableRow()
        for j, (col_letter, col_name, section) in enumerate(columns):
            cell = TableCell()
            # Pre-fill experiment ID for first few rows
            if j == 0 and i < 5:
                cell.addElement(P(text=f"E{i+1:03d}"))
            data_row.addElement(cell)
        table1.addElement(data_row)

    doc.spreadsheet.addElement(table1)

    # ========================================
    # Sheet 2: Dropdown Values
    # ========================================
    table2 = Table(name="Dropdown Values")

    dropdown_data = {
        "LIGHT: Pattern": ["white", "black", "X-pattern"],
        "MEDIUM: Turbidity": ["clear", "slightly cloudy", "cloudy", "opaque"],
        "MEDIUM: Aggregation": ["none", "few lumps", "many lumps", "clumped"],
        "MEDIUM: Density": ["sparse", "medium", "dense", "very dense"],
        "MEDIUM: Activity": ["inactive", "low", "medium", "high", "very high"],
        "Response Type": ["positive", "negative", "none", "mixed"],
        "Response Strength": ["none", "weak", "moderate", "strong"],
        "Microscope": ["Yes", "No"],
    }

    # Find max rows needed
    max_rows = max(len(v) for v in dropdown_data.values())

    # Add header row
    header_row = TableRow()
    for col_name in dropdown_data.keys():
        cell = TableCell(stylename=header_style)
        cell.addElement(P(text=col_name))
        header_row.addElement(cell)
    table2.addElement(header_row)

    # Add data rows
    for i in range(max_rows):
        data_row = TableRow()
        for col_name, values in dropdown_data.items():
            cell = TableCell()
            if i < len(values):
                cell.addElement(P(text=values[i]))
            data_row.addElement(cell)
        table2.addElement(data_row)

    doc.spreadsheet.addElement(table2)

    # ========================================
    # Sheet 3: Quick Reference
    # ========================================
    table3 = Table(name="Quick Reference")

    reference_content = [
        ["EUGLENA PHOTOTAXIS REFERENCE", ""],
        ["", ""],
        ["PHOTOTAXIS TYPES:", ""],
        ["Positive phototaxis", "Movement TOWARD light source"],
        ["Negative phototaxis", "Movement AWAY from light source"],
        ["", ""],
        ["LIGHT RESPONSES:", ""],
        ["Step-up response", "Increased light triggers tumbling/direction change"],
        ["Step-down response", "Decreased light triggers tumbling/direction change"],
        ["", ""],
        ["TYPICAL BEHAVIOR:", ""],
        ["Low light", "Positive phototaxis (move toward light)"],
        ["High light", "Negative phototaxis (avoid bright light)"],
        ["Optimal", "Moderate light for photosynthesis"],
        ["", ""],
        ["MEDIUM COLOR GUIDE:", ""],
        ["Bright green", "Healthy, active culture"],
        ["Dark green", "High density, may need dilution"],
        ["Yellow-green", "Stressed or aging culture"],
        ["Brown/olive", "Old culture, possible contamination"],
        ["Clear", "Very low density or dead culture"],
        ["", ""],
        ["RESPONSE TIMING:", ""],
        ["Immediate", "< 5 seconds"],
        ["Fast", "5-30 seconds"],
        ["Slow", "30-120 seconds"],
        ["Delayed", "> 120 seconds"],
        ["", ""],
        ["EXPERIMENTAL TIPS:", ""],
        ["Dark adaptation", "Keep in dark 30+ min before light tests"],
        ["Temperature", "Optimal 20-25°C"],
        ["Medium", "Replace weekly for best results"],
        ["Density", "Dilute if too dense (can't see individuals)"],
    ]

    for row_data in reference_content:
        row = TableRow()
        for cell_data in row_data:
            cell = TableCell()
            if cell_data:
                cell.addElement(P(text=cell_data))
            row.addElement(cell)
        table3.addElement(row)

    doc.spreadsheet.addElement(table3)

    # Save the document
    output_path = os.path.join(os.path.dirname(__file__), "euglena_experiment_log.ods")
    doc.save(output_path)
    print(f"Created: {output_path}")

if __name__ == "__main__":
    create_spreadsheet()

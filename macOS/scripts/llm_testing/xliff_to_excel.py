import sys
import xml.etree.ElementTree as ET
import pandas as pd
import random
import os

def parse_xliff_to_excel(input_file, output_excel):
    # Parse the XLIFF file
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Define namespace
    ns = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    
    # Prepare data for Excel
    data = []
    mapping = {}  # To store which value went to which column
    
    # Find all trans-units
    for trans_unit in root.findall('.//xliff:trans-unit', ns):
        trans_id = trans_unit.get('id')
        source = trans_unit.find('xliff:source', ns)
        target = trans_unit.find('xliff:target', ns)
        target_classic = trans_unit.find('xliff:target-classic', ns)
        
        if source is not None and target is not None and target_classic is not None:
            source_text = source.text or ""
            target_text = target.text or ""
            target_classic_text = target_classic.text or ""
            
            # Randomly decide which translation goes to which column
            if random.choice([True, False]):
                first_translation = target_text
                second_translation = target_classic_text
                mapping[trans_id] = {
                    "First translation": "target",
                    "Second translation": "target-classic"
                }
            else:
                first_translation = target_classic_text
                second_translation = target_text
                mapping[trans_id] = {
                    "First translation": "target-classic",
                    "Second translation": "target"
                }
            
            # Add to data
            data.append({
                "Id": trans_id,
                "Original": source_text,
                "First translation": first_translation,
                "Second translation": second_translation
            })
    
    # Create DataFrame
    df = pd.DataFrame(data)
    
    # Write to Excel
    df.to_excel(output_excel, index=False)
    
    return mapping

def main():
    if len(sys.argv) != 3:
        print("Usage: python script.py input_xliff.xliff output_excel.xlsx")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_excel = sys.argv[2]
    
    try:
        # Ensure the input file exists
        if not os.path.exists(input_file):
            print(f"Error: Input file '{input_file}' does not exist.")
            sys.exit(1)
        
        # Parse XLIFF and create Excel
        mapping = parse_xliff_to_excel(input_file, output_excel)
        
        # Print mapping information
        print(f"Successfully created Excel file: {output_excel}")
        print("\nMapping of translations to columns:")
        print("=" * 50)
        
        for trans_id, columns in mapping.items():
            print(f"ID: {trans_id}")
            print(f"  First translation: {columns['First translation']}")
            print(f"  Second translation: {columns['Second translation']}")
            print("-" * 50)
        
    except Exception as e:
        print(f"Error processing file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

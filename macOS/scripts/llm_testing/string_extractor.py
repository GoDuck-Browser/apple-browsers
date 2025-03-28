#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import re

def extract_strings_to_text_file(input_file, output_file, max_strings=200):
    # Register the namespace
    ns = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    
    # Parse the XML file
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Find all trans-unit elements
    trans_units = root.findall('.//xliff:trans-unit', ns)
    
    # Limit to max_strings
    trans_units = trans_units[:max_strings]

    # Open output file
    with open(output_file, 'w', encoding='utf-8') as f:
        for i, unit in enumerate(trans_units):
            source = unit.find('xliff:source', ns)
            target = unit.find('xliff:target', ns)
            
            if source is not None and target is not None:
                source_text = source.text or ""
                target_text = target.text or ""
                
                # Handle newlines and escape quotes in the strings
                source_text = source_text.replace('\n', '\\n').replace('"', '\\"')
                target_text = target_text.replace('\n', '\\n').replace('"', '\\"')
                
                # Write in the requested format
                f.write(f'"{source_text}"="{target_text}"')
                
                # Add semicolon after each pair except the last one
                if i < len(trans_units) - 1:
                    f.write(';')

def main():
    input_file = './assets/loc/it_for_compression.xliff'  # Replace with your input file path
    output_file = './assets/loc/strings_it.txt'  # Output file name
    max_strings = 100  # Maximum number of strings to extract
    
    try:
        extract_strings_to_text_file(input_file, output_file, max_strings)
        print(f"Successfully extracted strings to {output_file}")
        
    except Exception as e:
        print(f"Error processing the XLIFF file: {e}")

if __name__ == "__main__":
    main()


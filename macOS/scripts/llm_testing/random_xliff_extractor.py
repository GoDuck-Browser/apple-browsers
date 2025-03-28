#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import random
import copy
import os

def extract_random_trans_units_to_xliff(input_file, output_file, num_units=20):
    # Register the namespace
    ns = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    ET.register_namespace('', 'urn:oasis:names:tc:xliff:document:1.2')
    ET.register_namespace('xml', 'http://www.w3.org/XML/1998/namespace')
    
    # Parse the XML file
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Find all trans-unit elements
    trans_units = root.findall('.//xliff:trans-unit', ns)
    
    # Select random trans-units
    if len(trans_units) <= num_units:
        selected_units = trans_units
    else:
        selected_units = random.sample(trans_units, num_units)
    
    # Create a new XLIFF structure
    new_root = copy.deepcopy(root)
    
    # Remove all existing trans-units from the new structure
    for file_elem in new_root.findall('.//xliff:file', ns):
        body = file_elem.find('.//xliff:body', ns)
        if body is not None:
            for unit in body.findall('.//xliff:trans-unit', ns):
                body.remove(unit)
    
    # Add the selected trans-units to the appropriate file/body elements
    for unit in selected_units:
        # Find the original file and body that contained this unit
        for file_elem in root.findall('.//xliff:file', ns):
            body = file_elem.find('.//xliff:body', ns)
            if body is not None and unit in body:
                # Find the corresponding file and body in the new structure
                original_attr = file_elem.get('original')
                new_file = None
                for nf in new_root.findall('.//xliff:file', ns):
                    if nf.get('original') == original_attr:
                        new_file = nf
                        break
                
                if new_file is not None:
                    new_body = new_file.find('.//xliff:body', ns)
                    if new_body is not None:
                        # Add a copy of the selected unit to the new body
                        new_body.append(copy.deepcopy(unit))
                break
    
    # Write the new XLIFF to a file
    tree = ET.ElementTree(new_root)
    tree.write(output_file, encoding='utf-8', xml_declaration=True)

def main():
    input_file = './assets/loc/export-test.xliff'  # Replace with your input file path
    output_file = './assets/loc/random_20_strings.xliff'  # Output file name
    
    try:
        extract_random_trans_units_to_xliff(input_file, output_file)
        print(f"Successfully created {output_file} with 20 random trans-units")
        
    except Exception as e:
        print(f"Error processing the XLIFF file: {e}")

if __name__ == "__main__":
    main()

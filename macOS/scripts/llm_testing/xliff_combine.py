import os
import glob
import xml.etree.ElementTree as ET
from collections import defaultdict

# Register the namespaces
ET.register_namespace('', 'urn:oasis:names:tc:xliff:document:1.2')
ET.register_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')

def combine_xliff_files(input_dir, output_file):
    """Combine multiple XLIFF files into a single file."""
    # Get all XLIFF files in the input directory
    xliff_files = glob.glob(os.path.join(input_dir, '*.xliff'))
    
    if not xliff_files:
        print("No XLIFF files found in the specified directory.")
        return
    
    # Define namespace for XPath queries
    ns = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    
    # Parse the first file to use as a template
    first_tree = ET.parse(xliff_files[0])
    first_root = first_tree.getroot()
    
    # Create a new root element with the same attributes
    new_root = ET.Element(first_root.tag, first_root.attrib)
    
    # Dictionary to store file elements by their 'original' attribute
    file_dict = {}
    
    # Track trans-unit counts
    total_trans_units = 0
    file_trans_units = defaultdict(int)
    
    # Process each XLIFF file
    for xliff_file in xliff_files:
        file_name = os.path.basename(xliff_file)
        print(f"Processing {file_name}...")
        
        # Parse the XLIFF file
        tree = ET.parse(xliff_file)
        root = tree.getroot()
        
        # Process each file element
        for file_elem in root.findall('.//xliff:file', ns):
            original = file_elem.get('original')
            
            # Count trans-units in this file element
            trans_units = file_elem.findall('.//xliff:trans-unit', ns)
            count = len(trans_units)
            
            if count > 0:
                file_trans_units[original] += count
                total_trans_units += count
                
                print(f"  File '{original}' has {count} trans-unit elements")
                
                # If we haven't seen this file element before, add it to our dictionary
                if original not in file_dict:
                    # Make a deep copy of the file element
                    file_dict[original] = ET.fromstring(ET.tostring(file_elem, encoding='utf-8').decode('utf-8'))
                else:
                    # If we have seen it, merge the trans-units from the body
                    existing_file = file_dict[original]
                    existing_body = existing_file.find('.//xliff:body', ns)
                    
                    for trans_unit in trans_units:
                        # Check if this trans-unit already exists (by id)
                        trans_id = trans_unit.get('id')
                        existing_trans = existing_file.findall(f'.//xliff:trans-unit[@id="{trans_id}"]', ns)
                        
                        if not existing_trans:
                            # Make a deep copy of the trans-unit
                            trans_unit_copy = ET.fromstring(ET.tostring(trans_unit, encoding='utf-8').decode('utf-8'))
                            existing_body.append(trans_unit_copy)
    
    # Add all file elements to the new root in sorted order
    for original in sorted(file_dict.keys()):
        new_root.append(file_dict[original])
    
    # Create a new tree with the new root
    new_tree = ET.ElementTree(new_root)
    
    # Write the combined XLIFF to the output file
    new_tree.write(output_file, encoding='utf-8', xml_declaration=True)
    
    print(f"\nCombined XLIFF file created: {output_file}")
    
    # Print summary
    for original in sorted(file_trans_units.keys()):
        print(f"File '{original}' has {file_trans_units[original]} trans-unit elements")
    
    print(f"Total trans-unit elements: {total_trans_units}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Combine multiple XLIFF files into a single file.')
    parser.add_argument('input_dir', help='Directory containing XLIFF files')
    parser.add_argument('output_file', help='Output XLIFF file')
    
    args = parser.parse_args()
    
    combine_xliff_files(args.input_dir, args.output_file)


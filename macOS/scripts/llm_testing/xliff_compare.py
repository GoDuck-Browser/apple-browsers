import sys
import xml.etree.ElementTree as ET
import copy
from xml.dom import minidom

def register_namespaces():
    # Register the namespaces used in XLIFF files
    ET.register_namespace('', "urn:oasis:names:tc:xliff:document:1.2")
    ET.register_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")

def parse_xliff(file_path):
    # Parse the XLIFF file
    tree = ET.parse(file_path)
    return tree

def add_target_classic(first_tree, second_tree):
    # Create a deep copy of the first tree to modify
    result_tree = copy.deepcopy(first_tree)
    
    # Get all trans-units from the second file and create a dictionary for quick lookup
    ns = {'xliff': 'urn:oasis:names:tc:xliff:document:1.2'}
    second_trans_units = {}
    for trans_unit in second_tree.findall('.//xliff:trans-unit', ns):
        trans_id = trans_unit.get('id')
        target = trans_unit.find('xliff:target', ns)
        if trans_id and target is not None:
            second_trans_units[trans_id] = target.text
    
    # Process all trans-units in the first file
    for trans_unit in result_tree.findall('.//xliff:trans-unit', ns):
        trans_id = trans_unit.get('id')
        if trans_id in second_trans_units:
            # Find the target element
            target = trans_unit.find('xliff:target', ns)
            if target is not None:
                # Create and add the target-classic element after the target
                target_classic = ET.Element('{urn:oasis:names:tc:xliff:document:1.2}target-classic')
                target_classic.text = second_trans_units[trans_id]
                target_classic.set('xml:space', 'preserve')
                
                # Insert target-classic after target
                parent = trans_unit
                target_index = list(parent).index(target)
                parent.insert(target_index + 1, target_classic)
    
    return result_tree

def write_pretty_xml(tree, output_file):
    # Convert ElementTree to string
    rough_string = ET.tostring(tree.getroot(), encoding='utf-8')
    
    # Use minidom to pretty-print
    reparsed = minidom.parseString(rough_string)
    pretty_xml = reparsed.toprettyxml(indent="  ", encoding='utf-8').decode('utf-8')
    
    # Fix double line breaks that minidom sometimes adds
    pretty_xml = '\n'.join([line for line in pretty_xml.split('\n') if line.strip()])
    
    # Write to file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(pretty_xml)

def main():
    if len(sys.argv) != 4:
        print("Usage: python script.py first_file.xliff second_file.xliff output_file.xliff")
        sys.exit(1)
    
    first_file = sys.argv[1]
    second_file = sys.argv[2]
    output_file = sys.argv[3]
    
    register_namespaces()
    
    try:
        first_tree = parse_xliff(first_file)
        second_tree = parse_xliff(second_file)
        
        result_tree = add_target_classic(first_tree, second_tree)
        
        write_pretty_xml(result_tree, output_file)
        print(f"Successfully processed files. Output written to {output_file}")
        
    except Exception as e:
        print(f"Error processing files: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

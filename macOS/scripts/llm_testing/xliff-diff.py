import xml.etree.ElementTree as ET
import copy

XLIFF_NAMESPACE = 'urn:oasis:names:tc:xliff:document:1.2'
NS = {'ns': XLIFF_NAMESPACE}
ET.register_namespace('', XLIFF_NAMESPACE)

def parse_xliff(file):
    tree = ET.parse(file)
    root = tree.getroot()
    return tree, root

def extract_units_by_file_and_id(root):
    files = {}
    for file_elem in root.findall('ns:file', NS):
        original_attr = file_elem.get('original')
        units = {}
        for unit in file_elem.findall('.//ns:trans-unit', NS):
            unit_id = unit.get('id')
            if unit_id:
                units[unit_id] = unit
        files[original_attr] = {
            'file_elem': file_elem,
            'units': units
        }
    return files

def create_new_xliff(missing_files):
    xliff = ET.Element(f'{{{XLIFF_NAMESPACE}}}xliff', version='1.2')
    for original_attr, file_info in missing_files.items():
        orig_file_elem = file_info['file_elem']
        new_file_elem = ET.SubElement(xliff, f'{{{XLIFF_NAMESPACE}}}file', attrib={
            'original': orig_file_elem.get('original'),
            'source-language': orig_file_elem.get('source-language'),
            'target-language': orig_file_elem.get('target-language'),
            'datatype': orig_file_elem.get('datatype'),
        })

        # Copy header if exists
        header = orig_file_elem.find('ns:header', NS)
        if header is not None:
            new_file_elem.append(copy.deepcopy(header))

        body = ET.SubElement(new_file_elem, f'{{{XLIFF_NAMESPACE}}}body')
        for unit in file_info['missing_units']:
            body.append(copy.deepcopy(unit))

    return ET.ElementTree(xliff)

def main(original_file, translated_file, output_file):
    orig_tree, orig_root = parse_xliff(original_file)
    trans_tree, trans_root = parse_xliff(translated_file)

    orig_files = extract_units_by_file_and_id(orig_root)
    trans_files = extract_units_by_file_and_id(trans_root)

    missing_files = {}

    for original_attr, orig_file_info in orig_files.items():
        orig_units = orig_file_info['units']
        trans_units = trans_files.get(original_attr, {}).get('units', {})

        missing_ids = set(orig_units.keys()) - set(trans_units.keys())
        missing_units = [orig_units[unit_id] for unit_id in missing_ids]

        if missing_units:
            missing_files[original_attr] = {
                'file_elem': orig_file_info['file_elem'],
                'missing_units': missing_units
            }

    new_tree = create_new_xliff(missing_files)
    new_tree.write(output_file, encoding='utf-8', xml_declaration=True)
    print(f"✅ Created '{output_file}' with missing trans-units.")

if __name__ == "__main__":
    original_file = './assets/loc/it-orig.xliff'
    translated_file = './assets/loc/random_100_strings.xliff'
    output_file = './assets/loc/it_for_compression.xliff'

    main(original_file, translated_file, output_file)

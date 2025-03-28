import re
import pandas as pd
import os

def parse_translation_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Extract the mapping section
    mapping_section = content.split("Mapping of translations to columns:")[1].strip()
    
    # Initialize lists to store data
    ids = []
    first_translations = []
    second_translations = []
    
    # Pattern to match each translation entry
    pattern = r"ID: (.*?)\n\s+First translation: (.*?)\n\s+Second translation: (.*?)(?=\n-----|$)"
    
    # Find all matches
    matches = re.findall(pattern, mapping_section, re.DOTALL)
    
    # Process matches
    for match in matches:
        id_value = match[0].strip()
        first_translation = match[1].strip()
        second_translation = match[2].strip()
        
        ids.append(id_value)
        first_translations.append(first_translation)
        second_translations.append(second_translation)
    
    # Create DataFrame
    df = pd.DataFrame({
        'ID': ids,
        'First translation': first_translations,
        'Second translation': second_translations
    })
    
    return df

def main():
    input_file = './assets/loc/it_compare_map.txt'  # Change this to your input file path
    output_file = './assets/loc/it_translation_mapping.xlsx'
       
    # Parse the file and get DataFrame
    df = parse_translation_file(input_file)
    
    # Save to Excel
    output_path = output_file
    df.to_excel(output_path, index=False)
    
    print(f"Successfully created Excel file: {output_path}")

if __name__ == "__main__":
    main()

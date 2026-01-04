import json
import os
import xml.sax.saxutils
from collections import defaultdict

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
INPUT_FILE = 'real.json'
OUTPUT_DIR = 'deploy_package'

# Field API Names
FIELD_TYPE_API = 'Type'          # Standard Field (Controller for SubType)
FIELD_SUBTYPE = 'SubType__c'     # Custom Field (Dependent on Type, Controller for Detail)
FIELD_DETAIL = 'Detail__c'       # Custom Field (Dependent on SubType)

STANDARD_VAL_SET = 'CampaignType' # Metadata type for Campaign.Type

def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

def escape_xml(value):
    return xml.sax.saxutils.escape(value)

def create_custom_field_xml(field_api_name, all_values, controlling_field=None, dependency_map=None):
    """
    Generates XML for Custom Fields with optional Dependency logic.
    
    :param field_api_name: The API name of the field being created (e.g., SubType__c)
    :param all_values: A set of all possible values for this field.
    :param controlling_field: The API name of the parent field (e.g., Type).
    :param dependency_map: Dict { 'ChildValue': {'ParentValue1', 'ParentValue2'} }
    """
    label = field_api_name.replace('__c', '')
    
    lines = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append('<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">')
    lines.append(f'    <fullName>{field_api_name}</fullName>')
    lines.append(f'    <label>{label}</label>')
    lines.append('    <type>Picklist</type>')
    lines.append('    <valueSet>')
    
    # 1. Define the Controlling Field (if applicable)
    if controlling_field:
        lines.append(f'        <controllingField>{controlling_field}</controllingField>')

    lines.append('        <valueSetDefinition>')
    lines.append('            <sorted>false</sorted>')
    
    # 2. Define All Possible Values
    sorted_values = sorted(list(all_values))
    for val in sorted_values:
        clean_val = escape_xml(val)
        lines.append('            <value>')
        lines.append(f'                <fullName>{clean_val}</fullName>')
        lines.append('                <default>false</default>')
        lines.append(f'                <label>{clean_val}</label>')
        lines.append('            </value>')
    lines.append('        </valueSetDefinition>')

    # 3. Define Dependency Mappings (ValueSettings)
    # This maps which Controlling Values enable which Dependent Value
    if controlling_field and dependency_map:
        for child_val in sorted_values:
            # Only create settings if this child has parents defined in the map
            if child_val in dependency_map and dependency_map[child_val]:
                clean_child = escape_xml(child_val)
                lines.append('        <valueSettings>')
                lines.append(f'            <valueName>{clean_child}</valueName>')
                
                # List all parent values that enable this child
                for parent_val in sorted(list(dependency_map[child_val])):
                    lines.append(f'            <controllingFieldValue>{escape_xml(parent_val)}</controllingFieldValue>')
                
                lines.append('        </valueSettings>')

    lines.append('    </valueSet>')
    lines.append('</CustomField>')
    return "\n".join(lines)

def create_standard_valueset_xml(values_set):
    """
    Generates XML for Standard Value Sets (CampaignType).
    Standard fields act as controllers but don't usually store dependency info inside themselves.
    """
    lines = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append('<StandardValueSet xmlns="http://soap.sforce.com/2006/04/metadata">')
    lines.append('    <sorted>false</sorted>')
    
    for val in sorted(list(values_set)):
        clean_val = escape_xml(val)
        lines.append('    <standardValue>')
        lines.append(f'        <fullName>{clean_val}</fullName>')
        lines.append('        <default>false</default>')
        lines.append(f'        <label>{clean_val}</label>')
        lines.append('    </standardValue>')
        
    lines.append('</StandardValueSet>')
    return "\n".join(lines)

def process_json_and_generate_files():
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        return

    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Sets to store unique values for definition
    type_values = set()
    subtype_values = set()
    detail_values = set()

    # Maps for dependencies: Key = Child Value, Value = Set of Parent Values
    # We use sets because a specific SubType might appear under multiple Types in the JSON
    subtype_dependency_map = defaultdict(set) # Maps SubType -> {Type A, Type B}
    detail_dependency_map = defaultdict(set)  # Maps Detail -> {SubType 1, SubType 2}

    # --- Parse JSON to build sets and maps ---
    for level1 in data:
        t_name = level1.get('name')
        if t_name:
            type_values.add(t_name)
        
        if 'subtypes' in level1:
            for level2 in level1['subtypes']:
                st_name = level2.get('name')
                if st_name:
                    subtype_values.add(st_name)
                    # Map this SubType to its parent Type
                    if t_name:
                        subtype_dependency_map[st_name].add(t_name)
                
                if 'details' in level2:
                    for level3 in level2['details']:
                        d_name = level3.get('name')
                        if d_name:
                            detail_values.add(d_name)
                            # Map this Detail to its parent SubType
                            if st_name:
                                detail_dependency_map[d_name].add(st_name)

    # --- File Generation ---
    fields_dir = os.path.join(OUTPUT_DIR, 'objects', 'Campaign', 'fields')
    svs_dir = os.path.join(OUTPUT_DIR, 'standardValueSets')
    
    ensure_dir(fields_dir)
    ensure_dir(svs_dir)

    # 1. Write Standard Value Set (Type) - No dependencies here
    with open(os.path.join(svs_dir, f'{STANDARD_VAL_SET}.standardValueSet-meta.xml'), 'w', encoding='utf-8') as f:
        f.write(create_standard_valueset_xml(type_values))

    # 2. Write SubType__c (Dependent on Type)
    with open(os.path.join(fields_dir, f'{FIELD_SUBTYPE}.field-meta.xml'), 'w', encoding='utf-8') as f:
        xml_content = create_custom_field_xml(
            field_api_name=FIELD_SUBTYPE,
            all_values=subtype_values,
            controlling_field=FIELD_TYPE_API, # 'Type'
            dependency_map=subtype_dependency_map
        )
        f.write(xml_content)

    # 3. Write Detail__c (Dependent on SubType__c)
    with open(os.path.join(fields_dir, f'{FIELD_DETAIL}.field-meta.xml'), 'w', encoding='utf-8') as f:
        xml_content = create_custom_field_xml(
            field_api_name=FIELD_DETAIL,
            all_values=detail_values,
            controlling_field=FIELD_SUBTYPE, # 'SubType__c'
            dependency_map=detail_dependency_map
        )
        f.write(xml_content)

    # 4. Generate package.xml
    package_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>Campaign.SubType__c</members>
        <members>Campaign.Detail__c</members>
        <name>CustomField</name>
    </types>
    <types>
        <members>CampaignType</members>
        <name>StandardValueSet</name>
    </types>
    <version>58.0</version>
</Package>"""
    
    with open(os.path.join(OUTPUT_DIR, 'package.xml'), 'w', encoding='utf-8') as f:
        f.write(package_xml)

    print(f"Success! Metadata generated in '{OUTPUT_DIR}'")
    print(f"Dependencies mapped: Type->SubType and SubType->Detail")

if __name__ == "__main__":
    process_json_and_generate_files()
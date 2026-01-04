import json
import os
import re
import xml.sax.saxutils

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
INPUT_FILE = 'real.json'
ROOT_DIR = 'deploy_pkg'
OBJECTS_DIR = os.path.join(ROOT_DIR, 'objects')
RECORDS_DIR = os.path.join(ROOT_DIR, 'customMetadata')

MDT_OBJECT_NAME = 'Financial_Campaign_Config__mdt' 
MDT_FILENAME_PREFIX = 'Financial_Campaign_Config'

# ---------------------------------------------------------
# TEMPLATES
# ---------------------------------------------------------

# The definition of the object and its fields
OBJECT_XML_CONTENT = f"""<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Financial Campaign Config</label>
    <pluralLabel>Financial Campaign Configs</pluralLabel>
    <visibility>Public</visibility>
    <fields>
        <fullName>Type__c</fullName>
        <externalId>false</externalId>
        <label>Type</label>
        <length>255</length>
        <required>false</required>
        <type>Text</type>
        <unique>false</unique>
    </fields>
    <fields>
        <fullName>SubType__c</fullName>
        <externalId>false</externalId>
        <label>Sub Type</label>
        <length>255</length>
        <required>false</required>
        <type>Text</type>
        <unique>false</unique>
    </fields>
    <fields>
        <fullName>Detail__c</fullName>
        <externalId>false</externalId>
        <label>Detail</label>
        <length>255</length>
        <required>false</required>
        <type>Text</type>
        <unique>false</unique>
    </fields>
    <fields>
        <fullName>Campaign_Name__c</fullName>
        <externalId>false</externalId>
        <label>Campaign Name Format</label>
        <length>255</length>
        <required>false</required>
        <type>Text</type>
        <unique>false</unique>
    </fields>
    <fields>
        <fullName>Has_Year__c</fullName>
        <defaultValue>false</defaultValue>
        <externalId>false</externalId>
        <label>Connected To Year</label>
        <type>Checkbox</type>
    </fields>
</CustomObject>
"""

# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------

def ensure_dirs():
    if not os.path.exists(OBJECTS_DIR):
        os.makedirs(OBJECTS_DIR)
    if not os.path.exists(RECORDS_DIR):
        os.makedirs(RECORDS_DIR)

def escape_xml(value):
    if value is None: return ""
    return xml.sax.saxutils.escape(str(value), {"'": "&apos;", "\"": "&quot;"})

def sanitize_developer_name(text):
    # Alphanumeric and underscores only, no double underscores
    clean = re.sub(r'[^a-zA-Z0-9]', '_', text)
    clean = re.sub(r'_+', '_', clean)
    return clean.strip('_')

def create_mdt_record_xml(label, values):
    lines = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append(f'<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="{MDT_OBJECT_NAME}">')
    lines.append(f'    <label>{escape_xml(label)}</label>')
    lines.append(f'    <protected>false</protected>')
    
    for field_api, val in values.items():
        lines.append('    <values>')
        lines.append(f'        <field>{field_api}</field>')
        if isinstance(val, bool):
            xsi_type = "xsd:boolean"
            val_str = str(val).lower()
        else:
            xsi_type = "xsd:string"
            val_str = escape_xml(val)
        lines.append(f'        <value xsi:type="{xsi_type}">{val_str}</value>')
        lines.append('    </values>')

    lines.append('</CustomMetadata>')
    return "\n".join(lines)

def generate_object_file():
    filename = f"{MDT_OBJECT_NAME}.object"
    file_path = os.path.join(OBJECTS_DIR, filename)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(OBJECT_XML_CONTENT)
    print(f"Generated Object Definition: {filename}")

def generate_record_file(dev_name, label, field_data):
    # Returns the full member name for package.xml (e.g., Object.Record)
    full_member_name = f"{MDT_FILENAME_PREFIX}.{dev_name}"
    filename = f"{full_member_name}.md-meta.xml"
    file_path = os.path.join(RECORDS_DIR, filename)
    
    xml_content = create_mdt_record_xml(label, field_data)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    return full_member_name

def generate_package_xml(members):
    lines = []
    lines.append('<?xml version="1.0" encoding="UTF-8"?>')
    lines.append('<Package xmlns="http://soap.sforce.com/2006/04/metadata">')
    
    # Add the Custom Object definition
    lines.append('    <types>')
    lines.append(f'        <members>{MDT_OBJECT_NAME}</members>')
    lines.append('        <name>CustomObject</name>')
    lines.append('    </types>')
    
    # Add the Custom Metadata Records
    lines.append('    <types>')
    for m in sorted(members):
        lines.append(f'        <members>{m}</members>')
    lines.append('        <name>CustomMetadata</name>')
    lines.append('    </types>')
    
    lines.append('    <version>58.0</version>')
    lines.append('</Package>')
    
    with open(os.path.join(ROOT_DIR, 'package.xml'), 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))
    print("Generated package.xml")

# ---------------------------------------------------------
# MAIN LOGIC
# ---------------------------------------------------------

def process_json():
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        return

    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    ensure_dirs()
    generate_object_file()
    
    generated_members = []

    # TRAVERSAL
    for type_node in data:
        type_name = type_node.get('name', '')
        
        # LEVEL 1
        if type_node.get('independentEntry') is True:
            dev_name = sanitize_developer_name(type_name)
            label = type_name[:40]
            fields = {
                'Type__c': type_name, 'SubType__c': '', 'Detail__c': '',
                'Campaign_Name__c': type_node.get('campaignName', ''),
                'Has_Year__c': type_node.get('connectedToYear', False)
            }
            generated_members.append(generate_record_file(dev_name, label, fields))

        # LEVEL 2
        if 'subtypes' in type_node:
            for sub_node in type_node['subtypes']:
                sub_name = sub_node.get('name', '')
                if sub_node.get('independentEntry') is True:
                    dev_name = sanitize_developer_name(f"{type_name}_{sub_name}")
                    label = f"{type_name} - {sub_name}"[:40]
                    fields = {
                        'Type__c': type_name, 'SubType__c': sub_name, 'Detail__c': '',
                        'Campaign_Name__c': sub_node.get('campaignName', ''),
                        'Has_Year__c': sub_node.get('connectedToYear', False)
                    }
                    generated_members.append(generate_record_file(dev_name, label, fields))

                # LEVEL 3
                if 'details' in sub_node:
                    for detail_node in sub_node['details']:
                        detail_name = detail_node.get('name', '')
                        if detail_node.get('independentEntry') is True:
                            dev_name = sanitize_developer_name(f"{type_name}_{sub_name}_{detail_name}")
                            label = f"{sub_name} - {detail_name}"[:40]
                            fields = {
                                'Type__c': type_name, 'SubType__c': sub_name, 'Detail__c': detail_name,
                                'Campaign_Name__c': detail_node.get('campaignName', ''),
                                'Has_Year__c': detail_node.get('connectedToYear', False)
                            }
                            generated_members.append(generate_record_file(dev_name, label, fields))

    generate_package_xml(generated_members)
    print(f"\nSuccess! Deployment package created in folder: '{ROOT_DIR}'")

if __name__ == "__main__":
    process_json()
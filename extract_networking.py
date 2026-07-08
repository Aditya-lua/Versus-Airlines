import xml.etree.ElementTree as ET

tree = ET.parse("97598239454123_Grow_a_Garden_2/97598239454123_Grow_a_Garden_2__ReplicatedStorage.rbxmx")
root = tree.getroot()

for item in root.iter('Item'):
    if item.attrib.get('class') == 'ModuleScript' and item.attrib.get('name') == 'Networking':
        for props in item.findall('Properties'):
            for string_prop in props.findall('ProtectedString'):
                if string_prop.attrib.get('name') == 'Source':
                    print(string_prop.text)

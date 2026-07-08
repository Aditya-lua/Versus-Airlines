import xml.etree.ElementTree as ET

tree = ET.parse("97598239454123_Grow_a_Garden_2/97598239454123_Grow_a_Garden_2__ReplicatedStorage.rbxmx")
root = tree.getroot()

def get_paths(elem, current_path):
    name = elem.attrib.get('name')
    new_path = f"{current_path}.{name}" if current_path else name
    cls = elem.attrib.get('class')
    
    if cls in ['RemoteEvent', 'RemoteFunction']:
        print(new_path)
    
    for child in elem.findall('Item'):
        get_paths(child, new_path)

for item in root.iter('Item'):
    if item.attrib.get('name') == 'Remotes':
        for child in item.findall('Item'):
            get_paths(child, "")
        break

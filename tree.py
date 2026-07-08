import xml.etree.ElementTree as ET

tree = ET.parse("97598239454123_Grow_a_Garden_2/97598239454123_Grow_a_Garden_2__ReplicatedStorage.rbxmx")
root = tree.getroot()

def print_tree(elem, indent=""):
    print(f"{indent}{elem.attrib.get('class', '')} : {elem.attrib.get('name', 'Unknown')}")
    for child in elem.findall('Item'):
        print_tree(child, indent + "  ")

for item in root.iter('Item'):
    if item.attrib.get('name') == 'Remotes':
        print_tree(item)
        break

import xml.etree.ElementTree as ET

tree = ET.parse("97598239454123_Grow_a_Garden_2/97598239454123_Grow_a_Garden_2__LocalPlayer_PlayerGui.rbxmx")
root = tree.getroot()

for props in root.iter('ProtectedString'):
    if props.attrib.get('name') == 'Source':
        if 'PurchasePet' in props.text:
            print("Found in source:", props.text[:200])

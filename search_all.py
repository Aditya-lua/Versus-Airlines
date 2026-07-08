import os
import xml.etree.ElementTree as ET

for f in os.listdir("97598239454123_Grow_a_Garden_2"):
    if not f.endswith(".rbxmx"): continue
    path = os.path.join("97598239454123_Grow_a_Garden_2", f)
    try:
        tree = ET.parse(path)
        for props in tree.getroot().iter('ProtectedString'):
            if props.attrib.get('name') == 'Source':
                if 'HarvestAll' in props.text:
                    print(f"Found in {f}")
    except:
        pass

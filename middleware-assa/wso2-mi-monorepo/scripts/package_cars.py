#!/usr/bin/env python3
import os
import shutil
import zipfile
import xml.etree.ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED_DIR = os.path.join(REPO_ROOT, "shared")
SR_DIR = os.path.join(REPO_ROOT, "integrations", "service-request-service")
TMP_DIR = "/tmp/car_build"

DIST_DIR = os.path.join(REPO_ROOT, "dist-cars")
os.makedirs(DIST_DIR, exist_ok=True)

def repack_car(car_path, extract_dir, out_car_path):
    with zipfile.ZipFile(out_car_path, 'w', zipfile.ZIP_DEFLATED) as zip_out:
        for root, dirs, files in os.walk(extract_dir):
            for d in dirs:
                full_path = os.path.join(root, d)
                rel_path = os.path.relpath(full_path, extract_dir) + "/"
                zipfile_info = zipfile.ZipInfo(rel_path)
                zip_out.writestr(zipfile_info, '')
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, extract_dir)
                zip_out.write(full_path, rel_path)

def fix_db_urls(extract_dir):
    for root, dirs, files in os.walk(extract_dir):
        for file in files:
            if file.endswith(".xml") or file.endswith(".properties"):
                p = os.path.join(root, file)
                with open(p, "r", encoding="utf-8") as f:
                    content = f.read()
                if "localhost:3307" in content:
                    content = content.replace("localhost:3307", "mariadb:3306")
                    with open(p, "w", encoding="utf-8") as f:
                        f.write(content)

def update_shared_car():
    print("[1/2] Updating shared-artifacts_1.0.0.car...")
    car_src = "/tmp/shared.car"
    extract_dir = os.path.join(TMP_DIR, "shared")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
        
    # Copy updated AuthGuardSeq.xml
    src_auth = os.path.join(SHARED_DIR, "src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml")
    dest_auth = os.path.join(extract_dir, "AuthGuardSeq_1.0.0/AuthGuardSeq-1.0.0.xml")
    shutil.copy2(src_auth, dest_auth)
    print("  -> Updated AuthGuardSeq-1.0.0.xml")
    
    # Fix database URLs for docker networking
    fix_db_urls(extract_dir)
    print("  -> Updated database connection URLs to mariadb:3306")
    
    out_car = os.path.join(DIST_DIR, "shared-artifacts_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    shutil.copy2(out_car, "/tmp/shared-artifacts_1.0.0.car")
    print(f"  -> Generated {out_car}")

def update_sr_car():
    print("[2/2] Updating service-request-service_1.0.0.car...")
    car_src = "/tmp/sr.car"
    extract_dir = os.path.join(TMP_DIR, "sr")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
        
    # 1. Update ServiceRequestSeq.xml
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/ServiceRequestSeq.xml"),
        os.path.join(extract_dir, "ServiceRequestSeq_1.0.0/ServiceRequestSeq-1.0.0.xml")
    )
    print("  -> Updated ServiceRequestSeq-1.0.0.xml")

    # 2. Update ServiceRequestAPI.xml
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/apis/ServiceRequestAPI.xml"),
        os.path.join(extract_dir, "ServiceRequestAPI_1.0.0/ServiceRequestAPI-1.0.0.xml")
    )
    print("  -> Updated ServiceRequestAPI-1.0.0.xml")

    # 3. Update SrToExtServiceSeq.xml
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/SrToExtServiceSeq.xml"),
        os.path.join(extract_dir, "SrToExtServiceSeq_1.0.0/SrToExtServiceSeq-1.0.0.xml")
    )
    print("  -> Updated SrToExtServiceSeq-1.0.0.xml")

    # 4. Update SrAggregateResponseSeq.xml
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/SrAggregateResponseSeq.xml"),
        os.path.join(extract_dir, "SrAggregateResponseSeq_1.0.0/SrAggregateResponseSeq-1.0.0.xml")
    )
    print("  -> Updated SrAggregateResponseSeq-1.0.0.xml")

    # 5. Update config.properties
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/resources/conf/config.properties"),
        os.path.join(extract_dir, "config_1.0.0/config.properties")
    )
    print("  -> Updated config.properties")

    # 6. Add PublicServiceRequestAPI_1.0.0
    pub_api_dir = os.path.join(extract_dir, "PublicServiceRequestAPI_1.0.0")
    os.makedirs(pub_api_dir, exist_ok=True)
    with open(os.path.join(pub_api_dir, "artifact.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?><artifact name="PublicServiceRequestAPI" version="1.0.0" type="synapse/api" serverRole="EnterpriseIntegrator">\n    <file>PublicServiceRequestAPI-1.0.0.xml</file>\n</artifact>\n')
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/apis/PublicServiceRequestAPI.xml"),
        os.path.join(pub_api_dir, "PublicServiceRequestAPI-1.0.0.xml")
    )
    print("  -> Added PublicServiceRequestAPI_1.0.0")

    # 7. Add ServiceRequestGetSeq_1.0.0
    get_seq_dir = os.path.join(extract_dir, "ServiceRequestGetSeq_1.0.0")
    os.makedirs(get_seq_dir, exist_ok=True)
    with open(os.path.join(get_seq_dir, "artifact.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?><artifact name="ServiceRequestGetSeq" version="1.0.0" type="synapse/sequence" serverRole="EnterpriseIntegrator">\n    <file>ServiceRequestGetSeq-1.0.0.xml</file>\n</artifact>\n')
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/ServiceRequestGetSeq.xml"),
        os.path.join(get_seq_dir, "ServiceRequestGetSeq-1.0.0.xml")
    )
    print("  -> Added ServiceRequestGetSeq_1.0.0")

    # 8. Update artifacts.xml and metadata.xml
    for meta_file in ["artifacts.xml", "metadata.xml"]:
        artifacts_xml_path = os.path.join(extract_dir, meta_file)
        if os.path.exists(artifacts_xml_path):
            tree = ET.parse(artifacts_xml_path)
            root = tree.getroot()
            main_art = root.find("artifact")
            deps = [d.attrib.get("artifact") for d in main_art.findall("dependency")]
            if "PublicServiceRequestAPI" not in deps:
                elem = ET.SubElement(main_art, "dependency")
                elem.attrib = {"artifact": "PublicServiceRequestAPI", "version": "1.0.0", "include": "true", "serverRole": "EnterpriseIntegrator"}
            if "ServiceRequestGetSeq" not in deps:
                elem = ET.SubElement(main_art, "dependency")
                elem.attrib = {"artifact": "ServiceRequestGetSeq", "version": "1.0.0", "include": "true", "serverRole": "EnterpriseIntegrator"}
            tree.write(artifacts_xml_path, encoding="UTF-8", xml_declaration=True)
            print(f"  -> Updated {meta_file} dependencies")

    # Fix database URLs for docker networking
    fix_db_urls(extract_dir)
    print("  -> Updated database connection URLs to mariadb:3306")

    out_car = os.path.join(DIST_DIR, "service-request-service_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    shutil.copy2(out_car, "/tmp/service-request-service_1.0.0.car")
    print(f"  -> Generated {out_car}")

if __name__ == "__main__":
    update_shared_car()
    update_sr_car()
    print("Done! Both CAR packages updated successfully.")

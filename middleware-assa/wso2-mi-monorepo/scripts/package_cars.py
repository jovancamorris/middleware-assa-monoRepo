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
SHARED_CAR = os.path.join(SHARED_DIR, "target", "shared-artifacts_1.0.0.car")
SR_CAR = os.path.join(SR_DIR, "target", "service-request-service_1.0.0.car")
OTHER_SERVICES = [
    "branch-service",
    "customer-service",
    "spk-service",
    "vendor-service",
    "payments-service",
]
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
    car_src = SHARED_CAR
    if not os.path.exists(car_src) or "AuthGuardSeq_1.0.0/AuthGuardSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "shared-artifacts_1.0.0.car")
    if not os.path.exists(car_src):
        raise FileNotFoundError(f"Missing generated CAR: {car_src}.")
    extract_dir = os.path.join(TMP_DIR, "shared")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
        
    # Copy updated AuthGuardSeq.xml & DbRecordTransactionSeq.xml
    src_auth = os.path.join(SHARED_DIR, "src/main/wso2mi/artifacts/sequences/AuthGuardSeq.xml")
    dest_auth = os.path.join(extract_dir, "AuthGuardSeq_1.0.0/AuthGuardSeq-1.0.0.xml")
    shutil.copy2(src_auth, dest_auth)
    print("  -> Updated AuthGuardSeq-1.0.0.xml")

    src_dbt = os.path.join(SHARED_DIR, "src/main/wso2mi/artifacts/sequences/DbRecordTransactionSeq.xml")
    dest_dbt = os.path.join(extract_dir, "DbRecordTransactionSeq_1.0.0/DbRecordTransactionSeq-1.0.0.xml")
    shutil.copy2(src_dbt, dest_dbt)
    print("  -> Updated DbRecordTransactionSeq-1.0.0.xml")

    src_dbal = os.path.join(SHARED_DIR, "src/main/wso2mi/artifacts/sequences/DbRecordAttemptLogSeq.xml")
    dest_dbal = os.path.join(extract_dir, "DbRecordAttemptLogSeq_1.0.0/DbRecordAttemptLogSeq-1.0.0.xml")
    if os.path.exists(src_dbal):
        shutil.copy2(src_dbal, dest_dbal)
        print("  -> Updated DbRecordAttemptLogSeq-1.0.0.xml")

    src_gps = os.path.join(SHARED_DIR, "src/main/wso2mi/artifacts/sequences/GenericPaginationSeq.xml")
    dest_gps = os.path.join(extract_dir, "GenericPaginationSeq_1.0.0/GenericPaginationSeq-1.0.0.xml")
    if os.path.exists(src_gps):
        shutil.copy2(src_gps, dest_gps)
        print("  -> Updated GenericPaginationSeq-1.0.0.xml")
    
    # Fix database URLs for docker networking
    fix_db_urls(extract_dir)
    print("  -> Updated database connection URLs to mariadb:3306")
    
    out_car = os.path.join(DIST_DIR, "shared-artifacts_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    shutil.copy2(out_car, "/tmp/shared-artifacts_1.0.0.car")
    print(f"  -> Generated {out_car}")

def update_sr_car():
    print("[2/2] Updating service-request-service_1.0.0.car...")
    car_src = SR_CAR
    if not os.path.exists(car_src) or "ServiceRequestSeq_1.0.0/ServiceRequestSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "service-request-service_1.0.0.car")
    if not os.path.exists(car_src):
        raise FileNotFoundError(f"Missing generated CAR: {car_src}.")
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

    # 7b. Update SrToAtlasSeq.xml, SrExtServiceErrorHandlerSeq.xml, SrAtlasErrorHandlerSeq.xml
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/SrToAtlasSeq.xml"),
        os.path.join(extract_dir, "SrToAtlasSeq_1.0.0/SrToAtlasSeq-1.0.0.xml")
    )
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/SrExtServiceErrorHandlerSeq.xml"),
        os.path.join(extract_dir, "SrExtServiceErrorHandlerSeq_1.0.0/SrExtServiceErrorHandlerSeq-1.0.0.xml")
    )
    shutil.copy2(
        os.path.join(SR_DIR, "src/main/wso2mi/artifacts/sequences/SrAtlasErrorHandlerSeq.xml"),
        os.path.join(extract_dir, "SrAtlasErrorHandlerSeq_1.0.0/SrAtlasErrorHandlerSeq-1.0.0.xml")
    )
    print("  -> Updated SrToAtlasSeq, SrExtServiceErrorHandlerSeq, and SrAtlasErrorHandlerSeq")

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

def update_vehicle_car():
    print("[3/3] Updating vehicle-service_1.0.0.car...")
    veh_dir = os.path.join(REPO_ROOT, "integrations", "vehicle-service")
    car_src = os.path.join(veh_dir, "target", "vehicle-service_1.0.0.car")
    if not os.path.exists(car_src) or "VehicleGetByLicensePlateSeq_1.0.0/VehicleGetByLicensePlateSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "vehicle-service_1.0.0.car")
    if not os.path.exists(car_src):
        return
    extract_dir = os.path.join(TMP_DIR, "vehicle")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
    shutil.copy2(
        os.path.join(veh_dir, "src/main/wso2mi/artifacts/sequences/VehicleGetByLicensePlateSeq.xml"),
        os.path.join(extract_dir, "VehicleGetByLicensePlateSeq_1.0.0/VehicleGetByLicensePlateSeq-1.0.0.xml")
    )
    api_src = os.path.join(veh_dir, "src/main/wso2mi/artifacts/apis/VehicleAPI.xml")
    api_dest = os.path.join(extract_dir, "VehicleAPI_1.0.0/VehicleAPI-1.0.0.xml")
    if os.path.exists(api_dest):
        shutil.copy2(api_src, api_dest)
        print("  -> Updated VehicleAPI-1.0.0.xml")
    fix_db_urls(extract_dir)
    out_car = os.path.join(DIST_DIR, "vehicle-service_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    print(f"  -> Generated {out_car}")

def update_customer_car():
    print("[4/4] Updating customer-service_1.0.0.car...")
    cust_dir = os.path.join(REPO_ROOT, "integrations", "customer-service")
    car_src = os.path.join(cust_dir, "target", "customer-service_1.0.0.car")
    if not os.path.exists(car_src) or "CustomerGetByCreateDateSeq_1.0.0/CustomerGetByCreateDateSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "customer-service_1.0.0.car")
    if not os.path.exists(car_src):
        return
    extract_dir = os.path.join(TMP_DIR, "customer")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
    shutil.copy2(
        os.path.join(cust_dir, "src/main/wso2mi/artifacts/sequences/CustomerGetByCreateDateSeq.xml"),
        os.path.join(extract_dir, "CustomerGetByCreateDateSeq_1.0.0/CustomerGetByCreateDateSeq-1.0.0.xml")
    )
    fix_db_urls(extract_dir)
    out_car = os.path.join(DIST_DIR, "customer-service_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    print(f"  -> Generated {out_car}")

def update_branch_car():
    print("[5/5] Updating branch-service_1.0.0.car...")
    br_dir = os.path.join(REPO_ROOT, "integrations", "branch-service")
    car_src = os.path.join(br_dir, "target", "branch-service_1.0.0.car")
    if not os.path.exists(car_src) or "BranchGetByCreateDateSeq_1.0.0/BranchGetByCreateDateSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "branch-service_1.0.0.car")
    if not os.path.exists(car_src):
        return
    extract_dir = os.path.join(TMP_DIR, "branch")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
    shutil.copy2(
        os.path.join(br_dir, "src/main/wso2mi/artifacts/sequences/BranchGetByCreateDateSeq.xml"),
        os.path.join(extract_dir, "BranchGetByCreateDateSeq_1.0.0/BranchGetByCreateDateSeq-1.0.0.xml")
    )
    fix_db_urls(extract_dir)
    out_car = os.path.join(DIST_DIR, "branch-service_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    print(f"  -> Generated {out_car}")

def update_vendor_car():
    print("[6/6] Updating vendor-service_1.0.0.car...")
    vmd_dir = os.path.join(REPO_ROOT, "integrations", "vendor-service")
    car_src = os.path.join(vmd_dir, "target", "vendor-service_1.0.0.car")
    if not os.path.exists(car_src) or "VendorCreateSeq_1.0.0/VendorCreateSeq-1.0.0.xml" not in zipfile.ZipFile(car_src).namelist():
        car_src = os.path.join(DIST_DIR, "vendor-service_1.0.0.car")
    if not os.path.exists(car_src):
        return
    extract_dir = os.path.join(TMP_DIR, "vendor")
    if os.path.exists(extract_dir):
        shutil.rmtree(extract_dir)
    os.makedirs(extract_dir, exist_ok=True)
    with zipfile.ZipFile(car_src, 'r') as z:
        z.extractall(extract_dir)
    shutil.copy2(
        os.path.join(vmd_dir, "src/main/wso2mi/artifacts/sequences/VendorCreateSeq.xml"),
        os.path.join(extract_dir, "VendorCreateSeq_1.0.0/VendorCreateSeq-1.0.0.xml")
    )
    print("  -> Updated VendorCreateSeq-1.0.0.xml")
    xslt_src = os.path.join(vmd_dir, "src/main/wso2mi/artifacts/local-entries/VendorCreateXmlXslt.xml")
    xslt_dest = os.path.join(extract_dir, "VendorCreateXmlXslt_1.0.0/VendorCreateXmlXslt-1.0.0.xml")
    if os.path.exists(xslt_dest):
        shutil.copy2(xslt_src, xslt_dest)
        print("  -> Updated VendorCreateXmlXslt-1.0.0.xml")
    fix_db_urls(extract_dir)
    out_car = os.path.join(DIST_DIR, "vendor-service_1.0.0.car")
    repack_car(car_src, extract_dir, out_car)
    print(f"  -> Generated {out_car}")

def stage_service_car(car_src):
    if os.path.exists(car_src):
        out_car = os.path.join(DIST_DIR, os.path.basename(car_src))
        shutil.copy2(car_src, out_car)
        print(f"  -> Staged {out_car}")

if __name__ == "__main__":
    update_shared_car()
    update_sr_car()
    update_vehicle_car()
    update_customer_car()
    update_branch_car()
    update_vendor_car()
    for s in OTHER_SERVICES:
        if s in ["customer-service", "branch-service", "vendor-service"]:
            continue
        car_path = os.path.join(REPO_ROOT, "integrations", s, "target", f"{s}_1.0.0.car")
        stage_service_car(car_path)
    print("Done! All CAR packages staged successfully.")

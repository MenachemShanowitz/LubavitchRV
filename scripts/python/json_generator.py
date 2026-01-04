import csv
import json
import io

# The CSV data provided
csv_data = """Type,SubType,Detail,Connected to a Year,Campaign Name
General,Seforim,,No,Seforim
General,Torah Fund,,No,Torah Fund
General,Yahrtzeit/Yizkor,,No,Yizkor
General,,,No,General
General,Building Fund,,No,General Building
General,Electric Bill,,No,General Electric
General,Furniture,,No,General Furniture
General,Unknown,,No,General Unknown
General,Building Upkeep,,No,General Upkeep
General,Men Mikvah,,No,General Men's Mikvah
General,Mikvah Fund,,No,General Mikvah Fund
General,Children Books,,No,Childrens Book
General,Mashapia,,No,Mashpia
General,Birthday Club,,No,Birthday Club
Kibudim,Shabbos,,Yes,{year} - Shabbos Kibud
Kibudim,Rosh Hashana,,Yes,{year} - RH Kibud
Kibudim,Yom Kipur,,Yes,{year} - Yom Kipur Kibud
Kibudim,Sukkos,,Yes,{year} - Sukkos Kibud
Kibudim,Simchas Torah,,Yes,{year} - Simchas Torah Kibud
Kibudim,Pesach,,Yes,{year} - Pesach Kibud
Kibudim,Shavuos,,Yes,{year} - Shavuos Kibud
Kibudim,Hagbah Yearly,,Yes,{year} - Hagbah Yearly
Kibudim,Psicha Yearly,,Yes,{year} - Psicha Yearly
Kibudim,Chazak,,Yes,{year} - Chazak
Kibudim,Chanuka,,Yes,{year} - Chanuka Kibud
Membership,,,Yes,{year} - Membership
Services,Hoshanos,,Yes,Hoshanos
Grants,Maos Chitim,,Yes,{year} - Maos Chittim
Grants,Tishrei Yom Tov Fund,,Yes,{year} - Tishrei Fund
Grants,General,,Yes,{year} - General Grant
Events,Tishrei,,Yes,{year} - Tishrei
Events,Chanukah,,Yes,{year} - Chanukah
Events,19 Kislev,,Yes,{year} - 19 Kislev
Events,Farbrengen Genaral,,Yes,{year} - Farbrengen Genaral
Events,Purim,,Yes,{year} - Purim
Events,Mesibas Shabbos,,Yes,{year} - Mesibas Shabbos
Events,Kiddush,,Yes,{year} - Kiddush
Events,Shiurim,,Yes,{year} - Shiurim
Events,11 Nison,,Yes,{year} - 11 Nison
Events,Avos Ubonim,,Yes,{year} - Avos Ubonim
Events,Kids Rally,,Yes,{year} - Kids Rally
Events,Shabbos Kids Program,,Yes,{year} - Shabbos Kids Program
Events,Siyum Harambam,,Yes,{year} - Siyum Harambam
Events,Tanya,,No,Tanya
Events,Nshei,,Yes,{year} - Nshei
Events,3 Tamuz,,Yes,{year} - 3 Tamuz
Events,20 Av,,Yes,{year} - 20 Av
Events,Break Fast,,Yes,{year} - Break Fast
Events,Rosh Chodesh Kislev,,Yes,{year} - Rosh Chodesh Kislev
Advertising,,,No,Advertising
Shul Renovation,New Flooring,,No,New Flooring
Shul Renovation,Men's Mikvah,,No,Men's Mikvah
Shul Renovation,Mikvah Fund,,No,Mikvah Fund
Hall Rental,Big Hall,,No,Big Hall Rentel
Hall Rental,Cheder Sheni,,No,Cheder Sheni Rentel
Kibudim,Shabbos,Aliyah,Yes,{year} - Aliyah
Kibudim,Yom Kipur,Maftir Yona,Yes,{year} - Maftir Yona
Kibudim,Yom Kipur,Kol Nidrei,Yes,{year} - Kol Nidrei
Kibudim,Sukkos,Aliyah,Yes,{year} - Sukkos Aliyah
Kibudim,Sukkos,Psicha,Yes,{year} - Sukkos Psicha
Kibudim,Sukkos,Hagbah,Yes,{year} - Sukkos Hagbah
Kibudim,Sukkos,Gelilah,Yes,{year} - Sukkos Gelilah
Kibudim,Simchas Torah,Geshem,Yes,{year} - Geshem
Kibudim,Simchas Torah,Ata Horisa,Yes,{year} - Ata Horaisa
Kibudim,Simchas Torah,Aliyah,Yes,{year} - Simchas Torah Aliyah
Kibudim,Simchas Torah,Psicha,Yes,{year} - Simchas Torah Psicha
Kibudim,Simchas Torah,Hagbah,Yes,{year} - Simchas Torah Hagbah
Kibudim,Simchas Torah,Gelilah,Yes,{year} - Simchas Torah Gelilah
Kibudim,Simchas Torah,Choson Torah,Yes,{year} - Choson Torah
Kibudim,Simchas Torah,Choson Breishis,Yes,{year} - Choson Bereishis
Kibudim,Simchas Torah,Kol Hane'orim,Yes,{year} - Kol Hane'orim
Kibudim,Simchas Torah,Vehoyo Zar'acho,Yes,{year} - Vehoyo Zar'acho
Kibudim,Pesach,Tal,Yes,{year} - Tal
Kibudim,Hagbah Yearly,Bereshis,Yes,{year} - Hagbah Bereshis
Kibudim,Hagbah Yearly,Shemos,Yes,{year} - Hagbah Shemos
Kibudim,Hagbah Yearly,Vayikra,Yes,{year} - Hagbah Vayikra
Kibudim,Hagbah Yearly,Bamidbor,Yes,{year} - Hagbah Bamidbar
Kibudim,Hagbah Yearly,Devorim,Yes,{year} - Hagbah Devorim
Kibudim,Psicha Yearly,Bereshis,Yes,{year} - Psicha Bereshis
Kibudim,Psicha Yearly,Shemos,Yes,{year} - Psicha Shemos
Kibudim,Psicha Yearly,Vayikra,Yes,{year} - Psicha Vayikra
Kibudim,Psicha Yearly,Bamidbar,Yes,{year} - Psicha Bamidbar
Kibudim,Psicha Yearly,Devarim,Yes,{year} - Psicha Devorim"""

def parse_csv_to_nested_json(csv_text):
    reader = csv.DictReader(io.StringIO(csv_text))
    
    # Structure: { "Type_Name": { "data": {...}, "subtypes": { "Subtype_Name": { "data": {...}, "details": [...] } } } }
    tree = {}

    for row in reader:
        type_name = row['Type'].strip()
        subtype_name = row['SubType'].strip()
        detail_name = row['Detail'].strip()
        connected_year = True if row['Connected to a Year'].lower() == 'yes' else False
        campaign_name = row['Campaign Name'].strip()

        # 1. Handle Top Level (Type)
        if type_name not in tree:
            tree[type_name] = {
                "name": type_name,
                "type": "type",
                "independentEntry": False, 
                "subtypes": {} 
            }

        # If this row has NO subtype and NO detail, it is an independent entry for the Type
        if not subtype_name and not detail_name:
            tree[type_name]["independentEntry"] = True
            tree[type_name]["campaignName"] = campaign_name
            tree[type_name]["connectedToYear"] = connected_year
            continue

        # 2. Handle Second Level (SubType)
        if subtype_name:
            if subtype_name not in tree[type_name]["subtypes"]:
                tree[type_name]["subtypes"][subtype_name] = {
                    "name": subtype_name,
                    "type": "subtype",
                    "independentEntry": False,
                    "details": []
                }
            
            # If this row has NO detail, it is an independent entry for the SubType
            if not detail_name:
                tree[type_name]["subtypes"][subtype_name]["independentEntry"] = True
                tree[type_name]["subtypes"][subtype_name]["campaignName"] = campaign_name
                tree[type_name]["subtypes"][subtype_name]["connectedToYear"] = connected_year
                continue

        # 3. Handle Third Level (Detail)
        if detail_name:
            # Details are always leaves, so they are always independent entries
            detail_obj = {
                "name": detail_name,
                "type": "detail",
                "independentEntry": True,
                "campaignName": campaign_name,
                "connectedToYear": connected_year
            }
            tree[type_name]["subtypes"][subtype_name]["details"].append(detail_obj)

    # Final pass: Convert dictionaries to lists
    final_output = []
    
    for t_name, t_data in tree.items():
        type_obj = {
            "name": t_data["name"],
            "type": t_data["type"],
            "independentEntry": t_data["independentEntry"]
        }
        
        if t_data["independentEntry"]:
            type_obj["campaignName"] = t_data.get("campaignName")
            type_obj["connectedToYear"] = t_data.get("connectedToYear")

        subtypes_list = []
        for st_name, st_data in t_data["subtypes"].items():
            subtype_obj = {
                "name": st_data["name"],
                "type": st_data["type"],
                "independentEntry": st_data["independentEntry"]
            }
            
            if st_data["independentEntry"]:
                subtype_obj["campaignName"] = st_data.get("campaignName")
                subtype_obj["connectedToYear"] = st_data.get("connectedToYear")
            
            if st_data["details"]:
                subtype_obj["details"] = st_data["details"]
                
            subtypes_list.append(subtype_obj)
            
        if subtypes_list:
            type_obj["subtypes"] = subtypes_list
            
        final_output.append(type_obj)

    return json.dumps(final_output, indent=4)

print(parse_csv_to_nested_json(csv_data))
"""Countries and capitals used by the geography decks.

193 UN member states plus Vatican City. Format per line:
ISO 3166-1 alpha-2 | English name | capital | continent | optional note shown on the answer side.
Transcontinental countries are listed where they are most commonly grouped.
"""

RAW = """
DZ|Algeria|Algiers|Africa|
AO|Angola|Luanda|Africa|
BJ|Benin|Porto-Novo|Africa|Cotonou is the seat of government and largest city.
BW|Botswana|Gaborone|Africa|
BF|Burkina Faso|Ouagadougou|Africa|
BI|Burundi|Gitega|Africa|Bujumbura was the capital until 2019.
CV|Cabo Verde|Praia|Africa|
CM|Cameroon|Yaoundé|Africa|
CF|Central African Republic|Bangui|Africa|
TD|Chad|N'Djamena|Africa|
KM|Comoros|Moroni|Africa|
CG|Republic of the Congo|Brazzaville|Africa|Not to be confused with the DR Congo (Kinshasa).
CD|DR Congo|Kinshasa|Africa|Not to be confused with the Republic of the Congo (Brazzaville).
CI|Côte d'Ivoire|Yamoussoukro|Africa|Abidjan is the largest city and economic centre.
DJ|Djibouti|Djibouti|Africa|
EG|Egypt|Cairo|Africa|
GQ|Equatorial Guinea|Malabo|Africa|
ER|Eritrea|Asmara|Africa|
SZ|Eswatini|Mbabane|Africa|Lobamba is the legislative and royal capital.
ET|Ethiopia|Addis Ababa|Africa|
GA|Gabon|Libreville|Africa|
GM|Gambia|Banjul|Africa|
GH|Ghana|Accra|Africa|
GN|Guinea|Conakry|Africa|
GW|Guinea-Bissau|Bissau|Africa|
KE|Kenya|Nairobi|Africa|
LS|Lesotho|Maseru|Africa|
LR|Liberia|Monrovia|Africa|
LY|Libya|Tripoli|Africa|
MG|Madagascar|Antananarivo|Africa|
MW|Malawi|Lilongwe|Africa|
ML|Mali|Bamako|Africa|
MR|Mauritania|Nouakchott|Africa|
MU|Mauritius|Port Louis|Africa|
MA|Morocco|Rabat|Africa|Casablanca is the largest city.
MZ|Mozambique|Maputo|Africa|
NA|Namibia|Windhoek|Africa|
NE|Niger|Niamey|Africa|
NG|Nigeria|Abuja|Africa|Lagos is the largest city; Abuja replaced it as capital in 1991.
RW|Rwanda|Kigali|Africa|
ST|São Tomé and Príncipe|São Tomé|Africa|
SN|Senegal|Dakar|Africa|
SC|Seychelles|Victoria|Africa|
SL|Sierra Leone|Freetown|Africa|
SO|Somalia|Mogadishu|Africa|
ZA|South Africa|Pretoria|Africa|Pretoria is the executive capital; Cape Town is the legislative and Bloemfontein the judicial capital.
SS|South Sudan|Juba|Africa|
SD|Sudan|Khartoum|Africa|
TZ|Tanzania|Dodoma|Africa|Dar es Salaam is the largest city.
TG|Togo|Lomé|Africa|
TN|Tunisia|Tunis|Africa|
UG|Uganda|Kampala|Africa|
ZM|Zambia|Lusaka|Africa|
ZW|Zimbabwe|Harare|Africa|
AF|Afghanistan|Kabul|Asia|
AM|Armenia|Yerevan|Asia|
AZ|Azerbaijan|Baku|Asia|
BH|Bahrain|Manama|Asia|
BD|Bangladesh|Dhaka|Asia|
BT|Bhutan|Thimphu|Asia|
BN|Brunei|Bandar Seri Begawan|Asia|
KH|Cambodia|Phnom Penh|Asia|
CN|China|Beijing|Asia|
GE|Georgia|Tbilisi|Asia|
IN|India|New Delhi|Asia|
ID|Indonesia|Jakarta|Asia|A new capital, Nusantara, is under construction.
IR|Iran|Tehran|Asia|
IQ|Iraq|Baghdad|Asia|
IL|Israel|Jerusalem|Asia|The status of Jerusalem is disputed; most embassies are in Tel Aviv.
JP|Japan|Tokyo|Asia|
JO|Jordan|Amman|Asia|
KZ|Kazakhstan|Astana|Asia|Almaty is the largest city and was the capital until 1997.
KW|Kuwait|Kuwait City|Asia|
KG|Kyrgyzstan|Bishkek|Asia|
LA|Laos|Vientiane|Asia|
LB|Lebanon|Beirut|Asia|
MY|Malaysia|Kuala Lumpur|Asia|The government sits in Putrajaya.
MV|Maldives|Malé|Asia|
MN|Mongolia|Ulaanbaatar|Asia|
MM|Myanmar|Naypyidaw|Asia|Yangon is the largest city and was the capital until 2006.
NP|Nepal|Kathmandu|Asia|
KP|North Korea|Pyongyang|Asia|
OM|Oman|Muscat|Asia|
PK|Pakistan|Islamabad|Asia|Karachi is the largest city.
PH|Philippines|Manila|Asia|
QA|Qatar|Doha|Asia|
SA|Saudi Arabia|Riyadh|Asia|
SG|Singapore|Singapore|Asia|A city-state: the capital has the same name.
KR|South Korea|Seoul|Asia|
LK|Sri Lanka|Sri Jayawardenepura Kotte|Asia|Colombo is the largest city and commercial capital.
SY|Syria|Damascus|Asia|
TJ|Tajikistan|Dushanbe|Asia|
TH|Thailand|Bangkok|Asia|
TL|Timor-Leste|Dili|Asia|
TR|Turkey|Ankara|Asia|Istanbul is the largest city.
TM|Turkmenistan|Ashgabat|Asia|
AE|United Arab Emirates|Abu Dhabi|Asia|Dubai is the largest city.
UZ|Uzbekistan|Tashkent|Asia|
VN|Vietnam|Hanoi|Asia|Ho Chi Minh City is the largest city.
YE|Yemen|Sana'a|Asia|
AL|Albania|Tirana|Europe|
AD|Andorra|Andorra la Vella|Europe|
AT|Austria|Vienna|Europe|
BY|Belarus|Minsk|Europe|
BE|Belgium|Brussels|Europe|
BA|Bosnia and Herzegovina|Sarajevo|Europe|
BG|Bulgaria|Sofia|Europe|
HR|Croatia|Zagreb|Europe|
CY|Cyprus|Nicosia|Europe|
CZ|Czechia|Prague|Europe|
DK|Denmark|Copenhagen|Europe|
EE|Estonia|Tallinn|Europe|
FI|Finland|Helsinki|Europe|
FR|France|Paris|Europe|
DE|Germany|Berlin|Europe|
GR|Greece|Athens|Europe|
HU|Hungary|Budapest|Europe|
IS|Iceland|Reykjavik|Europe|
IE|Ireland|Dublin|Europe|
IT|Italy|Rome|Europe|
LV|Latvia|Riga|Europe|
LI|Liechtenstein|Vaduz|Europe|
LT|Lithuania|Vilnius|Europe|
LU|Luxembourg|Luxembourg|Europe|A city-state-like capital with the same name as the country.
MT|Malta|Valletta|Europe|
MD|Moldova|Chisinau|Europe|
MC|Monaco|Monaco|Europe|A city-state: the capital has the same name.
ME|Montenegro|Podgorica|Europe|
NL|Netherlands|Amsterdam|Europe|The government and parliament sit in The Hague.
MK|North Macedonia|Skopje|Europe|
NO|Norway|Oslo|Europe|
PL|Poland|Warsaw|Europe|
PT|Portugal|Lisbon|Europe|
RO|Romania|Bucharest|Europe|
RU|Russia|Moscow|Europe|
SM|San Marino|San Marino|Europe|
RS|Serbia|Belgrade|Europe|
SK|Slovakia|Bratislava|Europe|
SI|Slovenia|Ljubljana|Europe|
ES|Spain|Madrid|Europe|
SE|Sweden|Stockholm|Europe|
CH|Switzerland|Bern|Europe|Switzerland has no official capital; Bern is the "federal city".
UA|Ukraine|Kyiv|Europe|
GB|United Kingdom|London|Europe|
VA|Vatican City|Vatican City|Europe|The smallest country in the world.
AG|Antigua and Barbuda|Saint John's|North America|
BS|Bahamas|Nassau|North America|
BB|Barbados|Bridgetown|North America|
BZ|Belize|Belmopan|North America|
CA|Canada|Ottawa|North America|
CR|Costa Rica|San José|North America|
CU|Cuba|Havana|North America|
DM|Dominica|Roseau|North America|
DO|Dominican Republic|Santo Domingo|North America|
SV|El Salvador|San Salvador|North America|
GD|Grenada|St. George's|North America|
GT|Guatemala|Guatemala City|North America|
HT|Haiti|Port-au-Prince|North America|
HN|Honduras|Tegucigalpa|North America|
JM|Jamaica|Kingston|North America|
MX|Mexico|Mexico City|North America|
NI|Nicaragua|Managua|North America|
PA|Panama|Panama City|North America|
KN|Saint Kitts and Nevis|Basseterre|North America|
LC|Saint Lucia|Castries|North America|
VC|Saint Vincent and the Grenadines|Kingstown|North America|
TT|Trinidad and Tobago|Port of Spain|North America|
US|United States|Washington, D.C.|North America|
AR|Argentina|Buenos Aires|South America|
BO|Bolivia|Sucre|South America|Sucre is the constitutional capital; the government sits in La Paz.
BR|Brazil|Brasília|South America|Rio de Janeiro was the capital until 1960.
CL|Chile|Santiago|South America|
CO|Colombia|Bogotá|South America|
EC|Ecuador|Quito|South America|
GY|Guyana|Georgetown|South America|
PY|Paraguay|Asunción|South America|
PE|Peru|Lima|South America|
SR|Suriname|Paramaribo|South America|
UY|Uruguay|Montevideo|South America|
VE|Venezuela|Caracas|South America|
AU|Australia|Canberra|Oceania|Sydney is the largest city.
FJ|Fiji|Suva|Oceania|
KI|Kiribati|South Tarawa|Oceania|
MH|Marshall Islands|Majuro|Oceania|
FM|Micronesia|Palikir|Oceania|
NR|Nauru|Yaren|Oceania|Nauru has no official capital; Yaren is the de facto seat of government.
NZ|New Zealand|Wellington|Oceania|Auckland is the largest city.
PW|Palau|Ngerulmud|Oceania|
PG|Papua New Guinea|Port Moresby|Oceania|
WS|Samoa|Apia|Oceania|
SB|Solomon Islands|Honiara|Oceania|
TO|Tonga|Nuku'alofa|Oceania|
TV|Tuvalu|Funafuti|Oceania|
VU|Vanuatu|Port Vila|Oceania|
"""

CONTINENTS = ["Europe", "Asia", "Africa", "North America", "South America", "Oceania"]


def flag(iso2):
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in iso2)


def load():
    rows = []
    for line in RAW.strip().splitlines():
        iso, name, capital, continent, note = line.split("|")
        rows.append(
            dict(iso=iso, name=name, capital=capital, continent=continent, note=note, flag=flag(iso))
        )
    assert len(rows) == 194, len(rows)
    assert len({r["iso"] for r in rows}) == 194
    counts = {}
    for r in rows:
        assert r["continent"] in CONTINENTS
        counts[r["continent"]] = counts.get(r["continent"], 0) + 1
    return rows


if __name__ == "__main__":
    import collections

    rows = load()
    print(collections.Counter(r["continent"] for r in rows))

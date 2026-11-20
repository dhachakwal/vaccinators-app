/// Facility -> UC map, copied from the EPI Chakwal website's
/// own `SV_FAC_UC` map (index.html, v14.29, 19 Nov 2026) — the same
/// 68-entry mapping the dashboard's Summary section uses to link a
/// Fixed facility to its UC. The Fixed tab of the Summary sheet
/// lists FACILITIES, not UCs, so My Data needs this map to show
/// "Fixed doses in MY UC" (section c). If the dashboard adds a
/// facility, add its line here too — the key is the facility name
/// normalised by [normFacilityName] (lowercase, letters/digits
/// only), exactly like the site's `svNormName`.
///
/// MY DATA PRIVACY: this map only ever turns a facility name into
/// a UC name so the service can keep the rows of the logged-in
/// vaccinator's UC and drop the rest. It never exposes another
/// UC's data — there is no UC picker anywhere in the app.
const Map<String, String> kFacilityToUc = {
    'districtheadquarterhospitalchakwal': 'CHAKWAL URBAN V',
    'mnhdhudialchakwal': 'DHUDIAL',
    'mnhcchakralchakwal': 'CHAK MALOOK',
    'mnhcdhokmusahibchakwal': 'DHERMOND',
    'mnhcjhatlajaswalchakwal': 'JASWAL',
    'mnhckhairpurchakwal': 'KHAIRPUR',
    'mnhcmainganchakwal': 'MAINGON',
    'mnhcbheenchakwal': 'BHEEN',
    'mnhcchakumrachakwal': 'CHAK UMRA',
    'mnhcdabchakwal': 'DAB',
    'mnhcdharabichakwal': 'BALKASSAR',
    'mnhcjandchakwal': 'JAND',
    'mnhcjandialfaizullahchakwal': 'CHOA GANJ ALI SHAH',
    'mnhckarialachakwal': 'KARYALA',
    'mnhckarsalchakwal': 'KARSAL',
    'mnhckhokharzairchakwal': 'KHAI',
    'mnhcmangwalchakwal': 'MANGWAL',
    'mnhcminwalchakwal': 'BALOKASSAR',
    'mnhcmulhalmughlanchakwal': 'MULHAL MUGHLAN',
    'mnhcmureedchakwal': 'MUREED',
    'mnhcnachindichakwal': 'JAND KHANZADA',
    'mnhcneelachakwal': 'WARWAL',
    'mnhcpadshahanchakwal': 'PADSHAN',
    'mnhcranjhachakwal': 'KOT CHOHDRIAN',
    'mnhcroopwalchakwal': 'KOT CHOHDRIAN',
    'mnhcsaralchakwal': 'SARAL',
    'mnhcsehgalabadchakwal': 'SAIGOLABAD',
    'mnhcshahpursayyedanchakwal': 'CHOA GANJ ALI SHAH',
    'mnhcsohawadewalianchakwal': 'JASWAL',
    'ruralhealthcenterdullahchakwal': 'DULLAH',
    'ruralhealthcentermundaychakwal': 'BAIGAL',
    'ruralhealthcenterpirphullahichakwal': 'MOGLA',
    'mnhcarachoasaidanshahchakwal': 'ARA',
    'mnhcbadshahpurchoasaidanshahchakwal': 'DALWAL',
    'mnhcdulmialchoasaidanshahchakwal': 'DULMIAL',
    'mnhclehrsultanpurchoasaidanshahchakwal': 'LEHAR SULTAN PUR',
    'mnhcratoochachoasaidanshahchakwal': 'SALOI',
    'basichealthunitbhounkallarkaharchakwal': 'BHOUN',
    'mnhcbharpurkallarkaharchakwal': 'BHERPUR',
    'mnhcmunarakallarkaharchakwal': 'MUNARA',
    'mnhcnoorpurkallarkaharchakwal': 'NURPUR',
    'mnhcsardhikallarkaharchakwal': 'BUCHAL KHURD',
    'mnhcsarkalankallarkaharchakwal': 'NURPUR',
    'ruralhealthcenterbuchalkalankallarkaharchakwal': 'BUCHAL KALAN',
    'traumacentertehsilheadquarterhospitalkallarkaharchakwal': 'KALLAR KAHAR',
    'governmentcityhospitaltalagangchakwal': 'TALAGANG URBAN I',
    'mnhcbudhialtalagangchakwal': 'BHUDIAL',
    'mnhcchinjitalagangchakwal': 'BHILOMAR',
    'mnhcdhaulartalagangchakwal': 'DHOULAR',
    'mnhcdhermondtalagangchakwal': 'DHERMOND',
    'mnhcdhokhumtalagangchakwal': 'PIRA FATEHIAL',
    'mnhcghooltalagangchakwal': 'LAWA RURAL',
    'mnhcjasialtalagangchakwal': 'JASIAL',
    'mnhckotgullahtalagangchakwal': 'KOT GULLAH',
    'mnhckotsarangtalagangchakwal': 'KOT SARANG',
    'mnhclaititalagangchakwal': 'LETTI',
    'mnhcmultankhurdtalagangchakwal': 'MULTAN KHURD',
    'mnhcnakkakahuttalagangchakwal': 'NAKKA KAHUT',
    'mnhcpachnandtalagangchakwal': 'PICHNAND',
    'mnhcpatwalitalagangchakwal': 'BHUDIAL',
    'mnhcpirafatialtalagangchakwal': 'PIRA FATEHIAL',
    'mnhcsukkatalagangchakwal': 'KOT QAZI',
    'mnhctehitalagangchakwal': 'TEHI',
    'mnhcthoamehramkhantalagangchakwal': 'THOA MEHRAM KHAN I',
    'mnhcwanhartalagangchakwal': 'BIDHAR',
    'mnhcbhillomartalagangchakwal': 'BHILOMAR',
    'ruralhealthcenterkotqazitalagangchakwal': 'KOT QAZI',
    'tehsilheadquarterhospitaltalagangchakwal': 'TALAGANG URBAN II',
};

/// Same as the site's svNormName: lowercase, keep letters/digits.
String normFacilityName(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

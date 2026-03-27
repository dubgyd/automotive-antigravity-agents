# VDA 702 Situation Catalog

Automated extraction from sheet 'Sheet1'.

| Unnamed: 0 | Unnamed: 1 | Unnamed: 2 | Unnamed: 3 | Unnamed: 4 | Unnamed: 5 | Unnamed: 6 | Unnamed: 7 | Unnamed: 8 | Unnamed: 9 | Unnamed: 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| nan | nan | nan | nan | nan | nan | nan | nan | nan | nan | nan |
| nan | nan | Situation catalog | nan | nan | nan | nan | E-rating<br>[Time range] | E-rating<br>[Frequency range] | nan | nan |
| nan | nan | ID | Main structure | Subgroup | Evaluated situations | nan | E | E | nan | Additional information |
| nan | nan | Basic situations DRIVING | nan | nan | nan | nan | nan | nan | nan | nan |
| nan | nan | FU | Environmental impact | Viewing conditions | nan | nan | nan | nan | nan | nan |
| nan | nan | FU010 | Environmental impact | Viewing conditions | Driving in poor visibility (fog / glare ...) with visibility below 50m | nan | E2 | E2 | nan | nan |
| nan | nan | FU020 | Environmental impact | Viewing conditions | Driving in the dark without residual light (no road lighting, no moon, no lights by other traffic)<br>-> The roads edge not recognizable | nan | E3 | —— | nan | Time range:<br>Very conservative for densely populated areas (EU). |
| nan | nan | FU030 | Environmental impact | Viewing conditions | Driving in the dark with residual light (e.g., street lights, other traffic lights, twilight)<br>-> roadside recognizable | nan | E4 | E4 | nan | Normal case for professional traffic in "dark" season |
| nan | nan | FP | Vehicle occupant | Passengers | nan | nan | nan | nan | nan | nan |
| nan | nan | FP010 | Vehicle occupant | Passengers | 1 rider | nan | E4 | E4 | nan | From OEM customer data (field trial Germany) |
| nan | nan | FP020 | Vehicle occupant | Passengers | 2 rider | nan | E4 | E4 | nan | From OEM customer data (field trial Germany) |
| nan | nan | FP030 | Vehicle occupant | Passengers | >2 rider | nan | E3 | E3 | nan | From OEM customer data (field trial Germany) |
| nan | nan | FS | Road condition | Coefficients of friction, spurries, incline, unevenness | nan | nan | nan | nan | nan | nan |
| nan | nan | FS010 | Road condition | Coefficients of friction | Driving on normal friction | nan | E4 | —— | nan | nan |
| nan | nan | FS020 | Road condition | Coefficients of friction | Driving on a reduced coefficient of friction in the range μ <0.8 +/- 0.1 (e.g., strong wetness, bobbin, rollsplit, etc.) | nan | E3 | —— | nan | nan |
| nan | nan | FS030 | Road condition | Coefficients of friction | Driving on low friction in the range μ <0.5 +/- 0.1 (e.g., snow, ice ...) | nan | E2 | —— | nan | nan |
| nan | nan | FS040 | Road condition | Coefficients of friction | Driving on roads with μ-split. (Deviation li / re by delta-μ> 0.3, for example, change<br>Dry / wet / ice) | nan | E1 | E2 | nan | Very short time. Note FS010, FS020, FS030 |
| nan | nan | FS050 | Road condition | Coefficients of friction | Driving on μ-hop roads (transition with delta-μ> 0.3, for example, alternating dry /<br>Wet / ice) | nan | E1 | E3 | nan | Very short time. Note FS010, FS020, FS030 |
| nan | nan | FS090 | Road condition | Roadway unevenness | Ride with considerable vertical excitation on the wheel (for example, sloop, ground wave, cobblestone, speed bumper, curb ...) | nan | E3 | E3 | nan | Vertical excitation by slouch hole: approx. 10 m / s2; Depending on the degree of excitation, E2 |
| nan | nan | FB | Drive dynamic condition | Longitudinal and transverse dynamics | nan | nan | nan | nan | nan | nan |
| nan | nan | FB010 | Driving condition | speed | Driving at speeds above 130km / h | nan | E3 | —— | nan | Expert derivation from OEM internal customer data <br>(worldwide and averaged over vehicles) |
| nan | nan | FB020 | Driving condition | speed | Driving with speed over 180km / h | nan | E2 | —— | nan | Expert derivation from OEM internal customer data <br>(worldwide and averaged over vehicles) |
| nan | nan | FB030 | Driving condition | speed | Driving at speeds above 200 km / h | nan | E1 | —— | nan | Expert derivation from OEM internal customer data <br>(worldwide and averaged over vehicles) |
| nan | nan | FB040 | Driving condition | speed | Slow driving / starting operation (0 <x <12 km / h) | nan | E3 | E4 | nan | OEM customer data: 2% of the time at 0-10km / h<br>OEM customer data: <3% of the time at 0-15km / h<br>Customer data: <10% at 0 <x <10km / h |
| nan | nan | FB090 | Driving condition | Accelerate | Driving with normal longitudinal acceleration (<2m / s2) | nan | E4 | E4 | nan | Expert derivations from OEM internal customer data |
| nan | nan | FB100 | Driving condition | Accelerate | Driving with longitudinal acceleration over 2 m / s ^ 2 | nan | E3 | E4 | nan | Expert derivations from OEM internal customer data |
| nan | nan | FB110 | Driving condition | Accelerate | Driving with longitudinal acceleration over 4 m / s ^ 2 | nan | E2 | E3 | nan | Also includes starting with maximum acceleration (also: race start); Conservative assessment. Only at full load acceleration for a few seconds.<br>(E.g., 0-100km / h in 8s) |
| nan | nan | FB120 | Driving condition | Decelerate | Driving with normal deceleration (<4m / s ^ 2) | nan | E4 | E4 | nan | Expert derivations from OEM internal customer data |
| nan | nan | FB130 | Driving condition | Decelerate | Drive with deceleration over 4 m / s ^ 2 | nan | E2 | E3 | nan | Expert derivations from OEM internal customer data |
| nan | nan | FB140 | Driving condition | Decelerate | Driving with deceleration over 6 m / s ^ 2<br>(E.g., dangers, ABS) | nan | E1 | E2 | nan | Expert derivations from OEM internal customer data |
| nan | nan | FB150 | Driving condition | Other maneuvers | Running a lane change<br>(Duration in which the vehicle is not completely on Of a track) | nan | E3 | E4 | nan | Change from one lane to another, also on AB or on multi-lane roads (e.g., in front of crossroads)<br>Expert estimate: approx. 10 turns per second. -> 5,5 h / a |
| nan | nan | FB160 | Driving condition | Other maneuvers | Reversing (incl. Shunting) | nan | E2 | E4 | nan | Expert derivation from OEM internal customer data |
| nan | nan | FB170 | Driving condition | Other maneuvers | Vehicle performs overtaking maneuvers<br>(Only overtaking with lane change on Counter-track) | nan | E2 | E3 | nan | Time range:<br>Conservative expert assessment:<br>Duration: <10s (from ADAC dossier)<br>Number: << 1000 p.a. -> << 4h / a<br>Frequency range:<br>Expert assessment:<br>Comes only with every 10th journey before (not city, not highway ...) |
| nan | nan | FF | Drivers driving | shifts, blinking | nan | nan | nan | nan | nan | nan |
| nan | nan | FF010 | Drivers driving | shifts | Drivers perform change of gear | nan | E3 | E4 | nan | OEM internal customer data <br>Handset: 6,25h / a |
| nan | nan | FF020 | Drivers driving | Direction indication | Driving me active turn signal (exclusive standing) | nan | E3 | E4 | nan | Expert assessment:<br><144s per trip |
| nan | nan | FF030 | Driver's Activities Driving -> Other | belt | Driver straps (from opening the belt buckle to the belt no longer<br>Before the body) | nan | E2 | E4 | nan | Expert assessment<br><7s per trip |
| nan | nan | FF040 | Driver's Activities Driving -> Other | belt | Driver straps on (from grabbing the belt until snapping into<br>Belt buckle) | nan | E2 | E4 | nan | Expert assessment<br><7s per trip |
| nan | nan | FV | Traffic situations ride | Parking,<br>Holding operations,<br>Crossing situations | nan | nan | nan | nan | nan | nan |
| nan | nan | FV010 | Traffic situations ride | Parking | In and out Parking | nan | E3 | E4 | nan | nan |
| nan | nan | FV020 | Traffic situations ride | Parking | In and out in the longitudinal direction<br>(Unloading: from the first vehicle movement to vehicle complete in the lane, including waiting times, if applicable) | nan | E2 | E3 | nan | Time range:<br>Expert Estimation: e.g. For 1min every 10th journey<br>-> << 4h / a<br>Frequency range:<br>Expert Estimation: Only a small part of the<br>Parking places in the longitudinal direction |
| nan | nan | FV030 | Traffic situations ride | Parking | In and out transversal direction<br>(Parking: From first vehicle movement to vehicle.<br>Completely on lane. Incl. Waiting times, if applicable) | nan | E3 | E4 | nan | Expert Estimation: At almost every ride. (E.g. 1min for on and off parking |
| nan | nan | FV040 | Traffic situations ride | Holding operations | Holding on the mountain / on a hill with inclinations between 2% and 8% | nan | E3 | E3 | nan | nan |
| nan | nan | FV050 | Traffic situations ride | Holding operations | Holding on the mountain / on a hill with inclinations> 8% | nan | E2 | E2 | nan | nan |
| nan | nan | FV060 | Traffic situations ride | Holding operations | Keeping on the road (e.g., before stop sign, traffic light, zebra ...) | nan | E4 | E4 | nan | Holding means here: v = 0km / h and KL 15 on |
| nan | nan | FV070 | Traffic situations ride | Holding operations | Keeping on the road (e.g., before stop sign, traffic light, zebra ...) standing first (without front vehicle) | nan | E3 | E4 | nan | Holding means here: v = 0km / h and KL 15 on |
| nan | nan | FV080 | Traffic situations ride | Crossing situations | Driving across the intersection, i. Fzg. Kreuzt Route of other road users (with / without traffic lights, zebras, cycle path ...) | nan | E3 | E4 | nan | Expert assessment:<br><< 10% of the route consists of junctions<br>(Crossing area approx. 25m) |
| nan | nan | FV090 | Traffic situations ride | Crossing situations | Turn off (leaving the own lane to the vehicle completely on the crossroad) | nan | E3 | E4 | nan | Appraisal:<br>With approx. 20 turn-off procedures per trip á 2s<br>-> << 40h / a |
| nan | nan | FV100 | Traffic situations ride | Traffic situation | Free ride | nan | E4 | E4 | nan | nan |
| nan | nan | FV110 | Traffic situations ride | Traffic situation | Follow-up normal distance | nan | E4 | E4 | nan | nan |
| nan | nan | FV130 | Traffic situations ride | Traffic situation | Driving with traffic in sight | nan | E4 | E4 | nan | nan |
| nan | nan | FV140 | Traffic situations ride | Traffic situation | Driving with parking cars on the roadside | nan | E4 | E4 | nan | nan |
| nan | nan | FX | Special Situations Movement | Loading, tires, towing | nan | nan | nan | nan | nan | nan |
| nan | nan | FX010 | Special Situations Movement | loading | Driving with trailer | nan | E2 | E2 | nan | nan |
| nan | nan | FX020 | Special Situations Movement | loading | Driving with loaded roof rack (e.g., box, wheels) | nan | E2 | E2 | nan | nan |
| nan | nan | FX030 | Special Situations Movement | loading | Loading of exclusive occupants up to max. 100kg | nan | E4 | E4 | nan | Expert derivation from OEM internal customer data |
| nan | nan | FX040 | Special Situations Movement | loading | Loading of exclusive occupants> 100 kg | nan | E3 | E3 | nan | Expert derivation from OEM internal customer data |
| nan | nan | FX050 | Special Situations Movement | tire | Driving with emergency wheel | nan | E1 | E1 | nan | nan |
| nan | nan | FX060 | Special Situations Movement | tire | Driving with snow chains | nan | E1 | E1 | nan | nan |
| nan | nan | FX070 | Special Situations Movement | Towing operations | Vehicle towed other cars | nan | E1 | E1 | nan | nan |
| nan | nan | FX080 | Special Situations Movement | Towing operations | Vehicle is towed<br>(E.g., on axle, from other car ...) | nan | E1 | E1 | nan | nan |
| nan | nan | FO | Location | Street type, street environment<br>(Construction site, tunnel) | nan | nan | nan | nan | nan | nan |
| nan | nan | FO010 | Location | Highway | Driving on highway | nan | E4 | E3 | nan | nan |
| nan | nan | FO020 | Location | Highway | Drive on highway entrance | nan | E2 | E3 | nan | Expert Estimation: Some on each ride. Other than never;<br>-> On average, less than every 10th ride |
| nan | nan | FO030 | Location | Highway | Drive on highway exit | nan | E2 | E3 | nan | Expert Estimation: Some on each ride. Other than never;<br>-> On average, less than every 10th ride |
| nan | nan | FO040 | Location | Country road | Driving on country road | nan | E4 | E4 | nan | nan |
| nan | nan | FO050 | Location | city | Driving in the city | nan | E4 | E4 | nan | nan |
| nan | nan | FO060 | Location | Pass road | Drive on the pass road | nan | E2 | E2 | nan | nan |
| nan | nan | FO070 | Location | Traffic-free area | traffic-free area<br>(Also: Play street) | nan | E2 | E3 | nan | Environment research:<br>For example, in Freiburg there are currently 177 such areas, Düsseldorf about 100<br>-> On average 1 time per 10 trips -> one step<br>Lower than driving in Tempo-30 zone (FO080) |
| nan | nan | FO080 | Location | Tempo 30 zone | Drive in tempo-30 zone | nan | E3 | E4 | nan | Environmental research<br>Residential areas are covered over a wide area with a speed of 30 zones.<br>-> Min. Every 10th lives in a tempo 30 zone<br>-> passage approximately 2 times a day -> E4 (Freq.)<br>-> Duration per trip <2min -> E3 (time) |
| nan | nan | FO090 | Location | Building site | Driving in construction area (motorway) with structural separation | nan | E3 | —— | nan | Expert assessment<br>From ACE-Pressmittelung from 17.8.2011: Construction sites in D cover about 6-7% of the AB distances |
| nan | nan | FO100 | Location | Building site | Driving in the construction area (motorway) without structural separation | nan | E2 | —— | nan | nan |
| nan | nan | FO110 | Location | tunnel | Driving through tunnel | nan | E2 | E3 | nan | Assessment: Tunnel distance to total route in Central Europe is clearly smaller 1% |
| nan | nan | FO120 | Location | Railroad Crossing | Drive over railway crossing | nan | E1 | E3 | nan | nan |
| nan | nan | Basic Conditions | nan | nan | nan | nan | nan | nan | nan | nan |
| nan | nan | SP | Vehicle occupant | Drivers, passengers | nan | nan | nan | nan | nan | nan |
| nan | nan | SP010 | Vehicle occupant | driver | Stand with driver in vehicle and kl.15 off | nan | E3 | E4 | nan | E.g. Waiting for rider, short stop on AB resting place<br>Etc. conceptually corresponds to "Kl.15 from" e.g. "Ignition off", "driving out"; |
| nan | nan | SP020 | Vehicle occupant | driver | Standing with driver not in the vehicle (including parking) | nan | E4 | E4 | nan | nan |
| nan | nan | SP030 | Vehicle occupant | Passengers | Stand without driver, but with passengers in the vehicle | nan | E3 | E4 | nan | E.g. Short stop on AB service area etc. |
| nan | nan | SB | Operating condition | Ignition / electrical wiring,<br>Locking | nan | nan | nan | nan | nan | nan |
| nan | nan | SB010 | Operating condition | Ignition on / off | Vehicle is standing with engine running | nan | E4 | E4 | nan | Analogous holding situations during driving |
| nan | nan | SB020 | Operating condition | Ignition on / off | Vehicle with active driving readiness (e-car) | nan | E4 | E4 | nan | Analogous holding situations during driving |
| nan | nan | SB030 | Operating condition | Ignition on / off | Long-term parking> 2 days | nan | E4 | —— | nan | Relevant e.g. With increased quiescent current or active. Electrical consumers; |
| nan | nan | SF | Driver Actions Stand | Loading / filling, loading / unloading, loading / unloading | nan | nan | nan | nan | nan | nan |
| nan | nan | SF010 | Driver Actions Stand | Get in / out | Driver goes into vehicle on / off | nan | —— | E4 | nan | At the beginning and end of each trip |
| nan | nan | SF020 | Driver Actions Stand | Release the parking brake | Driver triggers parking brake | nan | —— | E4 | nan | nan |
| nan | nan | SF030 | Driver Actions Stand | Ignition on / off | Driver starts the vehicle | nan | —— | E4 | nan | nan |
| nan | nan | SF040 | Driver Actions Stand | Loading / unloading trunk | Vehicle trunk is loaded or unloaded<br>(Person is behind open suitcase) | nan | E2 | E4 | nan | Usually takes only a few seconds (insert jacket / pocket) |
| nan | nan | SF050 | Driver Actions Stand | Fill the vehicle | Vehicle is being refueled | nan | E2 | E3 | nan | Time range:<br>Approx. 5min refueling per 500km (10h)<br>Frequency range:<br>20tkm p.a. -><br>40x refueling p.a. |
| nan | nan | SF060 | Driver Actions Stand | Charging of the vehicle | E-vehicle is charged via charging cable (plug-in) | nan | E4 | E4 | nan | nan |
| nan | nan | SS | Service activities | Maintenance, repair | nan | nan | nan | nan | nan | nan |
| nan | nan | SS010 | Service activities | Check / refill liquids | nan | nan | nan | nan | nan | nan |
| nan | nan | SS020 | Service activities | Vehicle on lifting platform / car lift … | nan | nan | nan | nan | nan | nan |
| nan | nan | SX | Special Situations Stand | Breakdown, crash, external start | nan | nan | nan | nan | nan | nan |
| nan | nan | SX010 | Special Situations Stand | Breakdown | Vehicle is stopped due to a breakdown | nan | —— | E1 | nan | nan |
| nan | nan | SX020 | Special Situations Stand | Crash | Vehicle suffers accident | nan | —— | E1 | nan | nan |
| nan | nan | SX030 | Special Situations Stand | External start | Vehicle is started externally | nan | E1 | E1 | nan | Bridging until generator is running |
| nan | nan | SO | Location | Roadside, Parking, Other | nan | nan | nan | nan | nan | nan |
| nan | nan | SO010 | Location | Parking / garage / garage | Parking in the car park | nan | E4 | E4 | nan | nan |
| nan | nan | SO020 | Location | Parking / garage / garage | Parking in garage | nan | E4 | E4 | nan | nan |
| nan | nan | SO030 | Location | Roads edge city | Parking on the street side (city) | nan | E4 | E4 | nan | Not on parking, but still on the street; |
| nan | nan | SO040 | Location | Motorway freeway | Vehicle is parked or parked at the roadside or street strip (motorway) | nan | E1 | E1 | nan | Time range:<br>Stop is kept as short as possible<br>Frequency range:<br>On average <1x p.a. |
| nan | nan | Other basic situations | nan | nan | nan | nan | nan | nan | nan | nan |
| nan | nan | XP | Endangered person | Persons in the danger area | nan | nan | nan | nan | nan | nan |
| nan | nan | XP010 | Endangered person | Persons in the danger area | <br>Persons in danger (about 1 vehicle length)<br>Before / behind / parked vehicle | nan | E3 | E4 | nan | Basissituation is usually in combination with other boundary conditions to use what a<br>Reduction of the E value allows:<br>Example 1: Start in the wrong direction of travel<br>A) Person at start-up moment (<2m) behind the car -> several times a year: E2 (Freq.).<br>B) Person in starting torque in the range up to 5m behind the car -> several times a month: E3 (Freq.)<br>Example 2: Parking and marshalling situations<br>A) Person during maneuvering / parking in the immediate danger area (in the driving hose with <2m distance): E2<br>B) Person during maneuvering / parking in the non-immediate danger area (in the hose with> 2m clearance): E3 |
| nan | nan | XP020 | Endangered person | Persons in the vehicle | Person holding body part from the side or roof window | nan | E2 | E3 | nan | Time range:<br><100x p.a. for each<br><2min -> <4h / a<br>(E.g. toll station, ticket machine ...) |
| nan | nan | XP030 | Endangered person | Misconduct | People (also: children) on the vehicle<br>(Bonnet, roof ...) | nan | E1 | E1 | nan | nan |
| nan | nan | XW | To wash | Washing machine | nan | nan | nan | nan | nan | nan |
| nan | nan | XW010 | To wash | Washing machine | Vehicle is in the washing machine<br>(Also: Waschbox, Handwäsche ...) | nan | E2 | E3 | nan | Time range:<br>For example, 1x p. Week for 4min<br>Frequency range:<br>Up to 100x p.a. At Fuhrparkfzg. / Private i.d.R. Much rarer |
| nan | nan | XT | Vehicle transport | Ship, train, truck | nan | nan | nan | nan | nan | nan |
| nan | nan | XT010 | Vehicle transport | Transport in customer service | Vehicle is transported<br>(Ship / ferry, train, truck) | nan | E2 | E1 | nan | nan |
| nan | nan | XK | body | Sunroof, doors, windows | nan | nan | nan | nan | nan | nan |
| nan | nan | XK010 | body | Sunroof, doors, windows | Open / close window or sunroof | nan | E2 | E3 | nan | nan |
| nan | nan | XK020 | body | Sunroof, doors, windows | Locking / unlocking of the vehicle in standing position | nan | —— | E4 | nan | nan |
| nan | nan | XK030 | body | Sunroof, doors, windows | Driving with open top (convertible only) | nan | E3 | E3 | nan | nan |
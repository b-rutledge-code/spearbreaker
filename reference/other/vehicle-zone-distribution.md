# Vehicle Zone Distribution Reference

Complete list of all vehicle spawn zones and their default vehicle distributions in Project Zomboid Build 42.

## How It Works

```lua
VehicleZoneDistribution.ZONE_NAME.vehicles["Base.VehicleName"] = {index = -1, spawnChance = PERCENT}
```

- `spawnChance` is a weighted percentage (doesn't need to sum to 100)
- `index = -1` means random skin/variant

## All Zones

### General Parking Zones

#### parkingstall
General parking lots - most common spawn location.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 20% |
| Base.SmallCar | 15% |
| Base.SmallCar02 | 15% |
| Base.CarTaxi | 5% |
| Base.CarTaxi2 | 5% |
| Base.PickUpTruck | 5% |
| Base.PickUpVan | 5% |
| Base.CarStationWagon | 5% |
| Base.CarStationWagon2 | 5% |
| Base.VanSeats | 5% |
| Base.Van | 5% |
| Base.StepVan | 5% |
| Base.ModernCar | 3% |
| Base.ModernCar02 | 2% |
| **Base.DumpTruck** | **1%** |

#### medium
Medium density residential/commercial zones.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 30% |
| Base.CarStationWagon | 8% |
| Base.CarStationWagon2 | 8% |
| Base.PickUpTruck | 5% |
| Base.PickUpVan | 5% |
| Base.VanSeats | 5% |
| Base.Van | 5% |
| Base.StepVan | 5% |
| Base.SUV | 5% |
| Base.OffRoad | 5% |
| Base.ModernCar | 5% |
| Base.ModernCar02 | 5% |
| Base.CarLuxury | 4% |
| **Base.DumpTruck** | **1%** |

#### good
Upscale residential areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.ModernCar | 20% |
| Base.ModernCar02 | 20% |
| Base.SUV | 20% |
| Base.OffRoad | 20% |
| Base.CarLuxury | 10% |
| Base.SportsCar | 10% |

#### bad
Poor/run-down areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 25% |
| Base.SmallCar | 27% |
| Base.SmallCar02 | 27% |
| Base.CarStationWagon | 5% |
| Base.CarStationWagon2 | 5% |
| Base.StepVan | 5% |
| Base.Van | 4% |
| Base.PickUpTruck_Camo | 1% |
| Base.PickUpVan_Camo | 1% |

#### trailerpark
Trailer parks - older/cheaper vehicles.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 25% |
| Base.SmallCar | 29% |
| Base.SmallCar02 | 29% |
| Base.CarStationWagon | 5% |
| Base.CarStationWagon2 | 5% |
| Base.StepVan | 5% |
| Base.PickUpTruck_Camo | 1% |
| Base.PickUpVan_Camo | 1% |

### Economic Status Zones

#### luxuryDealership
Car dealerships with premium vehicles.
| Vehicle | Spawn % |
|---------|---------|
| Base.ModernCar | 20% |
| Base.ModernCar02 | 20% |
| Base.SUV | 20% |
| Base.OffRoad | 20% |
| Base.CarLuxury | 10% |
| Base.SportsCar | 10% |

#### sport
Sports car locations.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarLuxury | 50% |
| Base.SportsCar | 50% |

#### professional
Office/professional areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.ModernCar | 20% |
| Base.ModernCar02 | 20% |
| Base.CarNormal | 20% |
| Base.CarLuxury | 20% |
| Base.SUV | 20% |

#### middleClass
Middle-class residential.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 20% |
| Base.SmallCar | 20% |
| Base.SmallCar02 | 20% |
| Base.CarStationWagon | 10% |
| Base.CarStationWagon2 | 10% |

#### struggling
Low-income areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 20% |
| Base.SmallCar | 40% |
| Base.SmallCar02 | 40% |

### Industrial/Work Zones

#### junkyard
Scrapyards and junkyards.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 18% |
| Base.SmallCar | 15% |
| Base.SmallCar02 | 15% |
| Base.CarTaxi | 5% |
| Base.CarTaxi2 | 5% |
| Base.PickUpTruck | 5% |
| Base.PickUpVan | 5% |
| Base.CarStationWagon | 5% |
| Base.CarStationWagon2 | 5% |
| Base.VanSeats | 5% |
| Base.Van | 5% |
| Base.StepVan | 5% |
| Base.ModernCar | 3% |
| Base.ModernCar02 | 2% |
| Base.PickUpTruck_Camo | 1% |
| Base.PickUpVan_Camo | 1% |
| **Base.DumpTruck** | **5%** |

#### mccoy
McCoy Logging Company locations.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanMccoy | 33% |
| Base.PickUpTruckMccoy | 33% |
| Base.VanMccoy | 33% |
| **Base.DumpTruck** | **10%** |

#### trades
Construction and trade work sites.
| Vehicle | Spawn % |
|---------|---------|
| Base.Van | 20% |
| Base.StepVan | 20% |
| Base.PickUpTruck | 20% |
| Base.PickUpVan | 20% |
| Base.CarStationWagon2 | 20% |
| **Base.DumpTruck** | **20%** |

#### farm
Agricultural areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpTruck | 14% |
| Base.PickUpVan | 14% |
| Base.Trailer | 10% |
| Base.TrailerCover | 10% |
| Base.Trailer_Livestock | 50% |
| Base.PickUpTruck_Camo | 1% |
| Base.PickUpVan_Camo | 1% |
| **Base.DumpTruck** | **7%** |

#### carpenter
Carpenter/woodworking businesses.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanLightsCarpenter | 50% |
| Base.VanCarpenter | 50% |

#### delivery
Delivery service areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.Van | 20% |
| Base.StepVan | 20% |

### Traffic Zones

#### trafficjamw / trafficjame / trafficjamn / trafficjams
Traffic jam zones (directional: west/east/north/south).
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 20% |
| Base.SmallCar | 15% |
| Base.SmallCar02 | 15% |
| Base.CarTaxi | 5% |
| Base.CarTaxi2 | 5% |
| Base.PickUpTruck | 5% |
| Base.PickUpVan | 5% |
| Base.CarStationWagon | 5% |
| Base.CarStationWagon2 | 5% |
| Base.VanSeats | 5% |
| Base.Van | 5% |
| Base.StepVan | 5% |
| Base.ModernCar | 3% |
| Base.ModernCar02 | 2% |

#### evacuee
Evacuation routes.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormal | 25% |
| Base.CarStationWagon | 25% |
| Base.CarStationWagon2 | 25% |
| Base.SUV | 25% |

### Emergency Services

#### police
Police stations.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanLightsPolice | 35% |
| Base.CarLightsPolice | 60% |
| Base.VanSeats_Prison | 5% |

#### prison
Prisons.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanLightsPolice | 20% |
| Base.CarLightsPolice | 30% |
| Base.VanSeats_Prison | 50% |

#### fire
Fire stations.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanLightsFire | 50% |
| Base.PickUpTruckLightsFire | 50% |

#### ambulance
Hospitals/medical facilities.
| Vehicle | Spawn % |
|---------|---------|
| Base.VanAmbulance | 100% |

#### ranger
Ranger stations.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarLightsRanger | 50% |
| Base.PickUpVanLightsRanger | 25% |
| PickUpTruckLightsRanger | 25% |

### Business/Commercial Zones

#### business / business2 / business3 / ... / business12
Generic business parking - has ~60 different service/delivery vehicles at 1-4% each. Too many to list. Includes:
- Builder/carpenter vans
- Mail/delivery vans
- Food/beverage delivery
- Service vehicles (plumber, electrician, etc.)

### Specialty Zones

#### fossoil
Gas stations.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpVanLightsFossoil | 33% |
| Base.PickUpTruckLightsFossoil | 33% |
| Base.VanFossoil | 34% |

#### postal
Post offices.
| Vehicle | Spawn % |
|---------|---------|
| Base.StepVanMail | 50% |
| Base.VanMail | 50% |

#### spiffo
Spiffo's restaurant locations.
| Vehicle | Spawn % |
|---------|---------|
| Base.VanSpiffo | 80% |
| Base.TrailerAdvert | 20% |

#### radio
Radio stations.
| Vehicle | Spawn % |
|---------|---------|
| Base.VanRadio | 80% |
| Base.TrailerAdvert | 20% |

#### advertising
Advertising locations.
| Vehicle | Spawn % |
|---------|---------|
| Base.TrailerAdvert | 100% |

#### airportshuttle
Airport shuttle parking.
| Vehicle | Spawn % |
|---------|---------|
| Base.VanSeatsAirportShuttle | 80% |
| Base.CarTaxi | 10% |
| Base.CarTaxi2 | 10% |

#### airportservice
Airport service areas.
| Vehicle | Spawn % |
|---------|---------|
| Base.PickUpTruckLightsAirport | 20% |
| Base.PickUpTruckLightsAirportSecurity | 20% |
| Base.StepVanAirportCatering | 20% |
| Base.VanSeatsAirportShuttle | 20% |
| Base.VanMeltingPointMetal | 10% |
| Base.VanMobileMechanics | 10% |

### Burnt Vehicle Zones

#### normalburnt
Burnt civilian vehicles.
| Vehicle | Spawn % |
|---------|---------|
| Base.CarNormalBurnt | 25% |
| Base.SmallCarBurnt | 10% |
| Base.SmallCar02Burnt | 10% |
| Base.OffRoadBurnt | 5% |
| Base.PickupBurnt | 5% |
| Base.PickUpVanBurnt | 5% |
| Base.SportsCarBurnt | 5% |
| Base.VanSeatsBurnt | 5% |
| Base.VanBurnt | 5% |
| Base.ModernCarBurnt | 5% |
| Base.ModernCar02Burnt | 5% |
| Base.SUVBurnt | 5% |
| Base.TaxiBurnt | 5% |
| Base.LuxuryCarBurnt | 5% |

#### specialburnt
Burnt emergency/special vehicles.
| Vehicle | Spawn % |
|---------|---------|
| Base.NormalCarBurntPolice | 20% |
| Base.AmbulanceBurnt | 20% |
| Base.VanRadioBurnt | 20% |
| Base.PickupSpecialBurnt | 20% |
| Base.PickUpVanLightsBurnt | 20% |

#### racecar
Race track locations.
| Vehicle | Spawn % |
|---------|---------|
| Base.RaceCarBurnt | 100% |

### Brand-Specific Zones

| Zone | Vehicle | Spawn % |
|------|---------|---------|
| scarlet | Base.StepVan_Scarlet | 100% |
| massgenfac | Base.Van_MassGenFac | 100% |
| transit | Base.Van_Transit | 100% |
| network3 | Base.VanRadio_3N | 100% |
| kyheralds | Base.StepVan_Heralds | 100% |
| lectromax | Base.Van_LectroMax | 100% |
| knoxdisti | Base.Van_KnoxDisti | 100% |

---

## DumpTruck Mod Current Distribution

| Zone | Spawn % | Notes |
|------|---------|-------|
| parkingstall | 1% | General parking |
| medium | 1% | Medium density |
| junkyard | 5% | Scrapyards |
| farm | 7% | Agricultural |
| mccoy | 10% | McCoy Logging |
| trades | 20% | Construction sites |

## Zones NOT Currently Using (Potential Additions)

| Zone | Why it might fit |
|------|------------------|
| trafficjamw/e/n/s | Could be stuck in traffic |
| business1-12 | Construction/masonry businesses |
| carpenter | Heavy equipment |
| normalburnt | Burnt dump truck variant? |

---

*Generated from Build 42 runtime dump on 2026-01-22*

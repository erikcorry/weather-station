import certificate-roots
import encoding.json
import encoding.url
import fixed-point show FixedPoint
import http
import net
import solar-position show *

import .api-key

LONGITUDE ::= 10.1337
LATITUDE ::= 56.09

main:
  certificate-roots.install-common-trusted-roots
  network := net.open
  client := http.Client.tls network
  headers := http.Headers
  headers.add "X-Gravitee-Api-Key" API-KEY
  parameters := {
    "bbox": "$(LONGITUDE - 0.1),$(LATITUDE - 0.1),$(LONGITUDE + 0.1),$(LATITUDE + 0.1)",
    "limit": "30",
  }
  response/http.Response := client.get
      --host="dmigw.govcloud.dk"
      --path="/v2/metObs/collections/observation/items"
      --query_parameters=parameters
      --headers=headers
  data := json.decode-stream response.body
  sun := solar-position Time.now LONGITUDE LATITUDE
  dry-temp/float? := null
  cloud-cover/float? := null
  wind-speed/float? := null
  wind-direction/float? := null
  precipitation/float? := null
  data["features"].do: | feature |
    properties := feature["properties"]
    parameter-id := properties["parameterId"]
    if parameter-id == "temp_dry":
      dry-temp = properties["value"]
    else if parameter-id == "cloud_cover":
      cloud-cover = properties["value"]
    else if parameter-id == "wind_speed" or parameter-id == "wind_speed_past1h" or parameter-id == "wind_speed_past10min":
      wind-speed = properties["value"]
    else if parameter-id == "wind_dir":
      wind-direction = properties["value"]
    else if parameter-id == "precip_past1h" or parameter-id == "precip_past10min":
      precipitation = properties["value"]
    print "Parameter ID: $parameter-id: $properties["value"]"
  icon := ""
  if cloud-cover:
    if cloud-cover > 99:
      icon = "cloud"
  if dry-temp: print "Dry temperature: $(round dry-temp)°C"
  if cloud-cover: print "Cloud cover: $cloud-cover%"
  if wind-speed: print "Wind speed: $(round wind-speed)m/s"
  if precipitation: print "Precipitation: $(round precipitation)mm"
  if wind-direction:
    if wind-direction != 0.0:
      print "Wind direction: $(wind-direction.to-int)°"
    else:
      print "Wind direction: Calm"
  print
      sun.night ? "Night" : "Day"

round value/float -> string:
  return (FixedPoint --decimals=0 value).stringify

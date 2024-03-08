import certificate-roots
import color-tft
import encoding.json
import encoding.url
import fixed-point show FixedPoint
import http
import net
import pixel-display
import solar-position show *
import weather-icons.png-112.all show *

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
    "lat": LATITUDE,
    "lon": LONGITUDE,
    "appid": API-KEY,
    "units": "metric",
    "exclude": "minutely,hourly,daily,alerts",
  }
  response/http.Response := client.get
      --host="api.openweathermap.org"
      --path="/data/2.5/weather"
      --query_parameters=parameters
      --headers=headers
  data := json.decode-stream response.body
  sun := solar-position Time.now LONGITUDE LATITUDE

  code/int := data["weather"][0]["id"]
  text/string := data["weather"][0]["main"]
  dry-temp := data["main"]["temp"]
  wind-speed := data["wind"]["speed"]
  wind-direction := data["wind"]["deg"]
  cloud-cover := data["clouds"]["all"]
  icon := code-to-icon code (not sun.night) dry-temp

  print data

  print "$text, $(round dry-temp)°C, $(round wind-speed)m/s, $wind-direction°, clouds $cloud-cover%"

round value/num -> string:
  return (FixedPoint --decimals=1 value).stringify

code-to-icon code/int day/bool temp/num -> ByteArray?:
  if 200 <= code < 300:
    // Thunderstorm.
    if temp > 0:
      return day ? DAY-THUNDERSTORM : NIGHT-THUNDERSTORM
    else:
      return day ? DAY-SNOW-THUNDERSTORM : NIGHT-SNOW-THUNDERSTORM
  else if 300 <= code < 313:
    // Drizzle, no shower.
    return day ? DAY-RAIN : NIGHT-RAIN
  else if 313 <= code < 400:
    // Drizzle, showers.
    return day ? DAY-SHOWERS : NIGHT-SHOWERS
  else if 500 <= code < 520:
    // Rain, no shower.
    return day ? DAY-RAIN : NIGHT-RAIN
  else if 520 <= code < 600 or code == 771:
    // Rain, showers, or squalls.
    return day ? DAY-SHOWERS : NIGHT-SHOWERS
  else if 600 <= code < 610:
    // Snow.
    return day ? DAY-SNOW : NIGHT-SNOW
  else if 610 <= code < 620:
    // Sleet.
    return day ? DAY-SLEET : NIGHT-SLEET
  else if 620 <= code < 700:
    // Snow with showers.
    return day ? DAY-SNOW : NIGHT-SNOW
  else if code == 721 and day:
    return DAY-HAZE
  else if code == 701 or code == 741 or code == 721:
    // Mist or fog or haze.
    return day ? DAY-FOG : NIGHT-FOG
  else if code == 711:
    return SMOKE
  else if code == 731 or code == 761:
    return DUST
  else if code == 751:
    return SANDSTORM
  else if code == 762:
    // Volcanic ash.
    return VOLCANO
  else if code == 781:
    return TORNADO
  else if code == 800:
    return day ? DAY-SUNNY : NIGHT-CLEAR
  else if code == 801 or code == 802:
    // 11-25% cloudy or 25-50% cloudy.
    return day ? DAY-CLOUDY : NIGHT-PARTLY-CLOUDY
  else if code == 803 or code == 804:
    // 50-84% cloudy or 85-100% cloudy.
    return day ? DAY-CLOUDY : NIGHT-CLOUDY
  return null

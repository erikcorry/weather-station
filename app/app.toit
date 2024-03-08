import certificate-roots
import color-tft
import encoding.json
import encoding.url
import esp32
import fixed-point show FixedPoint
import font show Font
import http
import net
import ntp
import pixel-display show *
import pixel-display.png show Png
import pixel-display.gradient show GradientSpecifier GradientBackground
import solar-position show *
import weather-icons.png-112.all show *
import roboto.black-40 as big
import roboto.medium-20 as small

import .api-key
import .get-display

LONGITUDE ::= 10.1337
LATITUDE ::= 56.09

main:
  certificate-roots.install-common-trusted-roots
  network := net.open
  set-time-from-net
  client := http.Client.tls network //--root-certificates=[certificate-roots.USERTRUST_RSA_CERTIFICATION_AUTHORITY]

  display := null
  catch --trace: display = get-display M5-STACK-24-BIT-LANDSCAPE-SETTINGS

  bg := GradientBackground --angle=60 --specifiers=[
      GradientSpecifier --color=0x6060a0 0,
      GradientSpecifier --color=0x202040 100,
      ]

  temperature-label := Label --x=30 --y=48 --id="temperature-label"
  weather-icon := Png --x=20 --y=50 --id="weather-icon"
  weather-description := Label --x=50 --y=160 --id="weather-description"
  wind-direction-icon := Png --x=200 --y=0 --id="wind-direction"
  wind-speed := Label --x=200 --y=110 --id="wind-speed"
  clock := Label --x=200 --y=220 --id="clock"
  location := Label --x=20 --y=220 --id="location"

  elements :=
      Div --x=0 --y=0 --w=320 --h=240 --background=0x000000 [
          temperature-label,
          weather-icon,
          weather-description,
          wind-direction-icon,
          wind-speed,
          clock,
          location,
      ]

  big-font := Font [big.ASCII, big.LATIN-1-SUPPLEMENT]
  small-font := Font [small.ASCII, small.LATIN-1-SUPPLEMENT]

  style := Style
      --id-map = {
        "temperature-label": Style --color=0xffffff --font=big-font,
        "weather-icon": Style --color=0xffdf80,
        "weather-description": Style --color=0xffdf80 --font=small-font,
        "wind-direction": Style --color=0xd0d0ff,
        "wind-speed": Style --color=0xd0d0ff --font=big-font,
        "clock": Style --color=0xcfffcf --font=big-font,
        "location": Style --color=0xa0a0a0 --font=small-font,
      }

  elements.set-styles [style]

  if display: display.add elements

  code/int? := null
  wind-direction/int := 0

  while true:
    catch --trace:
      weather := get-weather client
      if code != weather.code:
        code = weather.code
        png-file := weather.icon
        weather-icon.png-file = png-file
      if wind-direction != weather.wind-direction:
        wind-direction = weather.wind-direction
        wind-direction-icon.png-file = direction-to-icon wind-direction
      temperature-label.text = "$(round weather.dry-temp)°C"
      wind-speed.text = "$(weather.wind-speed.to-int)m/s"
      location.text = weather.name
      weather-description.text = weather.text
    30.repeat: | i |
      now := Time.now.local
      clock.text = "$(%02d now.h):$(%02d now.m)"
      if display:
        if i == 0:
          elements.background = 0
          display.draw
          elements.background = bg
          display.draw
        else:
          display.draw
      sleep --ms=20_000

class Weather:
  code/int
  icon/ByteArray?
  text/string
  dry-temp/num
  wind-speed/num
  wind-direction/int
  cloud-cover/int
  name/string

  constructor --.code/int --sun/SolarPosition --.text="" --.dry-temp --.wind-speed --.wind-direction --.cloud-cover --.name="":
    icon = code-to-icon code (not sun.night) dry-temp

get-weather client/http.Client -> Weather:
  headers := http.Headers
  //headers.add "X-Gravitee-Api-Key" API-KEY
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
  print "$text, $(round dry-temp)°C, $(round wind-speed)m/s, $wind-direction°, clouds $cloud-cover%"

  time-offset := data["timezone"] / 3600
  set-timezone "UTC-$time-offset"

  print Time.now.local

  return Weather --code=code --sun=sun --text=text --dry-temp=dry-temp --wind-speed=wind-speed --wind-direction=wind-direction --cloud-cover=cloud-cover --name=data["name"]

round value/num -> string:
  return (FixedPoint --decimals=1 value).stringify

direction-to-icon angle/int -> ByteArray?:
  if angle == 0: return null
  if angle < 22: return DIRECTION-UP
  if angle < 67: return DIRECTION-UP-RIGHT
  if angle < 112: return DIRECTION-RIGHT
  if angle < 157: return DIRECTION-DOWN-RIGHT
  if angle < 202: return DIRECTION-DOWN
  if angle < 247: return DIRECTION-DOWN-LEFT
  if angle < 292: return DIRECTION-LEFT
  if angle < 337: return DIRECTION-UP-LEFT
  return DIRECTION-UP

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

set-time-from-net:
  now := Time.now.utc
  if now.year < 1981:
    result ::= ntp.synchronize
    if result:
      catch --trace: esp32.adjust-real-time-clock result.adjustment
      print "Set time to $Time.now by adjusting $result.adjustment"
    else:
      print "ntp: synchronization request failed"

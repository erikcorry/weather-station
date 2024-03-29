// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the LICENSE file.

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
import pixel-display.true-color show get-rgb
import solar-position show *
import weather-icons.png-112.all show *
import roboto.black-italic-40 as big
import roboto.medium-40 as medium
import roboto.medium-20 as small

import system

import .api-key
import .get-display

// Aarhus.
LATITUDE := 56.15
LONGITUDE := 10.20

main:
  certificate-roots.install-common-trusted-roots
  network := net.open
  set-time-from-net
  client := http.Client.tls network

  display := null
  catch --trace: display = get-display M5-STACK-24-BIT-LANDSCAPE-SETTINGS

  ui :=
      Div --x=0 --y=0 --w=320 --h=240 --background=0x000030 [
          Div.clipping --classes=["button"] --x=10 --y=10 --w=150 --h=70 [
              Label --x=75 --y=50 --id="temperature-label",
          ],
          Png --x=20 --y=100 --id="weather-icon",
          Label --x=50 --y=220 --id="weather-description",
          Div.clipping --classes=["button"] --x=180 --y=10 --w=120 --h=120 [
              Png --x=0 --y=-10 --id="wind-direction",
              Label --x=60 --y=100 --id="wind-speed",
          ],
          Div.clipping --classes=["button"] --x=180 --y=170 --w=120 --h=50 [
              Label --x=60 --y=40 --id="clock",
          ],
          Label --x=220 --y=160 --id="location",
      ]

  big-font := Font [big.ASCII, big.LATIN-1-SUPPLEMENT]
  medium-font := Font [medium.ASCII, medium.LATIN-1-SUPPLEMENT]
  small-font := Font [small.ASCII, small.LATIN-1-SUPPLEMENT]

  temperature-label := ui.get-element-by-id "temperature-label"
  weather-icon := ui.get-element-by-id "weather-icon"
  weather-description := ui.get-element-by-id "weather-description"
  wind-direction-icon := ui.get-element-by-id "wind-direction"
  wind-speed := ui.get-element-by-id "wind-speed"
  clock := ui.get-element-by-id "clock"
  location := ui.get-element-by-id "location"

  style := Style
      --class-map = {
        "button": Style --background=0xc0c0c0 --border=(RoundedCornerBorder --radius=10),
      }
      --id-map = {
        "temperature-label": Style --color=0 --font=medium-font --align-center,
        "weather-icon": Style --color=0xffdf80,
        "weather-description": Style --color=0xffdf80 --font=small-font,
        "wind-direction": Style --color=0x4040df,
        "wind-speed": Style --color=0x4040df --font=medium-font --align-center,
        "clock": Style --color=0xcf0000 --font=big-font --align-center,
        "location": Style --color=0x909090 --font=small-font --align-center,
      }

  ui.set-styles [style]

  if display: display.add ui

  code/int? := null
  wind-direction/int := -1

  draw display clock

  while true:
    catch --trace:
      weather := get-weather client LATITUDE LONGITUDE
      code = weather.code
      png-file := weather.icon
      weather-icon.png-file = png-file
      new-wind-direction := weather.wind-direction
      if weather.wind-speed == 0: new-wind-direction = -1
      if wind-direction != new-wind-direction:
        wind-direction = new-wind-direction
        wind-direction-icon.png-file = direction-to-icon wind-direction
      temp := weather.dry-temp
      temperature-label.text = "$(round temp)°C"
      r := temp < -10 ? 0 : temp > 20 ? 255 : ((temp.to-int + 10) * 255) / 30
      g := 0x80
      b := 255 - r
      color := get-rgb r g b
      temperature-label.color = color
      wind-speed.text = "$(weather.wind-speed.to-int)m/s"
      location.text = weather.name
      weather-description.text = weather.text
      30.repeat: | i |
        draw display clock
        sleep --ms=20_000

draw display/PixelDisplay? clock/Label:
  now := Time.now.local
  clock.text = "$(%02d now.h):$(%02d now.m)"
  if display: display.draw

class Weather:
  code/int
  icon/ByteArray?
  text/string
  dry-temp/num
  wind-speed/num
  wind-direction/int
  cloud-cover/int
  name/string

  constructor
      --.code/int
      --sun/SolarPosition
      --.text=""
      --.dry-temp
      --.wind-speed
      --.wind-direction
      --.cloud-cover
      --.name="":
    icon = code-to-icon code (not sun.night) dry-temp

get-weather client/http.Client latitude/num longitude/num -> Weather:
  headers := http.Headers
  parameters := {
    "lat": latitude,
    "lon": longitude,
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
  if response.status-code != 200:
    print data
    exit 1
  sun := solar-position Time.now longitude latitude

  code/int := data["weather"][0]["id"]
  text/string := data["weather"][0]["main"]
  dry-temp := data["main"]["temp"]
  wind-speed := data["wind"]["speed"]
  wind-direction := data["wind"]["deg"]
  cloud-cover := data["clouds"]["all"]
  print "$text, $(round dry-temp)°C, $(round wind-speed)m/s, $wind-direction°, clouds $cloud-cover%"

  time-offset := data["timezone"] / 3600
  if time-offset > 0:
    set-timezone "UTC-$time-offset"
  else:
    set-timezone "UTC+$(-time-offset)"

  print Time.now.local

  return Weather
      --code=code
      --sun=sun
      --text=text
      --dry-temp=dry-temp
      --wind-speed=wind-speed
      --wind-direction=wind-direction
      --cloud-cover=cloud-cover
      --name=data["name"]

round value/num -> string:
  return (FixedPoint --decimals=1 value).stringify

direction-to-icon angle/int -> ByteArray?:
  if angle < 0: return null
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

// SolidBorder --width=5

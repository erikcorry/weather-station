// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the LICENSE file.

import certificate-roots
import encoding.json
import esp32
import http
import net
import ntp

API-KEY ::= "YOUR API KEY HERE"

// Insert your location here.
LONGITUDE ::= 10.1337
LATITUDE ::= 56.09

main:
  // Make sure we accept the common TLS certificates used by servers.
  certificate-roots.install-common-trusted-roots
  // Open the default network.
  network := net.open
  // Set time from NTP.
  set-time-from-net
  // Create an HTTP client that uses TLS for security.
  client := http.Client.tls network

  // These parameters will be encoded with the ?..&..& syntax.
  parameters := {
    "lat": LATITUDE,
    "lon": LONGITUDE,
    "appid": API-KEY,
    "units": "metric",
    "exclude": "minutely,hourly,daily,alerts",
  }

  // A GET request for the current weather.
  response/http.Response := client.get
      --host="api.openweathermap.org"
      --path="/data/2.5/weather"
      --query_parameters=parameters
  // Decode the JSON into a map object.
  data := json.decode-stream response.body
  // Dump the decoded JSON on the terminal or serial port.
  pretty-print data

// Call this once from the main function:
set-time-from-net:
  now := Time.now.utc
  if now.year < 1981:
    result ::= ntp.synchronize
    if result:
      catch --trace: esp32.adjust-real-time-clock result.adjustment
      print "Set time to $Time.now by adjusting $result.adjustment"
    else:
      print "ntp: synchronization request failed"

/// Simple pretty-printer for JSON-compatible objects (maps, lists, strings,
///   numbers, booleans, and null).
pretty-print data --indent/string="" --prefix/string?=null --suffix/string?="" -> none:
  str := json.stringify data
  if str.size < 80:
    print "$(prefix or indent)$str$suffix"
    return
  if data is Map:
    print "$(prefix or indent){"
    i := 0
    data.do: | key value |
      suffix2 := i == data.size - 1 ? null : ","
      pretty-print value --indent="$indent  " --prefix="$indent  \"$key\": " --suffix=suffix2
      i++
    print "$indent}$suffix"
  else if data is List:
    print "$(prefix or indent)["
    for i := 0; i < data.size; i++:
      value := data[i]
      suffix2 := i == data.size - 1 ? null : ","
      pretty-print value --indent="$indent  " --suffix=suffix2
    print "$indent]$suffix"
  else:
    print "$(prefix or indent)$str$suffix" 

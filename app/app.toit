import certificate-roots
import encoding.url
import http
import net
import solar-position

import .api-key

LONGITUDE ::= 10.1337
LATITUDE ::= 56.09

main:
  certificate-roots.install-common-trusted-roots
  network := net.open
  client := http.Client.tls network
  headers := http.Headers
  headers.add "X-Gravitee-Api-Key" API-KEY
  arguments
  response/http.Response := client.get
      --host="dmigw.govcloud.dk"
      --path="/v2/metObs/collections/observation/items?
      --headers=headers
  print response
  while data := response.body.read:
    print data.to-string

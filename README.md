![](https://avatars0.githubusercontent.com/u/2897191?s=70&v=4)

<!-- https://guides.github.com/pdfs/markdown-cheatsheet-online.pdf -->

# Cloudflare DNS

This script allows the user to perform the following actions as long as the API_KEY provided has permissions

1) Enumerate a list of zones attached to a Cloudflare account
2) Enumerate a list of DNS records (CAA, SPF, DMARC, DKIM)
3) Get the status of DNSSEC per domain and get the relevant DS record
4) Create a default SPF record for all domains that are not configured
5) Create a default DMARC record for all domains that are not configured
6) Create a default DKIM record for all domains that are not configured
7) Create a custom SPF record for all domains that are not configured
8) Create a custom DMARC record for all domains that are not configured
9) Create a custom DKIM record for all domains that are not configured
10) Enable DNSSEC for all domains that are not configured


Acceptable commandline options are shown below. 

|   | command line  | description |
|---|---|---|
|  1) | API_KEY="api_key" ./cloudflare.sh get_zones  | This will enumerate all zones in the cloudflare account that the API_KEY Environment Variable has access.   |
|  2) | API_KEY="api_key" ./cloudflare.sh get_records   | This will enumerate all records and create CSV files for CAA, SPF, DMARC, and DKIM records.   |
|  3) | API_KEY="api_key" ./cloudflare.sh get_dnssec  | This will enumerate all domains and check the status of DNSSEC and where applicable will return the DS record required to be set at your Domain Name Provider eg metaname, godaddy etc. Note that not all providers support DNSSEC.  |
|  | ### NOTE - the get_records parameter must be run prior to running the script with any of the parameters below. ### |
|  4) | API_KEY="api_key" ./cloudflare.sh create_spf  | Without any additional information will create a default SPF record for the domains that have "None" in the Record_Type column of output from "get_records" - {"type":"TXT","name":"@","content":"v=spf1 -all"}  |
|  5) | API_KEY="api_key" ./cloudflare.sh create_dmarc  | Without any additional information will create a default DMARC record for the domains that have "None" in the Record_Type column of output from "get_records" - {"type":"TXT","name":"_dmarc","content":"v=DMARC1; p=reject"}  |
|  6) | API_KEY="api_key" ./cloudflare.sh create_dkim  | Without any additional information will create a default DKIM record for the domains that have "None" in the Record_Type column of output from "get_records" - {"type":"TXT","name":"*._domainkey","content":"v=DKIM1; p="}  |
|  7) | API_KEY="api_key" ./cloudflare.sh create_spf "{"type":"TXT","name":"@","content":"v=spf1 ip4:192.0.2.0 ip4:192.0.2.1 include:examplesender.email -all"}"  | This will create the SPF record with information you provide in the commandline  |
|  8) | API_KEY="api_key" ./cloudflare.sh create_demarc "{"type":"TXT","name":"_dmarc","content":"v=DMARC1; p=quarantine; adkim=r; aspf=r; rua=mailto:example@third-party-example.com;"}" | This will create the DMARC record with information you provide in the commandline |
|  9) | API_KEY="api_key" ./cloudflare.sh create_dkim "{"type":"TXT","name":"big-email._domainkey.example.com","content":"=DKIM1; p=76E629F05F70A2362BECE40658267AB2FC3CB6CBE"}"  | This will create the DKIM record with information you provide in the commandline  |
|  10) | API_KEY="api_key" ./cloudflare.sh enable_dnssec  | This will turn on DNSSEC for the domains that have "None" in the Record_Type column of output from "get_records" and return the DS record required to be set at your Domain Name Provider eg metaname, godaddy etc. Note that not all providers support DNSSEC.  |




[Theta](https://theta.co.nz)

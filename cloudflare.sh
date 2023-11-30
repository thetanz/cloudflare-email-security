#!/bin/bash

# turn on debugging
#set -x

test -z "$API_KEY" && clear && echo '

     The API_KEY Environment Variable is required to be set. Please review the information below.
     
     ### This script can be run a couple of different ways. There are multiple parameters that perform different actions. ###
     ### The example below will connect to cloudflare using your API_KEY and enumerate all zones that your API_KEY has access to ###
     
     API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh get_zones
     
     See https://github.com/thetanz/cloudflare_dns for more information on the command line options
     
     ' && exit 1 ||:

if [ "$1" != "get_zones" ] && [ "$1" != "get_records" ] && [ "$1" != "get_dnssec" ] && [ "$1" != "create_spf" ] && [ "$1" != "create_dmarc" ] && [ "$1" != "create_dkim" ] && [ "$1" != "enable_dnssec" ]; then
    
     clear
     echo '
     
     Acceptable commandline options are shown below. 
     
     1) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh get_zones
     2) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh get_records     
     3) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh get_dnssec
     
     This will enumerate all domains and check the status of DNSSEC and where applicable will return the DS record 
     required to be set at your Domain Name Provider eg metaname, godaddy etc. Note that not all providers support DNSSEC.
     
     ##################################################################################################################
     ### NOTE - the get_records parameter must be run prior to running the script with any of the parameters below. ###
     ##################################################################################################################
     
     4) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_spf      
     5) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_dmarc     
     6) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_dkim     
     7) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_spf "{"type":"TXT","name":"@","content":"v=spf1 ip4:192.0.2.0 ip4:192.0.2.1 include:examplesender.email -all"}" 
     8) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_demarc "{"type":"TXT","name":"_dmarc","content":"v=DMARC1; p=quarantine; adkim=r; aspf=r; rua=mailto:example@third-party-example.com;"}"
     9) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh create_dkim "{"type":"TXT","name":"big-email._domainkey.example.com","content":"=DKIM1; p=76E629F05F709EF665853333EEC3F5ADE69A2362BECE40658267AB2FC3CB6CBE"}" 
     10) API_KEY="your_cloudflare_api_key_here" ./cloudflare.sh enable_dnssec

     See https://github.com/thetanz/cloudflare_dns for more information on the command line options
     
     '
    exit 2
fi

# Initialization
page=1
per_page=50

# Check if the first command-line argument is "get_zones"
if [ "$1" == "get_zones" ]; then
    # Initialize the page number and zones variable
    page=1
    zones=""
    
    # Create a new CSV file and add the column headers
    echo "zone_id,zone_name" > zones_list.csv

    # Start a loop that will continue until no more zones are found
    while true; do
        # Send a GET request to the Cloudflare API to get a list of zones
        # The page number is incremented with each iteration
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?page=$page&per_page=$per_page" \
            -H "Authorization: Bearer $API_KEY")

        # Parse the response to get the zone ID and name
        current_zones=$(echo "$response" | jq -r '.result[]? | [.id, .name] | @csv')

        # If no zones are found, break the loop
        [ -z "$current_zones" ] && break

        # Append the current zones to the CSV file
        echo "$current_zones" >> zones_list.csv

        # Increment the page number
        ((page++))
    done

    # Check if the CSV file has more than one line (header line + zones)
    if [ $(wc -l < zones_list.csv) -le 1 ]; then
        echo "No zones found. Please check the response below to determine if the error is with the API_KEY or permissions."
        echo "$response" >> zones_list.csv
        echo "$response"

    else
        echo "Zones exported to zones_list.csv."
    fi


# Check if the first command-line argument is "get_records"
elif [ "$1" == "get_records" ]; then
    # Initialize the page number
    page=1

    # Create new CSV files and add the column headers
    echo "zone_id,zone_name,record_type,name,value" > ./caa_records.csv
    echo "zone_id,zone_name,record_type,name,value" > ./spf_records.csv
    echo "zone_id,zone_name,record_type,name,value" > ./dmarc_records.csv
    echo "zone_id,zone_name,record_type,name,value" > ./dkim_records.csv
    
    # Start a loop that will continue until no more zones are found
    while true; do
        # Send a GET request to the Cloudflare API to get a list of zones
        # The page number is incremented with each iteration
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?page=$page&per_page=$per_page" \
            -H "Authorization: Bearer $API_KEY")

        # Parse the response to get the zone IDs
        zones=$(echo "$response" | jq -r '.result[]?.id')

        # If no zones are found, break the loop
        [ -z "$zones" ] && break

        # Iterate over each zone
        for zone in $zones; do
            # Get the zone name from the response
            zone_name_response=$(echo "$response" | jq -r --arg zone "$zone" '.result[] | select(.id == $zone) | [.id,.name] | @csv') 
            
            # Print the zone ID and zone name
            echo $zone_name_response

            # Send a GET request to the Cloudflare API to get all DNS records for the zone
            dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone/dns_records" \
                -H "Authorization: Bearer $API_KEY")

            # Extract and write the different record types to the CSV files
            # Extract CAA records
            caa_records=$(echo "$dns_records" | jq -r '.result[]? | select(.type=="CAA") | [.id,.zone_name,.type,.name,.content] | @csv')

            # Check if CAA records are found
            if [ -n "$caa_records" ]; then
                # If found, append them to the CAA records CSV file
                echo "$caa_records" >> ./caa_records.csv
            else
                # If not found, write a line to the CSV file indicating that no CAA records were found for this zone
                echo "$zone_name_response,\"None\",," >> ./caa_records.csv
            fi

            # Extract SPF records
            spf_records=$(echo "$dns_records" | jq -r '.result[]? | select(.type=="TXT") | select(.content | contains("v=spf1")) | [.id,.zone_name,.type,.name,.content] | @csv')

            # Check if SPF records are found
            if [ -n "$spf_records" ]; then
                # If found, append them to the SPF records CSV file
                echo "$spf_records" >> ./spf_records.csv
            else
                # If not found, write a line to the CSV file indicating that no SPF records were found for this zone
                echo "$zone_name_response,\"None\",," >> ./spf_records.csv
            fi

            # Extract DMARC records
            dmarc_records=$(echo "$dns_records" | jq -r '.result[]? | select(.content | contains("v=DMARC1")) | [.id,.zone_name,.type,.name,.content] | @csv')

            # Check if DMARC records are found
            if [ -n "$dmarc_records" ]; then
                # If found, append them to the DMARC records CSV file
                echo "$dmarc_records" >> ./dmarc_records.csv
            else
                # If not found, write a line to the CSV file indicating that no DMARC records were found for this zone
                echo "$zone_name_response,\"None\",," >> ./dmarc_records.csv
            fi

            # Extract DomainKey records
            domainkey_records=$(echo "$dns_records" | jq -r '.result[]? | select(.name | contains("domainkey")) | [.id,.zone_name,.type,.name,.content] | @csv')

            # Check if DomainKey records are found
            if [ -n "$domainkey_records" ]; then
                # If found, append them to the DomainKey records CSV file
                echo "$domainkey_records" >> ./dkim_records.csv
            else
                # If not found, write a line to the CSV file indicating that no DomainKey records were found for this zone
                echo "$zone_name_response,\"None\",," >> ./dkim_records.csv
            fi

        done

        # Increment the page counter
        ((page++))
    done


# Information about SPF Records can been found here - https://www.cloudflare.com/learning/dns/dns-records/dns-spf-record/
# Check if the first command-line argument is "create_spf"
elif [ "$1" == "create_spf" ]; then
    # Create new csv file to log updates - create_spf_records.csv
    echo "Create SPF Records logging - see below" > ./create_spf_records.csv
    
    # Set the filename of the CSV file
    SPF_ZONE_NAMES_FILENAME="./spf_records.csv"

    # Check if SPF_ZONE_NAMES_FILENAME exists
    if [ ! -f "$SPF_ZONE_NAMES_FILENAME" ]; then
        echo "Please ensure '$SPF_ZONE_NAMES_FILENAME' exists in the current directory"
        exit 1
    fi

    # Read the CSV file containing the zone names
    while IFS=',' read -r zone_id zone_name record_type name value ; do
        # Remove double quotes from zone_id
        zone_id="${zone_id//\"/}"
        # Check if the record type is "None"
        if [ "$record_type" = "\"None\"" ]; then
            # Create a new TXT record
            # Use the second command-line argument as the new TXT record, or use the default if not provided
            new_txt_record=${2:-'{"type":"TXT","name":"@","content":"v=spf1 -all"}'} 

            echo $zone_id $zone_name $new_txt_record
            # Check if zone_id is not empty
            if [ -n "$zone_id" ]; then
                # Create the new TXT record for the zone
                txt_records_endpoint="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records"
                response=$(curl -s -X POST "$txt_records_endpoint" -H "Authorization: Bearer $API_KEY" -d "$new_txt_record")
                
                # Check if the TXT record was created successfully
                if [ "$(echo "$response" | jq -r '.success')" = "true" ]; then
                    echo "TXT record created for $zone_name" >> ./create_spf_records.csv
                else
                    # Log any errors that occurred while creating the TXT record
                    echo "Error creating TXT record for $zone_name: $(echo "$response" | jq -r '.errors[]')" >> ./create_spf_records.csv
                fi
            else
                echo "Zone not found: $zone_name" >> ./create_spf_records.csv
            fi
        fi
    done < "$SPF_ZONE_NAMES_FILENAME"

# Information about DMARC Records can be found here - https://www.cloudflare.com/learning/dns/dns-records/dns-dmarc-record/
# Check if the first command-line argument is "create_dmarc"
elif [ "$1" == "create_dmarc" ]; then
    # Create new csv file to log updates - create_dmarc_records.csv
    echo "Create DMARC Records logging - see below" > ./create_dmarc_records.csv
    
    # Set the filename of the CSV file
    DMARC_ZONE_NAMES_FILENAME="./dmarc_records.csv"

    # Check if DMARC_ZONE_NAMES_FILENAME exists
    if [ ! -f "$DMARC_ZONE_NAMES_FILENAME" ]; then
        echo "Please ensure '$DMARC_ZONE_NAMES_FILENAME' exists in the current directory"
        exit 1
    fi

    # Read the CSV file containing the zone names
    while IFS=',' read -r zone_id zone_name record_type name value ; do
        # Remove double quotes from zone_id
        zone_id="${zone_id//\"/}"
        # Check if the record type is "None"
        if [ "$record_type" = "\"None\"" ]; then
            # Create a new TXT record
            # Use the second command-line argument as the new TXT record, or use the default if not provided
            new_txt_record=${2:-'{"type":"TXT","name":"_dmarc","content":"v=DMARC1; p=reject"}'} 

            echo $zone_id $zone_name $new_txt_record
            # Check if zone_id is not empty
            if [ -n "$zone_id" ]; then
                # Create the new TXT record for the zone
                txt_records_endpoint="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records"
                response=$(curl -s -X POST "$txt_records_endpoint" -H "Authorization: Bearer $API_KEY" -d "$new_txt_record")
                
                # Check if the TXT record was created successfully
                if [ "$(echo "$response" | jq -r '.success')" = "true" ]; then
                    echo "TXT record created for $zone_name" >> ./create_dmarc_records.csv
                else
                    # Log any errors that occurred while creating the TXT record
                    echo "Error creating TXT record for $zone_name: $(echo "$response" | jq -r '.errors[]')" >> ./create_dmarc_records.csv
                fi
            else
                echo "Zone not found: $zone_name" >> ./create_dmarc_records.csv
            fi
        fi
    done < "$DMARC_ZONE_NAMES_FILENAME"

# Information about DKIM records can be found here - https://www.cloudflare.com/learning/dns/dns-records/dns-dkim-record/
# Check if the first command-line argument is "create_dkim"
elif [ "$1" == "create_dkim" ]; then
    # Create new csv file to log updates - create_dkim_records.csv
    echo "Create DKIM Records logging - see below" > ./create_dkim_records.csv
    
    # Set the filename of the CSV file
    DKIM_ZONE_NAMES_FILENAME="./dkim_records.csv"

    # Check if DKIM_ZONE_NAMES_FILENAME exists
    if [ ! -f "$DKIM_ZONE_NAMES_FILENAME" ]; then
        echo "Please ensure '$DKIM_ZONE_NAMES_FILENAME' exists in the current directory"
        exit 1
    fi

    # Read the CSV file containing the zone names
    while IFS=',' read -r zone_id zone_name record_type name value ; do
        # Remove double quotes from zone_id
        zone_id="${zone_id//\"/}"
        # Check if the record type is "None"
        if [ "$record_type" = "\"None\"" ]; then
            # Create a new TXT record
            # Use the second command-line argument as the new TXT record, or use the default if not provided
            new_txt_record=${2:-'{"type":"TXT","name":"*._domainkey","content":"v=DKIM1; p="}'}

            echo $zone_id $zone_name $new_txt_record
            # Check if zone_id is not empty
            if [ -n "$zone_id" ]; then
                # Create the new TXT record for the zone
                txt_records_endpoint="https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records"
                response=$(curl -s -X POST "$txt_records_endpoint" -H "Authorization: Bearer $API_KEY" -d "$new_txt_record")
                
                # Check if the TXT record was created successfully
                if [ "$(echo "$response" | jq -r '.success')" = "true" ]; then
                    echo "TXT record created for $zone_name" >> ./create_dkim_records.csv
                else
                    # Log any errors that occurred while creating the TXT record
                    echo "Error creating TXT record for $zone_name: $(echo "$response" | jq -r '.errors[]')" >> ./create_dkim_records.csv
                fi
            else
                echo "Zone not found: $zone_name" >> ./create_dkim_records.csv
            fi
        fi
    done < "$DKIM_ZONE_NAMES_FILENAME"


# Information about DNSSEC can be found here - https://www.cloudflare.com/dns/dnssec/how-dnssec-works/
# Check if the first command-line argument is "get_dnssec"
elif [ "$1" == "get_dnssec" ]; then
    # Initialize the page counter
    page=1

    # Create a new CSV file and write the header row
    echo "Zone ID, Zone Name, DNSSEC Status, DS Record, algorithm, digest, digest_algorithm, digest_type, flags, key_tag, key_type, modified_on, public_key" > dnssec_status.csv

    # Start an infinite loop
    while true; do
        # Send a GET request to the Cloudflare API to retrieve the zones, and store the response
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?page=$page&per_page=$per_page" \
            -H "Authorization: Bearer $API_KEY")

        # Extract the zone IDs from the response
        zones=$(echo $response | jq -r '.result[]?.id')

        # If there are no more zones, break the loop
        [ -z "$zones" ] && break

        # For each zone, do the following
        for zone in $zones; do
            # Send a GET request to the Cloudflare API to retrieve the DNSSEC record for the zone, and store the response
            cf_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone/dnssec" \
                -H "Authorization: Bearer $API_KEY" )

            # Extract the zone name from the response
            zone_name_response=$(echo $response | jq -r --arg zone $zone '.result[] | select(.id == $zone) | [.name] | @csv' | tr -d '"') 

            # Extract the DNSSEC record and other related information from the response
            dnssec_record=$(echo $cf_response | jq -r '.result.ds // empty')
            dnssec_status=$(echo $cf_response | jq -r '.result.status // empty')
            dnssec_digest=$(echo $cf_response | jq -r '.result.digest // empty')
            dnssec_flags=$(echo $cf_response | jq -r '.result.flags // empty')
            dnssec_digest_algorithm=$(echo $cf_response | jq -r '.result.digest_algorithm // empty')
            dnssec_algorithm=$(echo $cf_response | jq -r '.result.algorithm // empty')
            dnssec_key_tag=$(echo $cf_response | jq -r '.result.key_tag // empty')
            dnssec_key_type=$(echo $cf_response | jq -r '.result.key_type // empty')
            dnssec_digest_type=$(echo $cf_response | jq -r '.result.digest_type // empty')
            dnssec_public_key=$(echo $cf_response | jq -r '.result.public_key // empty')
            dnssec_modified_on=$(echo $cf_response | jq -r '.result.modified_on // empty')

            # Write the zone ID, zone name, DNSSEC record, and other related information to the CSV file
            echo "'$zone','$zone_name_response','$dnssec_status','$dnssec_record','$dnssec_algorithm','$dnssec_digest','$dnssec_digest_algorithm','$dnssec_digest_type','$dnssec_flags','$dnssec_key_tag','$dnssec_key_type','$dnssec_modified_on','$dnssec_public_key'," >> dnssec_status.csv
        done

        # Increment the page counter
        ((page++))
    done


# Information about DNSSEC can be found here - https://www.cloudflare.com/dns/dnssec/how-dnssec-works/
# Check if the first command-line argument is "get_dnssec"
elif [ "$1" == "enable_dnssec" ]; then
    # Initialize the page counter
    page=1

    # Create a new CSV file and write the header row
    echo "Zone ID, Zone Name, DNSSEC Status, DS Record, algorithm, digest, digest_algorithm, digest_type, flags, key_tag, key_type, modified_on, public_key" > dnssec_enable_status.csv

    # Start an infinite loop
    while true; do
        # Send a GET request to the Cloudflare API to retrieve the zones, and store the response
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?page=$page&per_page=$per_page" \
            -H "Authorization: Bearer $API_KEY")

        # Extract the zone IDs from the response
        zones=$(echo "$response" | jq -r '.result[]?.id') 

        # If there are no more zones, break the loop
        [ -z "$zones" ] && break

        # For each zone, do the following
        for zone in $zones; do
            
            # Send a PATCH request to the Cloudflare API to enable DNSSEC for the zone, and store the response
            enable_dnssec_response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone/dnssec" \
                -H "Authorization: Bearer $API_KEY" \
                -H "Content-Type: application/json" \
                --data '{
                    "status": "active"
                }')

            # Extract the zone name from the response
            cf_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone/dnssec" \
                -H "Authorization: Bearer $API_KEY" )

            # Extract the DNSSEC record and other related information from the response
            zone_name_response=$(echo "$response" | jq -r --arg zone "$zone" '.result[] | select(.id == $zone) | [.name] | @csv') 
            dnssec_record=$(echo $cf_response | jq -r '.result.ds // empty')
            dnssec_status=$(echo $cf_response | jq -r '.result.status // empty')
            dnssec_digest=$(echo $cf_response | jq -r '.result.digest // empty')
            dnssec_flags=$(echo $cf_response | jq -r '.result.flags // empty')
            dnssec_digest_algorithm=$(echo $cf_response | jq -r '.result.digest_algorithm // empty')
            dnssec_algorithm=$(echo $cf_response | jq -r '.result.algorithm // empty')
            dnssec_key_tag=$(echo $cf_response | jq -r '.result.key_tag // empty')
            dnssec_key_type=$(echo $cf_response | jq -r '.result.key_type // empty')
            dnssec_digest_type=$(echo $cf_response | jq -r '.result.digest_type // empty')
            dnssec_public_key=$(echo $cf_response | jq -r '.result.public_key // empty')
            dnssec_modified_on=$(echo $cf_response | jq -r '.result.modified_on // empty')

            # Write the zone ID, zone name, DNSSEC record, and other related information to the CSV file
            echo "'$zone','$zone_name_response','$dnssec_status','$dnssec_record','$dnssec_algorithm','$dnssec_digest','$dnssec_digest_algorithm','$dnssec_digest_type','$dnssec_flags','$dnssec_key_tag','$dnssec_key_type','$dnssec_modified_on','$dnssec_public_key'," >> dnssec_enable_status.csv

        done

        # Increment the page counter
        ((page++))
    done
fi

#!/bin/sh
LOG_FILE='/tmp/cloudflarespeedtest.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$LOG_FILE
}

urlencode() {
	# urlencode url<string>
	out=''
	for c in $(echo -n $1 | sed 's/[^\n]/&\n/g'); do
		case $c in
			[a-zA-Z0-9._-]) out="$out$c" ;;
			*) out="$out$(printf '%%%02X' "'$c")" ;;
		esac
	done
	echo -n $out
}

send_request() {
	# send_request action<string> args<string>
	local args="AccessKeyId=$ak_id&Action=$1&Format=json&$2&Version=2015-01-09"
	local hash=$(urlencode $(echo -n "GET&%2F&$(urlencode $args)" | openssl dgst -sha1 -hmac "$ak_sec&" -binary | openssl base64))
	curl -sSL --connect-timeout 5 "http://alidns.aliyuncs.com/?$args&Signature=$hash"
}

get_recordid() {
	sed 's/RR/\n/g' | sed -n 's/.*RecordId[^0-9]*\([0-9]*\).*/\1\n/p' | sort -ru | sed /^$/d
}

log_response_error() {
	local action="$1"
	local response="$2"
	local code message

	code="$(echo "$response" | sed -n 's/.*"Code"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
	message="$(echo "$response" | sed -n 's/.*"Message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

	if [ -n "$code" ] || [ -n "$message" ]; then
		echolog "$action failed: ${code:-unknown} ${message}"
	else
		echolog "$action failed: $response"
	fi
}

query_recordid() {
	send_request "DescribeSubDomainRecords" "DomainName=$main_dm&Line=$line&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$sub_dm.$main_dm&Timestamp=$timestamp&Type=$type"
}

update_record() {
	send_request "UpdateDomainRecord" "Line=$line&RR=$sub_dm&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&Timestamp=$timestamp&Type=$type&Value=$ip"
}

add_record() {
	send_request "AddDomainRecord&DomainName=$main_dm" "Line=$line&RR=$sub_dm&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&Timestamp=$timestamp&Type=$type&Value=$ip"
}

del_record() {
	send_request "DeleteDomainRecord" "RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&Timestamp=$timestamp"
}

aliddns() {
	if [ "$#" -lt 7 ]; then
		echolog "# ERROR, Missing arguments"
		exit 1
	fi

	ak_id=$1
	ak_sec=$2
	main_dm=$3
	sub_dm=$4
	line=$5
	isIpv6=$6
	shift 6
	type=A
	
	if [ "x${isIpv6}" = "x1" ] ;then
		type=AAAA
	fi

	query_response=`query_recordid`
	rrids=`echo "$query_response" | get_recordid`
	if echo "$query_response" | grep -q '"Code"[[:space:]]*:'; then
		log_response_error "QUERY record $type $sub_dm.$main_dm" "$query_response"
	fi

	failed=0
	index=1
	for ip in "$@"; do
		[ -z "$ip" ] && continue
		rrid=`echo "$rrids" | sed -n "${index}p"`

		if [ -z "$rrid" ]; then
			response=`add_record`
			rrid=`echo "$response" | get_recordid`
			if [ -n "$rrid" ]; then
				echolog "ADD record $rrid $type $ip"
			else
				log_response_error "ADD record $type $ip" "$response"
				failed=1
			fi
		else
			response=`update_record "$rrid"`
			if echo "$response" | grep -q '"Code"[[:space:]]*:'; then
				log_response_error "UPDATE record $rrid $type $ip" "$response"
				failed=1
			else
				echolog "UPDATE record $rrid $type $ip"
			fi
		fi
		index=$((index + 1))
	done

	if [ $index -eq 1 ]; then
		echolog "# ERROR, No IP provided"
		exit 1
	fi

	exit $failed
}


timestamp=$(date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ")

aliddns "$@"

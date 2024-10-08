#!/usr/bin/env bash

#!/usr/bin/env bash

display_usage() {
	echo ""
	echo "Usage: $0 [--env ENV]"
	echo ""
	echo "Options:"
	echo "  --env ENV    Specify the environment (pc, all). Defaults to 'pc'."
	echo ""
	echo "Example: $0 --env all"
	echo ""
}

# Default environment
ENV="okta-pcca"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		--env)
			if [[ $# -lt 2 ]]; then
				display_usage
				exit 1
			fi
			case "$2" in
				pc|pcca)
					ENV="okta-pcca"
					;;
				all)
					ENV="okta"
					;;
				*)
					echo "Invalid environment: $2"
					display_usage
					exit 1
					;;
			esac
			shift 2
			;;
		*)
			echo "Invalid argument: $1"
			display_usage
			exit 1
			;;
	esac
done

function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }

pstr="============================================================================"
tele_login() {
	#Current time + 4hours
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		# Linux (GNU version)
		expirylimit=$(date -d '+4 hour' '+%F'T'%T')
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		# MacOS
		expirylimit=$(date -j -v +4H '+%F'T'%T')
	elif [[ "$OSTYPE" == "cygwin" ]]; then
		# POSIX compatibility layer and Linux environment emulation for Windows
		expirylimit=$(date -d '+4 hour' '+%F'T'%T')
	elif [[ "$OSTYPE" == "msys" ]]; then
		# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
		expirylimit=$(date -d '+4 hour' '+%F'T'%T')
	else
		# Unknown.
		expirylimit=$(date -d '+4 hour' '+%F'T'%T')
	fi

	#Session expiry time
	sessionexpiry=$(tsh status --format=json 2>/dev/null | jq '.active.valid_until' | tr -d "\"")

	if [[ -z "$(tsh status)" ]]; then
		echo "Not logged in"
		tsh logout
		tsh login --proxy=paramountcommerce.teleport.sh --auth=$ENV
	elif [[ "$sessionexpiry" < "$expirylimit" ]]; then
		echo "Teleport session has expired or is expiring soon, launching a new session..."
		tsh logout
		tsh login --proxy=paramountcommerce.teleport.sh --auth=$ENV
	fi
	echo "Teleport Status"
	tsh status
}
tele_version_check() {
	TELEPORT_VERSION=$(curl -s https://paramountcommerce.teleport.sh/webapi/ping | jq -r .server_version | sed -E 's/([0-9]+\.[0-9]{1,3})[^ ]*/\1/g')
	LOCAL_VERSION=$(tsh version --format=json | jq .version | tr -d '"' | sed -E 's/([0-9]+\.[0-9]{1,3})[^ ]*/\1/g')
	[ $(ver $TELEPORT_VERSION) -gt $(ver $LOCAL_VERSION) ] &&
		echo "You seem to be using an older version of tsh client, please upgrade your local teleport version to the cloud version: $TELEPORT_VERSION or higher and retry" &&
		echo "yum install teleport-$(curl -s https://paramountcommerce.teleport.sh/webapi/ping | jq -r .server_version)" &&
		exit
}
tele_db() {
		AVAILABLE_ENVS=$(tsh db ls --format=json | jq -r '[.[].metadata.labels.Environment] | unique')

		if [ "$(echo "$AVAILABLE_ENVS" | jq length)" -eq 1 ]; then
		  environment=$(echo "$AVAILABLE_ENVS" | jq -r '.[0]')
		  echo "Only one environment found: $environment. Selecting it automatically."
		else
		  echo -n "Enter the environment you'd like to access $(echo "$AVAILABLE_ENVS" | tr -d \" | sed "s/,/ /g")"
		  read environment
		fi

		if [ -z "$(tsh db ls Environment="$environment" | tail -n +3 | cut -f1 -d' ')" ]; then
		  echo "No RDS found for the specified environment, taking you back to the main menu..."
		  break
		else
		tsh db ls Environment="$environment" -f json | jq -r '.[] | .metadata.name'
		echo $pstr
		echo -n "Enter/Paste the DB name you'd like to connect from the list above: "
		read db_name
		echo -n "Select DB username: $(tsh db ls --format=json | jq -r '[.[].users.allowed] | unique') : "
		read db_user
		tsh db login $db_name --db-user $db_user --db-name postgres
		key=$(tsh db config $db_name --format=json | jq -r '.key')
		openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt -in $key -out $key.pk8
		connection_info=$(tsh db config $db_name --format=json)

		# Display connection details
		echo "Hello! Use the below details to configure dBeaver:"
		echo "DB Connection Name : $(echo $connection_info | jq -r '.name')"
		echo "Host : localhost"
		echo "Port : 11144"
		echo "Database : postgres"
		echo "Authentication: Database Native"
		echo "Username : $(echo $connection_info | jq -r '.user')"
		echo "SSL Configuration"
		echo "CA Certificate : $(echo $connection_info | jq -r '.ca')"
		echo "Client Certificate : $(echo $connection_info | jq -r '.cert')"
		echo "Client Private Key: $key.pk8"

		# Generate JDBC connection string
		jdbc_connection_string="jdbc:postgresql://localhost:11144/postgres?ssl=true&sslmode=verify-full&sslrootcert=$(echo $connection_info | jq -r '.ca')&sslcert=$(echo $connection_info | jq -r '.cert')&sslkey=$key.pk8&user=$(echo $connection_info | jq -r '.user')"
		echo -e "JDBC Connection String: \e[32m $jdbc_connection_string\e[0m"

		# Generate psql CLI connection command
		psql_connection_command="psql 'postgresql://$(echo $connection_info | jq -r '.user')@localhost:11144/postgres?sslmode=verify-full&sslcert=$(echo $connection_info | jq -r '.cert')&sslkey=$key.pk8&sslrootcert=$(echo $connection_info | jq -r '.ca')'"
		echo -e "CLI Connection Command: \e[32m $psql_connection_command\e[0m"
	
		# Start porxy
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# macOS
		  if ! lsof -Pi :11144 -sTCP:LISTEN -t >/dev/null ; then
		    proxy="tsh proxy db $db_name --port 11144"
		    $proxy >/dev/null 2>&1 &
				echo Proxy enabled on tcp/11144
		  fi
		elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
			# Linux
		  if ss -lnt | awk '$4 ~ /:11144$/ {exit 1}'; then
		    proxy="tsh proxy db $db_name --port 11144"
		    $proxy >/dev/null 2>&1 & 
				echo Proxy enabled on tcp/11144
		  fi
		else
		  echo "Unsupported operating system: $OSTYPE"
		  exit 1
		fi
	fi
}
tele_assume() {
	# TODO: show only my sessions
	tsh requests ls
	echo $pstr
	echo -n "Enter the request ID you'd like to use for this session:"
	read requestid
	tsh request show $requestid
	tsh login --request-id=$requestid
}
tele_k8s() {
  echo "Here is the list of clusters you have access to:"
	tsh kube ls
	echo $pstr
	echo -n "Enter/Paste the Kubernetes Cluster name you'd like to connect from the list above:"
	read k8s_cluster_name
  tsh kube login $k8s_cluster_name
}

tele_migrate() {
	  echo "NOTE! This script will automatically change the dbeaver connection configuration for HOST to localhost which is a requirement for Teleport TLS versions to work"
		read -p "Continue (y/n)?" choice
		case "$choice" in
			y|Y|yes|Yes|YES )
				echo "You chose YES"
				echo "modifying script..."
				tmp=$(mktemp)
				jq ".connections[].configuration |= (
				    if .host == \"paramountcommerce.teleport.sh\" then
        				.host = \"localhost\"
    				else
				        .
				    end)" ~/.local/share/DBeaverData/workspace6/General/.dbeaver/data-sources.json > "$tmp" && mv "$tmp" ~/.local/share/DBeaverData/workspace6/General/.dbeaver/data-sources.json
				echo "Migration complete, please restart dBeaver"
				;;
			n|N|NO|No|no )
				echo "You chose NO, aborting";;
			* )
				echo "invalid";;
		esac
}
tele_request_access() {
  ALLOWED_ROLES=$(tctl get roles --format json | jq -r '.[] | .metadata.name')
  REQ_TTL=$(expr $(expr $(date +"%s" -d $(tsh status --format=json 2>/dev/null | jq '.active.valid_until' | tr -d "\"")) - $(date +"%s")) / 3600)
	echo "Enter the role(s) separated by comma, you'd like to request access from $ALLOWED_ROLES"
	read req_role
	echo "Type below the reason for your request"
	read req_reason
  tsh request create --roles "$req_role" --reason "$req_reason" --request-ttl "${REQ_TTL}h" > /dev/null 2>&1 &
	echo "Request submitted successfully"
}

PS3='Please enter your choice(1-Tsh Login, 2-ConnectDB, 3-AssumeRole, 4-RequestRoleAccess, 5-ConnectKubernetes, 6-SessionLogout, 7-MigrateToV2Script, 8-Quit): '
options=("Teleport Login" "Connect to DB" "Assume Role & Connect to DB" "Request Role Access" "Connect to Kubernetes Cluster" "Tsh Logout" "Migrate To V2 Script" "Quit")
select opt in "${options[@]}"; do
	case $opt in
	"Teleport Login")
		echo "You chose: Teleport Login"
		tele_version_check
		tele_login
		;;
	"Connect to DB")
		echo "You chose: Connecting to a DB"
		tele_version_check
		tele_login
		tele_db
		;;
	"Assume Role & Connect to DB")
		echo "You chose: Logging in with new access / request ID"
		tele_version_check
		tele_login
		tele_assume
		tele_db
		;;
	"Request Role Access")
		echo "You chose: Request access to a Teleport role"
    tele_request_access
		;;
	"Connect to Kubernetes Cluster")
		echo "You chose: Connecting to a Kubernetes Cluster"
		tele_version_check
		tele_login
    tele_k8s
		;;
	"Tsh Logout")
		echo "You chose: Logging out all teleport sessions"
		tsh logout
		# Check if the script is running on macOS or Linux
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# macOS
		  kill_proxy="lsof -ti :11144 | xargs kill"
		  $kill_proxy >/dev/null 2>&1 &
		elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
			# Linux
		  kill_proxy="fuser -k 11144/tcp"
		  $kill_proxy >/dev/null 2>&1 &
		else
		  echo "Unsupported operating system: $OSTYPE"
		  exit 1
		fi
		echo "Killed all teleport background processes"
		;;
	"Migrate To V2 Script")
    tele_migrate
		;;
	"Quit")
		break
		;;
	*) echo "invalid option $REPLY" ;;
	esac
done

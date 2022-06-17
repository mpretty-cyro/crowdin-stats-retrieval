#!/bin/bash
#
# Note this script requires you to have https://stedolan.github.io/jq/ installed

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
		shift	# past argument
		;;
    -a|--ios-project-id)
		IOS_PROJECT="$2"
		shift	# past value
		;;
	-b|--android-project-id)
		ANDROID_PROJECT="$2"
		shift	# past value
		;;
	-c|--desktop-project-id)
		DESKTOP_PROJECT="$2"
		shift	# past value
		;;
    -t|--token)
    	TOKEN="$2"
    	shift	# past value
    	;;
	-o|--output)
    	OUTPUT="$2"
    	shift	# past value
    	;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
  shift
done

if [[ -z $IOS_PROJECT ]]; then
    echo "You must provide the iOS Crowdin Project Id via the '-a' parameter"
    exit 1
fi

if [[ -z $ANDROID_PROJECT ]]; then
    echo "You must provide the Android Crowdin Project Id via the '-b' parameter"
    exit 1
fi

if [[ -z $DESKTOP_PROJECT ]]; then
    echo "You must provide the iOS Crowdin Project Id via the '-c' parameter"
    exit 1
fi

if [[ -z $TOKEN ]]; then
    echo "You must provide a Crowdin personal access token via the '-t' parameter"
    exit 1
fi

if [[ -z $OUTPUT ]]; then
    echo "You must provide an output file via the '-o' parameter"
    exit 1
fi

function retrieve_project_stats {
	local platform=$1
	local project_id=$2

	echo "Retrieving Languages for $platform Project Id: $project_id"

	local PROJECT_INFO_URL="https://api.crowdin.com/api/v2/projects/$project_id?limit=500"
	local PROJECT_RESPONSE=$(\
		curl -X GET $PROJECT_INFO_URL \
			-H 'Content-Type: application/json' \
	     	-H "Authorization: Bearer $TOKEN"
	)

	IFS=$'\n'
	local LANGUAGE_IDS=($(echo "$PROJECT_RESPONSE" | jq -r '.data.targetLanguages[].id'))
	local LANGUAGE_NAMES=($(echo "$PROJECT_RESPONSE" | jq -r '.data.targetLanguages[].name'))

	echo "Found ${#LANGUAGE_IDS[@]} languages"

	for i in "${!LANGUAGE_IDS[@]}"
	do
	   	local LANGUAGE_STATS_URL="https://api.crowdin.com/api/v2/projects/$project_id/languages/${LANGUAGE_IDS[$i]}/progress"
	   	local LANGUAGE_STATS=$(\
			curl -X GET $LANGUAGE_STATS_URL \
				-H 'Content-Type: application/json' \
		     	-H "Authorization: Bearer $TOKEN"
		)
	   
	   	local TRANSLATION_PROGRESS=$(echo "$LANGUAGE_STATS" | jq -r '.data[0].data.translationProgress')
		local APPROVAL_PROGRESS=$(echo "$LANGUAGE_STATS" | jq -r '.data[0].data.approvalProgress')
		local PHRASE_TRANSLATED=$(echo "$LANGUAGE_STATS" | jq -r '.data[0].data.phrases.translated')
		local PHRASE_APPROVED=$(echo "$LANGUAGE_STATS" | jq -r '.data[0].data.phrases.approved')
		local PHRASE_TOTAL=$(echo "$LANGUAGE_STATS" | jq -r '.data[0].data.phrases.total')
		local SAFE_NAME=$(echo ${LANGUAGE_NAMES[$i]} | sed -r 's/,/:/')	# Some language names have commans which break the CSV

	   	echo "$SAFE_NAME (${LANGUAGE_IDS[$i]}),$platform,$TRANSLATION_PROGRESS,$APPROVAL_PROGRESS,$PHRASE_TRANSLATED,$PHRASE_APPROVED,$PHRASE_TOTAL" >> $OUTPUT
	done
}


echo "Language,Platform,Translated Percent,Approved Percent,Translated Phrases,Approved Phrases,Total Phrases" > $OUTPUT
retrieve_project_stats "iOS" $IOS_PROJECT
retrieve_project_stats "Android" $ANDROID_PROJECT
retrieve_project_stats "Desktop" $DESKTOP_PROJECT

echo "Completed generating CSV"
#!/bin/bash
# 
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
#############        Explore Load Balancing with Cloud CDN        ###############
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-ce-lbcdn
export PROJDIR=`pwd`/gcp-ce-lbcdn
export SCRIPTNAME=gcp-ce-lbcdn.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-west2
export GCP_ZONE=us-west2-a
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
====================================================================
Exploring HTTP Load Balancing and Cloud CDN  
--------------------------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Create compute instances
 (3) Add instances to unmanaged instance group 
 (4) Configure unmanaged instance group ports 
 (5) Configure basic healthcheck and backend services
 (6) Add backend services to instance groups and configure scaling
 (7) Configure URL map and target http proxy
 (8) Configure forwarding rules
 (9) Configure load balancer firewall rule
(10) Create load testing instances
(11) Generate load
(12) Create and configure storage bucket
(13) Update URL map and add backend bucket 
(14) Enable CDN
(15) Generate load
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable compute.googleapis.com # to enable compute APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable compute.googleapis.com # to enable compute APIs" | pv -qL 100
    gcloud services enable compute.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud compute instances create glbcdn-html-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF\" # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create glbcdn-video-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF\" # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create glbcdn-html-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF\" # to create instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create glbcdn-video-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF\" # to create instance" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    echo
    echo "$ gcloud compute instances create glbcdn-html-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF\" # to create instance" | pv -qL 100
    gcloud compute instances create glbcdn-html-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script="#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF"
    echo
    echo "$ gcloud compute instances create glbcdn-video-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF\" # to create instance" | pv -qL 100
    gcloud compute instances create glbcdn-video-instance-us-central1-b --image-family debian-11 --image-project debian-cloud --zone us-central1-b --network default --metadata startup-script="#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF"
    echo
    echo "$ gcloud compute instances create glbcdn-html-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF\" # to create instance" | pv -qL 100
    gcloud compute instances create glbcdn-html-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script="#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-html</h1></body></html>' | sudo tee /var/www/html/index.html
      EOF"
    echo
    echo "$ gcloud compute instances create glbcdn-video-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script=\"#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF\" # to create instance" | pv -qL 100
    gcloud compute instances create glbcdn-video-instance-europe-west1-b --image-family debian-11 --image-project debian-cloud --zone europe-west1-b --network default --metadata startup-script="#! /bin/bash
      sudo apt-get update
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/index.html
      sudo mkdir /var/www/html/video
      echo '<!doctype html><html><body><h1>web-video</h1></body></html>' | sudo tee /var/www/html/video/index.html
      EOF"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "$ gcloud compute instances delete glbcdn-html-instance-us-central1-b --zone us-central1-b # to delete instance" | pv -qL 100
    gcloud compute instances delete glbcdn-html-instance-us-central1-b --zone us-central1-b 
    echo
    echo "$ gcloud compute instances delete glbcdn-video-instance-us-central1-b # to delete instance" | pv -qL 100
    gcloud compute instances delete glbcdn-video-instance-us-central1-b --zone us-central1-b 
    echo
    echo "$ gcloud compute instances delete glbcdn-html-instance-europe-west1-b # to delete instance" | pv -qL 100
    gcloud compute instances delete glbcdn-html-instance-europe-west1-b --zone europe-west1-b 
    echo
    echo "$ gcloud compute instances delete glbcdn-video-instance-europe-west1-b # to delete instance" | pv -qL 100
    gcloud compute instances delete glbcdn-video-instance-europe-west1-b --zone europe-west1-b 
else
    export STEP="${STEP},2i"
    echo
    echo "1. Create virtual machine instances" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-us-central1-b --zone us-central1-b # to create unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-us-central1-b --zone us-central1-b # to create unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-europe-west1-b --zone europe-west1-b # to create unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-europe-west1-b --zone europe-west1-b # to create unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-us-central1-b --instances glbcdn-video-instance-us-central1-b --zone us-central1-b # to add instance to unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-us-central1-b --instances glbcdn-html-instance-us-central1-b --zone us-central1-b # to add instance to unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-europe-west1-b --instances glbcdn-video-instance-europe-west1-b --zone europe-west1-b # to add instance to unmanaged instance group" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-europe-west1-b --instances glbcdn-html-instance-europe-west1-b --zone europe-west1-b # to add instance to unmanaged instance group" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-us-central1-b --zone us-central1-b # to create unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-us-central1-b --zone us-central1-b # to create unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-europe-west1-b --zone europe-west1-b # to create unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged create glbcdn-video-instance-group-europe-west1-b --zone europe-west1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-europe-west1-b --zone europe-west1-b # to create unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged create glbcdn-html-instance-group-europe-west1-b --zone europe-west1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-us-central1-b --instances glbcdn-video-instance-us-central1-b --zone us-central1-b # to add instance to unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-us-central1-b --instances glbcdn-video-instance-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-us-central1-b --instances glbcdn-html-instance-us-central1-b --zone us-central1-b # to add instance to unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-us-central1-b --instances glbcdn-html-instance-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-europe-west1-b --instances glbcdn-video-instance-europe-west1-b --zone europe-west1-b # to add instance to unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged add-instances glbcdn-video-instance-group-europe-west1-b --instances glbcdn-video-instance-europe-west1-b --zone europe-west1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-europe-west1-b --instances glbcdn-html-instance-europe-west1-b --zone europe-west1-b # to add instance to unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged add-instances glbcdn-html-instance-group-europe-west1-b --instances glbcdn-html-instance-europe-west1-b --zone europe-west1-b
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    echo
    echo "$ gcloud compute instance-groups unmanaged delete glbcdn-video-instance-group-us-central1-b --zone us-central1-b # to delete unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged delete glbcdn-video-instance-group-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged delete glbcdn-html-instance-group-us-central1-b --zone us-central1-b # to delete unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged delete glbcdn-html-instance-group-us-central1-b --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged delete glbcdn-video-instance-group-europe-west1-b --zone europe-west1-b # to delete unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged delete glbcdn-video-instance-group-europe-west1-b --zone europe-west1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged delete glbcdn-html-instance-group-europe-west1-b --zone europe-west1-b # to delete unmanaged instance group" | pv -qL 100
    gcloud compute instance-groups unmanaged delete glbcdn-html-instance-group-europe-west1-b --zone europe-west1-b
else
    export STEP="${STEP},3i"
    echo
    echo "1. Configure unmanaged instance groups" | pv -qL 100
    echo "2. Add virtual machine images to unmanaged instance group" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b # to configure port" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b # to configure port" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b # to configure port" | pv -qL 100
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b # to configure port" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b # to configure port" | pv -qL 100
    gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b # to configure port" | pv -qL 100
    gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-us-central1-b --named-ports http:80 --zone us-central1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b # to configure port" | pv -qL 100
    gcloud compute instance-groups unmanaged set-named-ports glbcdn-video-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b
    echo
    echo "$ gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b # to configure port" | pv -qL 100
    gcloud compute instance-groups unmanaged set-named-ports glbcdn-html-instance-group-europe-west1-b --named-ports http:80 --zone europe-west1-b
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},4i"
    echo
    echo "1. Configure unmanaged instance groups" | pv -qL 100
    echo "2. Add virtual machine images to unmanaged instance group" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ gcloud compute health-checks create http glbcdn-http-health-check --port 80 # to create healthcheck" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create glbcdn-video-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global # to create backend service" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services create glbcdn-html-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global # to create backend service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ gcloud compute health-checks create http glbcdn-http-health-check --port 80 # to create healthcheck" | pv -qL 100
    gcloud compute health-checks create http glbcdn-http-health-check --port 80
    echo
    echo "$ gcloud compute backend-services create glbcdn-video-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global # to create backend service" | pv -qL 100
    gcloud compute backend-services create glbcdn-video-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global # to create backend service
    echo
    echo "$ gcloud compute backend-services create glbcdn-html-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global # to create backend service" | pv -qL 100
    gcloud compute backend-services create glbcdn-html-backend-service --protocol HTTP --health-checks glbcdn-http-health-check --global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    echo
    echo "$ gcloud compute backend-services delete glbcdn-video-backend-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete glbcdn-video-backend-service --global
    echo
    echo "$ gcloud compute backend-services delete glbcdn-html-backend-service --global # to delete backend service" | pv -qL 100
    gcloud compute backend-services delete glbcdn-html-backend-service --global
else
    export STEP="${STEP},5i"
    echo
    echo "1. Configure healthcheck" | pv -qL 100
    echo "2. Configure backend service" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-us-central1-b --instance-group-zone us-central1-b --global # to create backend services" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-us-central1-b --instance-group-zone us-central1-b --global # to create backend services" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global # to create backend services" | pv -qL 100
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global # to create backend services" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-us-central1-b --instance-group-zone us-central1-b --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-us-central1-b --instance-group-zone us-central1-b --global
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-us-central1-b --instance-group-zone us-central1-b --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-us-central1-b --instance-group-zone us-central1-b --global
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbcdn-video-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-video-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global
    echo
    echo "$ gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global # to create backend services" | pv -qL 100
    gcloud compute backend-services add-backend glbcdn-html-backend-service --balancing-mode UTILIZATION --max-utilization 0.8 --capacity-scaler 1 --instance-group glbcdn-html-instance-group-europe-west1-b --instance-group-zone europe-west1-b --global
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},6i"
    echo
    echo "1. Add instance group to backend service" | pv -qL 100
    echo "2. Configure autoscaling" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ gcloud compute url-maps create glbcdn-www-url-map --default-service glbcdn-html-backend-service # to create URL maps" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --path-rules=\"/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service\" # to add a path matcher to your URL map" | pv -qL 100
    echo
    echo "$ gcloud compute target-http-proxies create glbcdn-target-http-proxy --url-map glbcdn-www-url-map # to create a target HTTP proxy to route requests to your URL map" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    echo
    echo "$ gcloud compute url-maps create glbcdn-www-url-map --default-service glbcdn-html-backend-service # to create URL maps" | pv -qL 100
    gcloud compute url-maps create glbcdn-www-url-map --default-service glbcdn-html-backend-service # to create URL maps
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --path-rules=\"/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service\" # to add a path matcher to your URL map" | pv -qL 100
    gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --path-rules="/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service"
    echo
    echo "$ gcloud compute target-http-proxies create glbcdn-target-http-proxy --url-map glbcdn-www-url-map # to create a target HTTP proxy to route requests to your URL map" | pv -qL 100
    gcloud compute target-http-proxies create glbcdn-target-http-proxy --url-map glbcdn-www-url-map
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    echo
    echo "$ gcloud compute target-http-proxies delete glbcdn-target-http-proxy # to deletetarget HTTP proxy" | pv -qL 100
    gcloud compute target-http-proxies delete glbcdn-target-http-proxy
    echo
    echo "$ gcloud compute url-maps delete glbcdn-www-url-map # to delete URL maps" | pv -qL 100
    gcloud compute url-maps delete glbcdn-www-url-map # to create URL maps
else
    export STEP="${STEP},7i"
    echo
    echo "1. Configure URL maps" | pv -qL 100
    echo "2. Add path matcher to URL map" | pv -qL 100
    echo "3. Create target HTTP proxy to route requests to URL map" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ gcloud compute addresses create glbcdn-ipv4-address --ip-version IPV4 --global # to create static IPV4 address" | pv -qL 100
    echo
    echo "$ gcloud compute forwarding-rules create glbcdn-forwarding-rule-ipv4 --address \$IPV4 --global --target-http-proxy glbcdn-target-http-proxy --ports 80 # to create IPV4 global forwarding rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    echo
    echo "$ gcloud compute addresses create glbcdn-ipv4-address --ip-version IPV4 --global # to create static IPV4 address" | pv -qL 100
    gcloud compute addresses create glbcdn-ipv4-address --ip-version IPV4 --global
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbcdn-ipv4-address')
    echo
    echo "$ gcloud compute forwarding-rules create glbcdn-forwarding-rule-ipv4 --address $IPV4 --global --target-http-proxy glbcdn-target-http-proxy --ports 80 # to create IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules create glbcdn-forwarding-rule-ipv4 --address $IPV4 --global --target-http-proxy glbcdn-target-http-proxy --ports 80
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    echo
    echo "$ gcloud compute forwarding-rules delete glbcdn-forwarding-rule-ipv4 --global # to delete IPV4 global forwarding rule" | pv -qL 100
    gcloud compute forwarding-rules delete glbcdn-forwarding-rule-ipv4 --global
    echo
    echo "$ gcloud compute addresses delete glbcdn-ipv4-address --global # to delete static IPV4 address" | pv -qL 100
    gcloud compute addresses delete glbcdn-ipv4-address --global
else
    export STEP="${STEP},8i"
    echo
    echo "1. Create static IPV4 address" | pv -qL 100
    echo "2. Create IPV4 global forwarding rule" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ gcloud compute firewall-rules create glbcdn-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16  --allow tcp:80 # to create firewall rule" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    echo
    echo "$ gcloud compute firewall-rules create glbcdn-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16  --allow tcp:80 # to create firewall rule" | pv -qL 100
    gcloud compute firewall-rules create glbcdn-allow-health-check --network default --source-ranges 130.211.0.0/22,35.191.0.0/16  --allow tcp:80
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "$ gcloud compute firewall-rules delete glbcdn-allow-health-check # to delete firewall rule" | pv -qL 100
    gcloud compute firewall-rules delete glbcdn-allow-health-check
else
    export STEP="${STEP},9i"
    echo
    echo "1. Configure firewall rule" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"
    echo
    echo "$ gcloud compute instances create glbcdn-europe-loadtest --network default --zone europe-west1-b --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
    echo
    echo "$ gcloud compute instances create glbcdn-us-loadtest --network default --zone us-central1-b  --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    echo
    echo "$ gcloud compute instances create glbcdn-europe-loadtest --network default --zone europe-west1-b --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
    gcloud compute instances create glbcdn-europe-loadtest --network default --zone europe-west1-b --provisioning-model=SPOT
    echo
    echo "$ gcloud compute instances create glbcdn-us-loadtest --network default --zone us-central1-b --provisioning-model=SPOT # to create siege load testing instance" | pv -qL 100
    gcloud compute instances create glbcdn-us-loadtest --network default --zone us-central1-b --provisioning-model=SPOT
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
    echo
    echo "$ gcloud compute instances delete glbcdn-us-loadtest --zone us-central1-b # to delete siege load testing instance" | pv -qL 100
    gcloud compute instances delete glbcdn-us-loadtest --zone us-central1-b
    echo
    echo "$ gcloud compute instances delete glbcdn-europe-loadtest --zone europe-west1-b # to delete siege load testing instance" | pv -qL 100
    gcloud compute instances delete glbcdn-europe-loadtest --zone europe-west1-b
else
    export STEP="${STEP},10i"
    echo
    echo "1. Create siege load testing instance" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"
    echo
    echo "$ gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/; done\" # to invoke service" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/video/; done\" # to invoke service" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/; done\" # to invoke service" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/video/; done\" # to invoke service" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbcdn-ipv4-address') > /dev/null 2>&1
    echo
    echo "$ gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://$IPV4/; done\" # to invoke service" | pv -qL 100
    gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null http://$IPV4/; done"
    sleep 10
    echo
    echo "$ gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://$IPV4/video/; done\" # to invoke service" | pv -qL 100
    gcloud compute ssh --quiet --zone us-central1-b glbcdn-us-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null http://$IPV4/video/; done"
    sleep 10
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://$IPV4/; done\" # to invoke service" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null http://$IPV4/; done"
    sleep 10
    echo
    echo "$ gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://$IPV4/video/; done\" # to invoke service" | pv -qL 100
    gcloud compute ssh --quiet --zone europe-west1-b glbcdn-europe-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null http://$IPV4/video/; done"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},11i"
    echo
    echo "1. Generate load" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"12")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},12i"
    echo
    echo "$ gsutil mb -l europe-west4 gs://\${GCP_PROJECT}-uig # to create bucket" | pv -qL 100
    echo 
    echo "$ gsutil iam ch allUsers:objectViewer gs://\${GCP_PROJECT}-uig # to make the bucket publicly accessible" | pv -qL 100
    echo
    echo "$ gsutil cp 20MB.zip gs://\${GCP_PROJECT}-uig/static/ # to copy files" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},12"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gsutil mb -l europe-west4 gs://${GCP_PROJECT}-uig # to create bucket" | pv -qL 100
    gsutil mb -l europe-west4 gs://${GCP_PROJECT}-uig
    echo 
    echo "$ gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT}-uig # to make the bucket publicly accessible" | pv -qL 100
    gsutil iam ch allUsers:objectViewer gs://${GCP_PROJECT}-uig
    echo
    echo "$ curl http://ipv4.download.thinkbroadband.com/20MB.zip -o $PROJDIR/20MB.zip # to download large file"
    curl http://ipv4.download.thinkbroadband.com/20MB.zip -o $PROJDIR/20MB.zip
    echo
    echo "$ gsutil cp $PROJDIR/20MB.zip gs://${GCP_PROJECT}-uig/static/ # to copy files" | pv -qL 100
    gsutil cp $PROJDIR/20MB.zip gs://${GCP_PROJECT}-uig/static/
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},12x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gcloud storage rm --recursive gs://${GCP_PROJECT}-uig # to delete bucket" | pv -qL 100
    gcloud storage rm --recursive gs://${GCP_PROJECT}-uig
else
    export STEP="${STEP},12i"
    echo
    echo "1. Create cloud storage bucket" | pv -qL 100
    echo "2. Make the bucket publicly accessible" | pv -qL 100
    echo "3. copy files to bucket" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"13")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},13i"
    echo
    echo "$ gcloud compute backend-buckets create glbcdn-static-backend-bucket --gcs-bucket-name ${GCP_PROJECT}-uig # to create backend bucket" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps remove-path-matcher glbcdn-www-url-map --path-matcher-name pathmap # to remove existing path matcher" | pv -qL 100
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --backend-bucket-path-rules '/static/*=glbcdn-static-backend-bucket' --backend-service-path-rules '/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service' # to create new path matcher" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},13"
    echo
    echo "$ gcloud compute backend-buckets create glbcdn-static-backend-bucket --gcs-bucket-name ${GCP_PROJECT}-uig # to create backend bucket" | pv -qL 100
    gcloud compute backend-buckets create glbcdn-static-backend-bucket --gcs-bucket-name ${GCP_PROJECT}-uig
    echo
    echo "$ gcloud compute url-maps remove-path-matcher glbcdn-www-url-map --path-matcher-name pathmap # to remove existing path matcher" | pv -qL 100
    gcloud compute url-maps remove-path-matcher glbcdn-www-url-map --path-matcher-name pathmap
    echo
    echo "$ gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --backend-bucket-path-rules '/static/*=glbcdn-static-backend-bucket' --backend-service-path-rules '/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service' # to create new path matcher" | pv -qL 100
    gcloud compute url-maps add-path-matcher glbcdn-www-url-map --default-service glbcdn-html-backend-service --path-matcher-name pathmap --backend-bucket-path-rules '/static/*=glbcdn-static-backend-bucket' --backend-service-path-rules '/video=glbcdn-video-backend-service,/video/*=glbcdn-video-backend-service'
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},13x"
    echo
    echo "$ gcloud compute url-maps remove-path-matcher glbcdn-www-url-map --path-matcher-name pathmap # to remove existing path matcher" | pv -qL 100
    gcloud compute url-maps remove-path-matcher glbcdn-www-url-map --path-matcher-name pathmap
    echo
    echo "$ gcloud compute backend-buckets delete glbcdn-static-backend-bucket # to delete backend bucket" | pv -qL 100
    gcloud compute backend-buckets delete glbcdn-static-backend-bucket
else
    export STEP="${STEP},13i"
    echo
    echo "1. Create backend bucket" | pv -qL 100
    echo "2. Remove existing path matcher" | pv -qL 100
    echo "3. Create new path matcher" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"14")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},14i"
    echo
    echo "$ gcloud compute backend-buckets update glbcdn-static-backend-bucket --enable-cdn # to enable CDN" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},14"
    echo
    echo "$ gcloud compute backend-buckets update glbcdn-static-backend-bucket --enable-cdn # to enable CDN" | pv -qL 100
    gcloud compute backend-buckets update glbcdn-static-backend-bucket --enable-cdn
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},14x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},14i"
    echo
    echo "1. Enable Cloud CDN" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"15")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},15i"
    echo
    echo "$ gcloud compute ssh --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/static/20MB.zip; done\" & # to generate load" | pv -qL 100
    echo
    echo "$ gcloud compute ssh --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://\$IPV4/static/20MB.zip; done\" & # to generate load" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},15"
    export IPV4=$(gcloud compute addresses list --format='value(ADDRESS)' --filter='name:glbcdn-ipv4-address') > /dev/null 2>&1
    echo
    echo "$ gcloud compute ssh --zone us-central1-b glbcdn-us-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null  http://$IPV4/static/20MB.zip; done\" & # to generate load" | pv -qL 100
    gcloud compute ssh --zone us-central1-b glbcdn-us-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null  http://$IPV4/static/20MB.zip; done" &
    echo && sleep 10
    echo "$ gcloud compute ssh --zone europe-west1-b glbcdn-europe-loadtest --command=\"for i in {1..10};do curl -s -w '%{time_total}\\\n' -o /dev/null http://$IPV4/static/20MB.zip; done\" & # to generate load" | pv -qL 100
    gcloud compute ssh --zone europe-west1-b glbcdn-europe-loadtest --command="for i in {1..10};do curl -s -w '%{time_total}\\n' -o /dev/null http://$IPV4/static/20MB.zip; done"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},15x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},15i"
    echo
    echo "1. Generate load" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done

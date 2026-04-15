
##############################################################################################################
Pipeline
#############################################################################################################

## We start off by installing Redis
## https://redis.io/docs/getting-started/installation/install-redis-on-mac-os/

# Show the Homebrew page

https://brew.sh/


# Switch over to the terminal window

# Make sure the font is a good large size
# Make sure the terminal is full screen
# Make sure that the command prompt does not show your name
# Add this to your .bash_profile export PS1="\[\e[34m\]\w\[\e[m\]>\n--> 
# to get the right prompt

brew --version

brew install redis

## Start the Redis Server (server starts in the foreground)
redis-server


## Stop the Redis server (we'll restart in the background)
Ctrl + C


## Start redis in the background

brew services start redis

## Check status of redis

brew services info redis


## Run the command-line client

redis-cli 



## Do a SET and GET to confirm the install
SET loonyKey loonyValue

GET loonyKey

LPUSH loonyList a b c

LPOP loonyList



############################
Installation on Linux
############################

## Start with a provisioned VM Instance on a cloud provider (e.g. GCP)
## The instance can be created with the following details:
name = redis-vm-instance
machine type = e2 micro
region = asia-south1 (Mumbai)


------------------ Start recording here

#-- Start on the VM instances page
#-- Click through and show the details of the VM created


## Assuming we start on the VM instances page with the instance up
## Click on SSH to bring up an SSH terminal

## IMPORTANT: Copy the URL of the SSH terminal and open up a new tab with 
## the SSH window (don't work on the small window that pops up by default)



## Update the package indexes
sudo apt-get update

## Download and install the latest version of Redis Server
sudo apt-get -y install redis-server

## Generate a password for connecting to the Redis server
## Make sure to save down the password - we'll use it later
openssl rand 60 | openssl base64 -A

## Assuming the password is Hw4A8QZXhROXhD9uMFDcRG6ueVlTz/RYlVX+50rirJld3Yj3ZUmbBb89uNKTVLivya4U/8jZjXZ/Gkmx


## Edit the redis.conf file to make two changes 
sudo nano /etc/redis/redis.conf

# in NETWORK section replace "bind 124.0.0.1 ::1" with
bind 0.0.0.0


# Ctrl + X to close the nano editor

# in the SECURITY section replace "# requirepass foobared" with following {generated using : openssl rand 60 | openssl base64 -A }

# Use Ctrl + W to search for "foobared" - will take you directly to the right place

# Make sure to uncomment out the line and put this in

requirepass Hw4A8QZXhROXhD9uMFDcRG6ueVlTz/RYlVX+50rirJld3Yj3ZUmbBb89uNKTVLivya4U/8jZjXZ/Gkmx

# Save and exit redis.conf file
sudo service redis-server restart

## Check the Redis server process
ps -f -u redis


## Store the password in the REDISCLI_AUTH environment variable 
export REDISCLI_AUTH=Hw4A8QZXhROXhD9uMFDcRG6ueVlTz/RYlVX+50rirJld3Yj3ZUmbBb89uNKTVLivya4U/8jZjXZ/Gkmx


## Pull up the Redis CLI from within the SSH window
redis-cli


## Do a SET and GET to confirm the install
SET loonyKey loonyValue

GET loonyKey

LPUSH loonyList a b c

LPOP loonyList

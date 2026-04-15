
##############################################################################################################
Pipeline with redis-cli
##############################################################################################################

## Have the redis-cli running in one terminal tab

## Open up a new terminal tab

## Create a workspace folder where the code can be placed
## Bring up a shell/terminal and run this command to create the folder and cd into it
mkdir -p ~/advancedredis && cd ~/advancedredis

## Behind the scenes store the pipeline_commands.txt in the current directory

## Run the command to show the presence of the file

ls -l 


# Open up pipeline_commands.txt in Sublimetext, show the contents

SET 01 iRzCY4ehheQpbGm
SET 02 OlLIWwKXBIL7rlt
SET 03 aaGN19SJkmrP6K9
SET 04 LYygSPJ6a2q7omJ
SET 05 udjSSYD47AjqHrt
HSET 100 name Nora                    
HSET 100 age 34
HSET 100 designation Director
HSET 100 department Engineering
HSET 100 company SomeCompany


## Head back to the shell/terminal
## Here, we use pipe mode for the upload
## https://redis.io/docs/manual/patterns/bulk-loading/
cat pipeline_commands.txt | redis-cli --pipe


# Go to the first tab where the redis-cli is running

GET 01
GET 05
HGET 100 name
HGETALL 100


##############################################################################################################
https://redis-py.readthedocs.io/en/stable/commands.html#redis-commands
##############################################################################################################
Pipeline with a Python client
##############################################################################################################

# On the second terminal window

# Start in the advancedredis/ directory with the following file 
# (remove any other file that might exist)

pipeline_python.py

## Run this command to show the file

ls -l


# Check python
python -V


# Install Python's Redis package
pip install redis


# IMPORTANT Show pipeline_python.py in sublimetext

# run the .py script
python pipeline_python.py


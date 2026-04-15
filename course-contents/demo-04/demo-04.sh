

##############################################################################################################
Pipeline with client and text file
##############################################################################################################

# Set up the following files in the current directory (do behind the scenes)
# (get rid of other files)

kv_pairs.txt
load_kvs.py

## Run this command to show the files
ls -l

# kv_pairs.txt content
100001,iRzCY4ehheQpbGm
100002,OlLIWwKXBIL7rlt
100003,aaGN19SJkmrP6K9
100004,LYygSPJ6a2q7omJ
100005,udjSSYD47AjqHrt
100006,KbMsHklYXwTME1j
100007,jqsKq8Amj7I9Ujk
100008,8nyD2DMNlmP4xys
100009,sGpo6rzUdWNjZkL
100010,ESrYEFGKa3J0WIa


# Open up load_kvs.py in sublimetext and show the code


# run .py file

python load_kvs.py


# Stop the redis service

brew services stop redis 

# Should see a success message


---------------------------------------- NOT for RECORDING

In case if issues and you need to re-run the code

## Just in case you run into issues, you can remove the KV pairs created
##      in this demo by running the command below from the redis-cli
DEL 100001 100002 100003 100004 100005 100006 100007 100008 100009 100010
DEL KVPairs



## To conclude the demo, exit the Redis CLI by switching to the terminal
##      tab where it is up, and running this
exit

## Also, turn off the Redis server by switching to the shell where that 
##      is running, and terminating the process by hitting
Ctrl + C

## If the above doesn't work, open up a new shell/terminal and 
##		find the process to terminate it
## Use the ps command to find all Redis-related processes
ps -ef | grep redis

## One of the entries will look something like the line below
501 64180 62575   0 Mon11AM ttys001    0:45.69 redis-server *:6379

## The second number is the process ID. Use it to kill (terminate) redis-server
kill 64180



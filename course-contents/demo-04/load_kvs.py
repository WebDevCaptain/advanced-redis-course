import redis
import time

redisObj = redis.Redis(host="localhost", port=6379, db=0)
pipeObj = redisObj.pipeline()

txtFile = open("kv_pairs.txt")
lines = txtFile.readlines()

for line in lines:
    
    kv = line.split(',')
    
    pipeObj.set(kv[0], kv[1])

    print("SET result: ", redisObj.get(kv[0]))

    pipeObj.hset("KVPairs", kv[0], kv[1])

    print("HGET result:", redisObj.hget("KVPairs", kv[0]))

pipeObj.execute()

print("\n\nAfter pipeline execution...")

print("\nGET 100001:", redisObj.get("100001"))

print("GET 100007:", redisObj.get("100007"))

print("\nHGETALL KVPairs:", redisObj.hgetall("KVPairs"), "\n")
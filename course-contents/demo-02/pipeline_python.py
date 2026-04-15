import redis
import time

redisObj = redis.Redis(host='localhost', port=6379, db=0)
pipeObj = redisObj.pipeline()

pipeObj.set("Name", "Jack")
pipeObj.set("a", 10)
pipeObj.set("b", 10)
pipeObj.set("p", 10)
pipeObj.set("q", 10)
pipeObj.set("n", 10)

pipeObj.execute()

print("\n----------------------Original Values")
print("Name: ", redisObj.get("Name"))
print("a: ", redisObj.get("a"))
print("b: ", redisObj.get("b"))
print("p: ", redisObj.get("p"))
print("q: ", redisObj.get("q"))
print("n: ", redisObj.get("n"))

pipeObj.append("Name", " Jonas")
pipeObj.incr("a")
pipeObj.incrby("b",3)
pipeObj.incrbyfloat("p",0.5)
pipeObj.delete("q")

print("\n----------------------Updating")

pipeObj.execute()

print("\n----------------------Updated Values")

print("APPEND Name Jonas: ", redisObj.get("Name"))
print("INCR a: ", redisObj.get("a"))
print("INCRBY b 3: ", redisObj.get("b"))
print("INCRBYFLOAT p 0.5: ", redisObj.get("p"))
print("DELETE q: ", redisObj.get("q"))
print("(No op) n: ", redisObj.get("n"))


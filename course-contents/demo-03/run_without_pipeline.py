import redis
import time


def run_without_pipelining():
	redisObj = redis.Redis(host='localhost', port=6379, db=0)

	redisObj.set('without_pipeline', 0)
	
	start = time.time()

	for i in range(100000):
		redisObj.incr('without_pipeline')

	print("Time taken (run_without_pipelining): ", time.time() - start)	

	print("without_pipeline counter value: ", redisObj.get("without_pipeline"))


if __name__ == "__main__":
    run_without_pipelining()
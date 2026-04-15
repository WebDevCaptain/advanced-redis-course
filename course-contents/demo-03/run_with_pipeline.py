import redis
import time


def run_with_pipelining():
	redisObj = redis.Redis(host='localhost', port=6379, db=0)
	pipeObj = redisObj.pipeline()

	redisObj.set('with_pipeline', 0)
	
	start = time.time()

	for i in range(100000):
		pipeObj.incr('with_pipeline')

	pipeObj.execute()

	print("Time taken (run_with_pipelining): ", time.time() - start)	

	print("with_pipeline counter value: ", redisObj.get("with_pipeline"))


if __name__ == "__main__":
    run_with_pipelining()
# Redis Complete Guide

This guide covers Redis from fundamentals to advanced usage with clear explanations and practical examples.

---

## Table of Contents
1. [Strings](#1-strings-basic-key-value)
2. [Hashes](#2-hashes-objects)
3. [Sets](#3-sets-unique-unordered)
4. [Sorted Sets](#4-sorted-sets-unique--ordered)
5. [Lists](#5-lists-ordered-queuestack)
6. [HyperLogLog](#6-hyperloglog-unique-count---estimate)
7. [Bitmaps](#7-bitmaps-yesno-per-position)
8. [Streams](#8-streams-message-log)
9. [Transactions](#9-transactions)
10. [Pipelining](#10-pipelining-batch-commands)
11. [Lua Scripts](#11-lua-scripts)
12. [Distributed Locks](#12-distributed-lock)
13. [RediSearch](#13-redisearch-full-text-search)
14. [RedisJSON - JSON Data](#14-redisjson---json-data)
15. [Redis Stack vs Redis Core](#15-redis-stack-vs-redis-core)
16. [Module Loading](#16-module-loading)
17. [Key Design Patterns](#17-common-key-patterns)
18. [Redis Performance - Why It's Fast](#18-redis-performance---why-its-fast)
19. [Redis Configuration](#19-redis-configuration)
20. [Expiration](#20-expiration)
21. [Pub/Sub](#21-pubsub-publishsubscribe)
22. [SORT Command](#22-sort-command)
23. [Redis Sentinel - High Availability](#23-redis-sentinel---high-availability)
24. [Redis Cluster - Horizontal Scaling](#24-redis-cluster---horizontal-scaling)
25. [Redis Persistence - RDB and AOF](#25-redis-persistence---rdb-and-aof)
26. [Common Redis Gotchas and Edge Cases](#26-common-redis-gotchas-and-edge-cases)
27. [SCAN Operations](#scan-operations-iterating-large-data)

---

## 1. Strings (Basic Key-Value)

### What it is
Strings are the most basic Redis data type - a simple key-value pair where the value is a string (or anything convertible to string like numbers, JSON, etc.).

### When to use
- Caching data (HTML, JSON, serialized objects)
- Storing simple values (flags, counters)
- Session data
- Configuration values

### Commands explained

**SET/GET - The foundation**
```redis
SET user:1:name "Alice"
GET user:1:name
```
`SET` overwrites any existing value. There's no "update" - just "set".

**SET with options**
```redis
SET user:1:token "abc123" EX 3600 NX
```
- `EX 3600` - Expires in 3600 seconds (1 hour)
- `NX` - Only set if key doesn't exist (useful for distributed locks)
- `XX` - Only set if key already exists
- Can combine: `SET key value EX 60 NX`

**MSET/MGET - Batch operations**
```redis
MSET user:1:name "Alice" user:1:age "25" user:1:city "NYC"
MGET user:1:name user:1:age user:1:city
```
Use these when you need to read/write multiple keys. Reduces network round-trips.

**INCR/DECR - Atomic counters**
```redis
SET counter 10
INCR counter           # Returns 11 (automatically +1)
DECR counter           # Returns 10
INCRBY counter 5       # Returns 15
DECRBY counter 3       # Returns 12
```
These operations are atomic - safe to use concurrently without race conditions. Redis handles the read-increment-write internally.

**APPEND - String concatenation**
```redis
SET greeting "Hello"
APPEND greeting " World"   # Now greeting = "Hello World"
APPEND greeting "!"         # Now greeting = "Hello World!"
```
Returns the new string length.

**GETRANGE/SETRANGE - Substring operations**
```redis
SET word "abcdef"
GETRANGE word 0 2          # Returns "abc" (inclusive indices)
GETRANGE word -3 -1        # Returns "def" (negative = from end)

SET word "XXXXXX" OFFSET 2 "abc"  # word now = "XXabcX"
```
Negative indices count from the end (-1 = last character).

### Real example: Cache a user profile
```redis
SET cache:user:123 '{"name":"Alice","email":"alice@example.com","created":"2024-01-01"}' EX 300
GET cache:user:123
```
Store serialized JSON with 5-minute TTL. When cache misses, fetch from database and populate Redis.

---

## 2. Hashes (Objects)

### What it is
Hashes store field-value pairs, similar to a JSON object or database row. Perfect for representing structured objects.

### When to use
- User profiles
- Database rows cached in Redis
- Configuration objects
- Any object with multiple properties

### Commands explained

**HSET/HGET - Basic operations**
```redis
HSET user:1 name "Alice" email "alice@example.com" age "28"
```
`HSET` can set multiple fields in one command. Returns number of fields added (not values).

```redis
HGET user:1 name                    # Returns "Alice"
HMGET user:1 name email             # Returns ["Alice", "alice@example.com"]
```

**HGETALL - Get everything**
```redis
HGETALL user:1
```
Returns all fields and values as alternating key-value list:
```
1) "name"
2) "Alice"
3) "email"
4) "alice@example.com"
5) "age"
6) "28"
```
This is both a strength (get everything in one call) and weakness (expensive for large hashes).

**HINCRBY - Numeric fields**
```redis
HSET user:1 points "100"
HINCRBY user:1 points 50            # Returns 150 (new value)
HINCRBY user:1 points -20           # Returns 130
```
Works like INCR but on a hash field. Useful for counters like "points", "loginCount", etc.

**HDEL - Delete fields**
```redis
HDEL user:1 age                     # Returns 1 (deleted 1 field)
HDEL user:1 age city                # Can delete multiple
```
Unlike DEL which deletes the entire key, HDEL removes specific fields.

**HEXISTS - Check field existence**
```redis
HEXISTS user:1 email               # Returns 1 (exists)
HEXISTS user:1 bio                 # Returns 0 (doesn't exist)
```

**HSCAN - Iterate large hashes**
```redis
HSCAN user:1 MATCH age:* COUNT 10
```
For hashes with thousands of fields, don't use HGETALL. Use HSCAN to iterate incrementally.

### Real example: E-commerce product
```redis
HSET product:100 name "Laptop Pro" price "1299" stock "50" category "electronics"
HINCRBY product:100 stock -1           # Decrement stock atomically
HGET product:100 stock                 # Check remaining stock
```

---

## 3. Sets (Unique, Unordered)

### What it is
Sets store unique values with no particular order. Each member must be unique - adding duplicates has no effect.

### When to use
- Tags (unique tags per item)
- Followers/following lists
- Preventing duplicate processing
- Set operations (intersection, union)

### Commands explained

**SADD/SMEMBERS - Add and get**
```redis
SADD post:42:tags "redis" "tutorial" "beginner"
SMEMBERS post:42:tags
```
Returns all members in arbitrary order. No duplicates possible.

**SISMEMBER - Check membership**
```redis
SISMEMBER post:42:tags "redis"        # Returns 1 (yes, member)
SISMEMBER post:42:tags "advanced"     # Returns 0 (no)
```
Fast O(1) lookup - great for checking if user already liked a post, etc.

**SCARD - Count members**
```redis
SCARD post:42:tags                    # Returns 3
```
Counts unique members. Faster than `SMEMBERS + LENGTH`.

**SREM - Remove members**
```redis
SREM post:42:tags "beginner"         # Returns 1 (removed)
SREM post:42:tags "beginner"         # Returns 0 (already gone)
```

### Set Operations (the real power)

**SINTER - Intersection**
```redis
SADD users:laptop "alice" "bob" "charlie" "dave"
SADD users:phone "charlie" "dave" "eve" "frank"

SINTER users:laptop users:phone
```
Returns members present in BOTH sets: `charlie`, `dave`

**SUNION - Union**
```redis
SUNION users:laptop users:phone
```
Returns all unique members from both: `alice`, `bob`, `charlie`, `dave`, `eve`, `frank`

**SDIFF - Difference**
```redis
SDIFF users:laptop users:phone
```
Returns members in first set but NOT in second: `alice`, `bob`

**Store results**
```redis
SINTERSTORE users:both users:laptop users:phone
SUNIONSTORE users:all users:laptop users:phone
SDIFFSTORE users:laptop-only users:laptop users:phone
```
These store the result into a new key instead of returning it.

### Real example: User likes
```redis
SADD post:42:likes "user:1" "user:2" "user:3"
SISMEMBER post:42:likes "user:2"     # Check if user liked
SADD post:42:likes "user:4"          # Add new like
SCARD post:42:likes                  # Total likes count
```

---

## 4. Sorted Sets (Unique + Ordered)

### What it is
Sorted sets are like sets but each member has an associated score. Members are automatically sorted by score. This is one of Redis's most powerful data types.

### When to use
- Leaderboards/rankings
- Trending content (sorted by time + score)
- Auto-sorted feeds
- Priority queues

### Commands explained

**ZADD - Add with scores**
```redis
ZADD leaderboard 1500 "player1" 2300 "player2" 800 "player3"
```
Scores can be any number (integers, floats, negative). Members are unique like sets.

**ZRANGE/ZREVRANGE - Get by position**
```redis
ZRANGE leaderboard 0 4 WITHSCORES           # Lowest to highest
ZREVRANGE leaderboard 0 4 WITHSCORES         # Highest to lowest
```
- `0 4` means first 5 elements (start index, stop index)
- `-1` means last element
- `WITHSCORES` includes the score in results

**ZRANGEBYSCORE - Get by score range**
```redis
ZRANGEBYSCORE leaderboard 1000 2000         # Score between 1000 and 2000
ZRANGEBYSCORE leaderboard 1000 +inf         # Score >= 1000
ZRANGEBYSCORE leaderboard -inf 1000         # Score <= 1000
```
`+inf` and `-inf` represent infinity.

**ZRANK/ZREVRANK - Get member's position**
```redis
ZRANK leaderboard "player1"                 # Returns 2 (0-based, low to high)
ZREVRANK leaderboard "player1"              # Returns 1 (0-based, high to low)
```
Useful for showing "You are ranked #3" in leaderboards.

**ZINCRBY - Update scores**
```redis
ZINCRBY leaderboard 500 "player1"           # Adds 500 to player1's score
ZINCRBY leaderboard -100 "player3"         # Decreases by 100
```
Perfect for games - just add/subtract points without needing the current score.

**ZSCORE - Get single member's score**
```redis
ZSCORE leaderboard "player1"                # Returns "1500"
```

### Real example: Trending posts
```redis
# Add posts with score = (views * recency_factor)
ZADD trending:posts 950 "post:1"
ZADD trending:posts 1200 "post:2"
ZADD trending:posts 750 "post:3"

# Get top 10 trending
ZREVRANGE trending:posts 0 9 WITHSCORES

# User just viewed a post - increment score
ZINCRBY trending:posts 10 "post:1"
```

### Real example: Time-series leaderboard
```redis
# Weekly leaderboard - use Unix timestamp as score
ZADD leaderboard:week:2024-01 1704700800 "player1"
ZINCRBY leaderboard:week:2024-01 100 "player1"

# Get top for this week
ZREVRANGE leaderboard:week:2024-01 0 9 WITHSCORES
```

---

## 5. Lists (Ordered, Queue/Stack)

### What it is
Lists are ordered collections that support insertion and deletion at both ends. Think of it as a queue (FIFO) or stack (LIFO).

### When to use
- Message queues
- Activity feeds (recent items)
- Task processing pipelines
- Chat messages

### Commands explained

**RPUSH/LPUSH - Add to list**
```redis
RPUSH queue:emails "email:1" "email:2" "email:3"
LPUSH recent:searches "query:c" "query:b" "query:a"
```
- RPUSH adds to the RIGHT (end)
- LPUSH adds to the LEFT (front)

**LRANGE - Get range**
```redis
LRANGE queue:emails 0 -1               # Get all
LRANGE queue:emails 0 4                 # First 5
LRANGE queue:emails -3 -1               # Last 3
```
- Index 0 = first element
- -1 = last element
- -2 = second to last

**LPOP/RPOP - Remove from list**
```redis
LPOP queue:emails                      # Remove from left (first)
RPOP queue:emails                      # Remove from right (last)
```

### Blocking operations (for queues)

```redis
BLPOP queue:emails 0                   # Wait until something available
BRPOP queue:emails 0                   # Same but from right
```
The `0` means wait forever. You can use `BLPOP queue 5` to wait max 5 seconds.

**Why use blocking?**
```
Without BLPOP:  Client must loop, checking constantly (wasteful)
With BLPOP:    Server notifies client when item arrives (efficient)
```

**LTRIM - Keep only certain range**
```redis
LPUSH user:100:activity "item1" "item2" "item3" "item4" "item5"
LTRIM user:100:activity 0 9            # Keep only first 10 items
```
Useful for "keep last 100 messages" patterns. Combined with LPUSH for recent activity logs.

### Real example: Job queue
```redis
# Producer adds job
RPUSH jobs:process "task:123" "task:124" "task:125"

# Consumer processes
LPOP jobs:process                      # Returns "task:123", processes it
LPOP jobs:process                      # Returns "task:124"
```

### Real example: Recent items feed
```redis
LPUSH user:42:feed "post:100" "post:99" "post:98"
LTRIM user:42:feed 0 49               # Keep only last 50 posts
LRANGE user:42:feed 0 9                # Show recent 10 on profile
```

---

## 6. HyperLogLog (Unique Count - Estimate)

### What it is
HyperLogLog is a probabilistic data structure that estimates the number of unique items (cardinality) with only ~12KB of memory, regardless of how many items you track.

### When to use
- Counting unique visitors
- Unique searches per day
- Any scenario where exact count isn't critical but memory matters

### Why this exists

**Problem:** Using a Set to count 1 billion unique items requires enormous memory.

**Solution:** HyperLogLog uses ~12KB regardless of count, with ~0.81% error margin.

Is 99.19% accuracy good enough? For analytics like "unique visitors" - yes!

### Commands explained

**PFADD - Add items**
```redis
PFADD visitors:today "session:1" "session:2" "session:1"
PFADD visitors:today "session:3"
```
"PF" stands for "Peter Flajolet" (inventor). Duplicates are automatically ignored - only unique items matter.

**PFCOUNT - Get estimate**
```redis
PFCOUNT visitors:today                 # Returns ~3
```
Returns estimated cardinality. The more items added, the more accurate.

**PFMERGE - Combine**
```redis
PFADD day1 "a" "b" "c"
PFADD day2 "c" "d" "e"
PFMERGE combined day1 day2
PFCOUNT combined                      # Returns ~5 (unique across both)
```
Merges multiple HyperLogLogs - counts unique across all.

### Key points
- Cannot retrieve individual items (unlike Set)
- Cannot check if specific item exists
- Only counts unique items (approximate)
- Merging is supported (unlike Sets)
- Memory: 12KB fixed, independent of count

---

## 7. Bitmaps (Yes/No per position)

### What it is
Bitmaps store a sequence of bits where each bit represents a binary yes/no value for a specific offset. Extremely memory-efficient for boolean data.

### When to use
- Daily active users
- User check-in/checkout tracking
- Feature flags per user
- Attendance tracking
- User actions on specific days

### Why this exists

**Problem:** Storing "user X visited today" as a string uses lots of memory.

**Solution:** Each user ID maps to a single bit. 1 million users × 1 bit = ~125KB.

### Commands explained

**SETBIT/GETBIT - Basic operations**
```redis
SETBIT active:2024-01-15 12345 1
GETBIT active:2024-01-15 12345
```
- `SETBIT key offset value` - offset is the position (0-based)
- Value must be 0 or 1
- If offset is beyond current length, Redis expands automatically

**BITCOUNT - Count set bits**
```redis
SETBIT active:2024-01-15 100 1
SETBIT active:2024-01-15 200 1
SETBIT active:2024-01-15 300 1
BITCOUNT active:2024-01-15              # Returns 3
```
Count how many bits are set to 1 - perfect for "daily active users".

**BITOP - Combine bitmaps**
```redis
SETBIT users:jan1 100 1
SETBIT users:jan1 200 1
SETBIT users:jan2 200 1
SETBIT users:jan2 300 1

BITOP AND users:both users:jan1 users:jan2
BITCOUNT users:both                    # Returns 1 (only user 200)
```
- `AND` - both days
- `OR` - either day
- `XOR` - only one day, not both

**BITPOS - Find first bit**
```redis
SETBIT mybitmap 10 1
BITPOS mybitmap 0                      # Returns 0 (first 0 bit)
BITPOS mybitmap 1                      # Returns 10 (first 1 bit)
```

### Real example: Daily active users
```redis
# User 12345 visited today
SETBIT daily:2024-01-15 12345 1

# User 67890 visited today
SETBIT daily:2024-01-15 67890 1

# How many unique visitors today?
BITCOUNT daily:2024-01-15              # Returns 2
```

### Real example: User login streaks
```redis
# User logged in on days 1, 3, 5
SETBIT user:123:logins 1 1
SETBIT user:123:logins 3 1
SETBIT user:123:logins 5 1

# Check if they logged in on day 4
GETBIT user:123:logins 4              # Returns 0
```

### Real example: Attendance tracking
```redis
# Mark user attended on day 0-6 (week)
SETBIT event:meetup:2024 5 1    # User 5 attended

# Count total attendees
BITCOUNT event:meetup:2024

# Combine two events
BITOP OR both_events event:meetup:2024 event:meetup:2025
```

### Memory calculation
- 1 million users = 125KB
- 10 million users = 1.25MB
- 100 million users = 12.5MB

Compare to using strings: 100 million strings would be gigabytes!

---

## 8. Streams (Message Log)

### What it is
Streams are append-only message logs with unique IDs. They're like a durable, ordered message queue with consumer group support - the foundation for event-driven architectures.

### When to use
- Event sourcing
- Message queues (replacing RabbitMQ/Kafka for simpler cases)
- Activity logs
- Real-time dashboards
- Order processing pipelines
- Service-to-service communication

### Why this exists

Lists and Sets can't:
- Provide unique message IDs
- Re-read old messages after processing
- Support multiple workers (consumer groups)
- Remember where each worker left off

---

### Basic Stream Operations

**XADD - Add messages**
```redis
XADD orders "*" orderId "123" amount "99" status "pending"
```
- The `*` auto-generates a unique ID (format: `<timestamp>-<sequence>`)
- You can specify ID: `XADD orders "1704700800000-0" ...`
- Fields are like a hash (key-value pairs)
- Auto-generated IDs are always increasing, so messages are time-ordered

**XLEN - Stream length**
```redis
XLEN orders                      # Returns number of messages
```

**XDEL - Delete specific message**
```redis
XDEL orders 1704700800000-0      # Delete specific message by ID
```

**XTRIM - Trim stream to max size**
```redis
XTRIM orders MAXLEN 1000          # Keep only last 1000 messages
XTRIM orders MINID 1704700800000-0  # Keep messages after this ID
```

**XRANGE - Read messages**
```redis
XRANGE orders - + COUNT 10       # Get first 10 messages
XRANGE orders - +                # Get all messages
XRANGE orders 1704700800000-0 1704700801000-0  # By ID range
```
- `-` means start of stream
- `+` means end of stream
- Returns messages with IDs and fields

**XREAD - Read from position**
```redis
XREAD COUNT 2 STREAMS orders 1704700800000-0
```
Read messages AFTER the specified ID. Useful for "give me new messages since last read".

**XREAD with blocking**
```redis
XREAD BLOCK 5000 COUNT 1 STREAMS orders $
```
- `BLOCK 5000` - Wait up to 5 seconds for new messages
- `$` means "only new messages" (not past)

---

### The Problem: Standard Streams

When you use basic XREAD/XRANGE, there's two major issues:

**Problem 1: All consumers get ALL messages**
```
Worker 1 → XREAD → sees ALL messages
Worker 2 → XREAD → sees ALL messages (duplicate!)
Worker 3 → XREAD → sees ALL messages (duplicate!)

→ If sending emails: DUPLICATE EMAILS SENT!
```

**Problem 2: No handling for crashed workers**
```
Worker receives message → starts processing → CRASHES!
→ We don't know if email was sent or not
→ Message is lost forever (or stuck)
```

---

### Solution: Consumer Groups

Consumer groups solve BOTH problems:

1. **Each message goes to ONE worker** (not all)
2. **Unacknowledged messages can be re-delivered** (if worker crashes)

**How it works:**
- A consumer group is a named group of workers
- Each worker in the group has a unique name
- Redis tracks which message was delivered to which worker
- If worker doesn't acknowledge, message stays "pending"
- Pending messages can be claimed by other workers

### Creating Consumer Groups

**XGROUP CREATE**
```redis
XGROUP CREATE orders processors 0
XGROUP CREATE orders processors 1704700800000-0   # Start from specific ID
```
- `0` means start from beginning of stream
- Can specify a starting ID (skip old messages)
- Group name: `processors`
- Stream name: `orders`

### Reading with Consumer Groups

**XREADGROUP - Claim messages**
```redis
XREADGROUP GROUP processors worker1 COUNT 5 STREAMS orders >
```

Key parts:
- `GROUP processors` - Use this group
- `worker1` - This worker's name
- `>` means "new messages not yet delivered to anyone in this group"
- Each message goes to ONE worker only!

**Different from basic XREAD:**
```redis
XREAD STREAMS orders $           # Gets ALL new messages (problem!)
XREADGROUP GROUP g worker >     # Gets ONE message per worker (solution!)
```

### Pending Messages

When a worker receives a message but doesn't acknowledge, it becomes "pending":

**XPENDING - Check pending messages**
```redis
XPENDING orders processors                    # Summary
XPENDING orders processors START 0 END 10    # Detailed
XPENDING orders processors IDLE 5000         # Messages idle > 5 seconds
```

Shows:
- How many messages are pending
- Which worker has which messages
- How long messages have been pending

### Acknowledging Messages

**XACK - Mark as processed**
```redis
XACK orders processors 1704700800000-0
```
After successful processing, acknowledge the message so:
- It won't be re-delivered
- It won't count as pending anymore

**Full workflow:**
```
1. XREADGROUP → get message (becomes pending)
2. Process message (send email, etc.)
3. XACK → mark as done (removes from pending)
```

### Claiming Pending Messages (For Crashed Workers)

If a worker crashes, its pending messages can be claimed by other workers:

**XCLAIM - Transfer ownership**
```redis
XCLAIM orders processors worker2 0 1704700800000-0
```
- Transfer message to worker2
- `0` = transfer immediately (no idle time requirement)
- Now worker2 can process it

**XAUTOCLAIM - Auto-claim idle messages**
```redis
XAUTOCLAIM orders processors worker3 0 60000 count 10
```
- Automatically claim messages idle for 60 seconds
- Transfer to worker3
- Get up to 10 messages

### Inspecting Consumer Groups

**XINFO GROUPS - List groups on stream**
```redis
XINFO GROUPS orders
```

**XINFO CONSUMERS - List consumers in group**
```redis
XINFO CONSUMERS orders processors
```

Shows:
- Consumer name
- Pending message count
- Last time they got a message

### Real Example: Email Processing Pipeline

```redis
# Producer: Order service adds order
XADD orders "*" orderId "ORD-123" customer "alice@example.com" total "150"

# Create consumer groups for different stages
XGROUP CREATE orders payment 0
XGROUP CREATE orders fulfillment 0

# Payment worker (worker1) gets order
XREADGROUP GROUP payment worker1 COUNT 1 STREAMS orders >
# Returns: 1704700800000-0, {orderId: ORD-123, customer: alice...}

# Process payment...
# If success:
XACK orders payment 1704700800000-0

# Fulfillment worker gets order
XREADGROUP GROUP fulfillment worker1 COUNT 1 STREAMS orders >
# Returns: 1704700800000-0 (same message, different group!)

# Ship order...
XACK orders fulfillment 1704700800001-0
```

### What if Worker Crashes?

```
1. Worker1 gets message via XREADGROUP → message is PENDING
2. Worker1 starts processing → CRASH (before XACK)
3. Message stays PENDING forever!

Solution:
- Use XPENDING to see stuck messages
- Use XCLAIM to transfer to another worker
- Or use XAUTOCLAIM to auto-claim idle messages
```

---

### Commands Summary

| Command | Purpose |
|---------|---------|
| `XADD` | Add message |
| `XRANGE` | Read messages (all consumers) |
| `XREAD` | Read from position |
| `XREAD BLOCK` | Blocking read |
| `XGROUP CREATE` | Create consumer group |
| `XREADGROUP` | Read with group (one message per worker) |
| `XACK` | Acknowledge processed message |
| `XPENDING` | Check pending messages |
| `XCLAIM` | Manually transfer message ownership |
| `XAUTOCLAIM` | Auto-claim idle messages |
| `XINFO GROUPS` | List groups |
| `XINFO CONSUMERS` | List consumers in group |

---

## 9. Transactions

### What it is
Transactions group multiple commands that execute atomically - either all succeed or none execute.

### The problem they solve
```redis
DECR inventory:product:100
SET order:123 status "confirmed"
```
If server crashes between these, you have inconsistent state (order confirmed but inventory not decremented).

### Commands explained

**MULTI/EXEC**
```redis
MULTI
DECR inventory:product:100
SET order:123 status "confirmed"
EXEC
```
- MULTI starts transaction mode
- Commands are queued, not executed
- EXEC runs all queued commands
- Returns array of results

**DISCARD**
```redis
MULTI
SET key "value"
DISCARD                           # Cancels transaction, queues cleared
```

### WATCH - Optimistic Locking

WATCH monitors keys - if they change before EXEC, the transaction fails.

```redis
WATCH product:100:stock
GET product:100:stock             # Returns 5

# Another client can do: DECR product:100:stock here

MULTI
DECR product:100:stock
EXEC                             # FAILS! Stock changed since WATCH
```

On failure, retry with fresh data.

**UNWATCH** - Stop watching
```redis
UNWATCH                          # Stop monitoring all keys
```

### Important notes

- Redis transactions are NOT like database ACID
- No automatic rollback on errors (individual commands fail individually)
- WATCH provides optimistic locking, not pessimistic
- Commands inside transaction execute sequentially (not parallel)

---

## 10. Pipelining (Batch Commands)

### What it is
Pipelining sends multiple commands to Redis without waiting for each response, then collects all responses at once.

### Why it matters

**Normal approach:**
```
Request 1 → Wait → Response 1 → Request 2 → Wait → Response 2
Total time = N × round-trip time
```

**Pipelined:**
```
Request 1 → Request 2 → Request 3 → Wait → Response 1,2,3
Total time = 1 × round-trip time
```

### Commands explained

In CLI, use pipeline by grouping commands:
```bash
echo -e "SET k1 v1\nSET k2 v2\nGET k1\nGET k2" | redis-cli
```

In code (Node.js):
```javascript
const pipeline = redis.pipeline();
pipeline.set('key1', 'value1');
pipeline.set('key2', 'value2');
pipeline.get('key1');
pipeline.get('key2');

const results = await pipeline.exec();
// results[0] = [null, 'OK'] (SET returns null error, 'OK' value)
// results[1] = [null, 'OK']
// results[2] = [null, 'value1']
// results[3] = [null, 'value2']
```

### When to use
- Bulk writes (migration, initialization)
- Batch reads (load initial data)
- Warm-up operations

### When NOT to use
- Single commands (adds overhead)
- Dependent commands where you need result before next command

---

## 11. Lua Scripts

### What it is
Lua scripts run logic directly on the Redis server, combining multiple operations atomically in a single call.

### Why use scripts

**Without scripts:**
```redis
GET counter           # Round-trip 1
INCR counter          # Round-trip 2
GET counter           # Round-trip 3
```

**With scripts:**
```redis
EVAL "local c = redis.call('INCR', KEYS[1]); return c" 1 counter
```
One round-trip!

### Commands explained

**EVAL - Run script**
```redis
EVAL "return redis.call('GET', KEYS[1])" 1 mykey
```
- Script is Lua code
- `KEYS[1]` = first key argument (the "1" means 1 key)
- `ARGV[1]` = first non-key argument

**More examples:**
```redis
EVAL "return redis.call('INCR', KEYS[1])" 1 counter

EVAL "redis.call('SET', KEYS[1], ARGV[1]); return 'OK'" 1 temp "value"

EVAL "if redis.call('EXISTS', KEYS[1]) == 0 then return redis.call('SET', KEYS[1], ARGV[1]) else return 'EXISTS' end" 1 mykey "value"
```

### Atomicity
Scripts execute atomically - no other commands run during execution. This is perfect for "check-then-update" patterns that would otherwise have race conditions.

### Real example: Atomic rate limiter
```lua
-- KEYS[1] = rate limit key
-- ARGV[1] = current timestamp
-- ARGV[2] = max requests per window

local current = redis.call('INCR', KEYS[1])
if current == 1 then
    redis.call('EXPIRE', KEYS[1], 60)
end
if current > tonumber(ARGV[2]) then
    return 0
else
    return 1
end
```

---

## 12. Distributed Lock

### What it is
A mechanism to ensure only one process can execute a critical section at a time across multiple servers.

### When to use
- Prevent double-processing of payments
- Ensure only one worker processes a task
- Distributed mutex for critical sections
- Inventory management

### The problem
```redis
GET product:100:stock        # Returns 1
-- Another process could also read 1 here!
DECR product:100:stock
```
Two processes both think there's stock, both decrement → negative inventory!

### Commands explained

**Basic lock (SETNX)**
```redis
SET lock:order:123 "worker1" NX EX 30
```
- SET with NX (only if not exists) = atomic lock
- EX 30 = auto-expire after 30 seconds (prevents dead locks)

**Release lock**
```redis
DEL lock:order:123
```
Delete the key to release.

### Problem: Accidental unlock
What if worker takes 30 seconds, lock expires, another worker grabs it, then first worker finishes and deletes the wrong lock?

### Solution: Lock value
```redis
-- Acquire with unique value
SET lock:order:123 "worker1:timestamp" NX EX 30

-- Release only if you own it
-- Use Lua script for atomic check + delete
EVAL "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end" 1 lock:order:123 "worker1:timestamp"
```

### Real example: Safe inventory decrement
```lua
-- KEYS[1] = lock key
-- KEYS[2] = inventory key

local lock = redis.call('SET', KEYS[1], ARGV[1], 'NX', 'EX', 30)
if not lock then
    return 'LOCKED'
end

local stock = tonumber(redis.call('GET', KEYS[2]))
if stock > 0 then
    redis.call('DECR', KEYS[2])
    redis.call('DEL', KEYS[1])
    return 'SUCCESS'
else
    redis.call('DEL', KEYS[1])
    return 'OUT_OF_STOCK'
end
```

---

## 13. RediSearch (Full-Text Search)

### What it is
RediSearch is a Redis module that provides full-text search, aggregations, and autocomplete - turning Redis into a search engine.

### When to use
- Product search
- Article search
- Autocomplete
- Filters and facets
- Geographic search
- Any search beyond simple key lookups

### Setup and indexing

**Create index**
```redis
FT.CREATE products ON hash PREFIX 1 product: SCHEMA name TEXT price NUMERIC category TAG
```
- `ON hash` - data stored as Redis hashes (or JSON with RedisJSON)
- `PREFIX 1 product:` - indexes keys matching `product:*`
- `SCHEMA` - define fields and their types

Field types:
- `TEXT` - searchable text (stemmed, tokenized)
- `NUMERIC` - numeric for filtering/ranges
- `TAG` - exact match (like category)
- `GEO` - geographic coordinates (lat/lon)
- `SORTABLE` - can add to enable sorting
- `NOINDEX` - store but don't index

### Basic search

```redis
-- Add product
HSET product:1 name "Running Shoes" price 99 category "sports"

-- Search
FT.SEARCH products "shoes"
FT.SEARCH products "shoes" LIMIT 0 10
```

**Filter by numeric**
```redis
FT.SEARCH products "shoes" FILTER price >= 50 price <= 150
FT.SEARCH products "shoes" FILTER price > 100 SORTBY price ASC
```

**Filter by tag**
```redis
FT.SEARCH products "shoes" FILTER category = sports
FT.SEARCH products "shoes" FILTER category IN sports outdoor
```

### GEO - Geographic Search

```redis
-- Add store with coordinates (longitude, latitude)
HSET store:1 name "Downtown Store" location "-122.4194,37.7749"

-- Create index with GEO field
FT.CREATE stores ON hash PREFIX 1 store: SCHEMA name TEXT location GEO

-- Find stores within 10km of a point
FT.SEARCH stores "*" GEOFILTER location -122.4194 37.7749 10 km
```

### WEIGHTS - Field Importance

```redis
-- Name matches are 3x more important than description
FT.CREATE products ON hash PREFIX 1 product: SCHEMA name TEXT description TEXT

FT.SEARCH products "laptop" WEIGHTS name 3 description 1
```

### HIGHLIGHT - Show Matching Text

```redis
FT.SEARCH products "running" HIGHLIGHT name "<b>" "</b>"
-- Returns: <b>Running</b> Shoes
```

### EXPLAIN - Debug Queries

```redis
FT.EXPLAIN products "@price:[50 100] (shoes | sneakers)"
-- Shows how Redis parses and executes your query
```

### PROFILE - Query Performance

```redis
FT.PROFILE products SEARCH "laptop"
-- Shows execution time for each part of the query
```

### Autocomplete

```redis
FT.SUGADD product:suggest "running shoes" 10
FT.SUGADD product:suggest "running shorts" 8
FT.SUGADD product:suggest "basketball shoes" 5

FT.SUGGET product:suggest "run"
```
Returns suggestions sorted by score.

### TF-IDF (How Search Ranking Works)

RediSearch uses TF-IDF (Term Frequency-Inverse Document Frequency):
- **TF**: How often a term appears in a document (more = more relevant)
- **IDF**: How rare the term is across all documents (rarer = more relevant)

Example: Searching "the" across 1000 documents:
- "the" appears in all 1000 → low IDF → low relevance
- "laptop" appears in 5 → high IDF → high relevance

### Important notes
- Indexes must be created before adding data
- Hash changes automatically update index
- Requires Redis Stack or RediSearch module
- Text fields are stemmed (running → run)
- Supports fuzzy matching with ~ operator

---

## 14. RedisJSON - JSON Data

### What it is
RedisJSON is a Redis module that lets you store, query, and manipulate JSON documents directly in Redis. No more serializing/deserializing strings!

### When to use
- Storing complex objects with nested data
- Need to update specific fields within JSON
- Schema flexibility (documents can have different fields)
- Integrating with other JSON tools

### Installation
RedisJSON comes with Redis Stack. If using Redis OSS:
```bash
MODULE LOAD /path/to/rejson.so
```

Or in redis.conf:
```
loadmodule /path/to/rejson.so
```

### Commands

**JSON.SET - Store JSON**
```redis
JSON.SET user:1 $ '{"name":"Alice","age":25,"address":{"city":"NYC"}}'
```
- `$` is the root path
- Creates key if not exists

**JSON.GET - Retrieve JSON**
```redis
JSON.GET user:1
JSON.GET user:1 $.name              # Get specific field
JSON.GET user:1 $.address.city      # Get nested field
```

**JSON.SET - Update field**
```redis
JSON.SET user:1 $.age 26             # Update age to 26
JSON.SET user:1 $.address.city "LA" # Update nested field
JSON.SET user:1 $.tags '["new","premium"]'  # Set array
```

**JSON.DEL - Delete**
```redis
JSON.DEL user:1 $.address            # Delete address field
JSON.DEL user:1                      # Delete entire document
```

**JSON.NUMINCBY - Atomic numeric operations**
```redis
JSON.SET product:1 $ '{"price":100}'
JSON.NUMINCBY product:1 $.price 50  # Price now 150
JSON.NUMINCBY product:1 $.price -10  # Price now 140
```

### Array Operations

```redis
JSON.SET cart:1 $ '{"items":["a","b","c"]}'

JSON.ARRAPPEND cart:1 $.items "d"    # Add to array
JSON.ARRTRIM cart:1 $.items 0 1     # Keep first 2 elements
JSON.ARRLEN cart:1 $.items           # Get array length
JSON.ARRINDEX cart:1 $.items "b"    # Find index of "b"
```

### Searching JSON with RediSearch

```redis
-- Create index on JSON documents
FT.CREATE users ON JSON PREFIX 1 user: SCHEMA $.name TEXT $.age NUMERIC

-- Add JSON document
JSON.SET user:1 $ '{"name":"Alice","age":25}'

-- Search
FT.SEARCH users "@age:[20 30]"
```

### When to Use JSON vs Hashes

| Feature | Hash | RedisJSON |
|---------|------|-----------|
| Simple flat data | ✅ Great | Works |
| Nested objects | ❌ Hard | ✅ Great |
| Partial updates | ❌ Replace all | ✅ Update just field |
| Schema flexibility | Fixed fields | ✅ Flexible |
| Memory usage | More efficient | Slightly more |

---

## 15. Redis Stack vs Redis Core

### Redis OSS (Open Source)
The basic Redis - what you've been learning:
- All core data types: Strings, Lists, Sets, Hashes, Sorted Sets
- HyperLogLog, Bitmaps, Streams
- Transactions, Lua, Pipelining
- Master-replica replication
- Clustering

**It's free and open-source.**

### Redis Stack (What's Included)

Redis Stack adds **modules** on top of Redis OSS:

| Module | What it adds |
|--------|-------------|
| **RediSearch** | Full-text search |
| **RedisJSON** | JSON document storage/query |
| **RedisGraph** | Graph database |
| **RedisTimeSeries** | Time-series data (IoT, metrics) |
| **RedisBloom** | Probabilistic data structures |
| **RedisGears** | Programmable engine |

### Comparison

| Feature | Redis OSS | Redis Stack |
|---------|-----------|-------------|
| Basic data types | ✅ All | ✅ All |
| Full-text search | ❌ | ✅ RediSearch |
| JSON support | ❌ | ✅ RedisJSON |
| Search indexes | ❌ | ✅ |
| Query JSON | ❌ | ✅ |
| Module loading | ✅ | ✅ (pre-installed) |
| Price | Free | Free (self-hosted) or paid (Cloud) |

### How to Get Redis Stack

**Docker (easiest):**
```bash
docker run -p 6379:6379 redis/redis-stack
```

**Install from source:**
- Download Redis Stack from redis.io
- Or compile modules and load into Redis OSS

**Redis Cloud:**
- Free tier available
- Modules pre-installed

### When to Use What

**Use Redis OSS when:**
- Simple caching
- Just need basic data structures
- Don't need search or JSON

**Use Redis Stack when:**
- Need full-text search
- Store JSON documents
- Complex queries on data
- Time-series or graph needs

---

## 16. Module Loading

### What it is
Redis modules are extensions that add new functionality. You can load them into Redis at startup or dynamically.

### Loading Methods

**1. redis.conf**
```conf
loadmodule /path/to/module1.so
loadmodule /path/to/module2.so
```

**2. Command line**
```bash
redis-server --loadmodule /path/to/rejson.so
```

**3. Runtime (if module supports)**
```redis
MODULE LOAD /path/to/module.so
MODULE UNLOAD module_name
```

### Common Modules

| Module | Purpose | File |
|--------|---------|------|
| RediSearch | Full-text search | redisearch.so |
| RedisJSON | JSON support | rejson.so |
| RedisGraph | Graph DB | redisgraph.so |
| RedisBloom | Bloom filters | redisbloom.so |
| RedisTimeSeries | Time series | redistimeseries.so |

### Check Loaded Modules

```redis
MODULE LIST
```

Returns:
```
1) "name" => "rejson"
   "ver" => 20010
2) "name" => "search"
   "ver" => 20010
```

### Module Version Compatibility

- Each Redis version may require specific module versions
- Always check compatibility charts
- Redis Stack includes matched versions

### Best Practices

1. **Use Redis Stack** - Pre-tested module combinations
2. **Pin versions** - Don't auto-upgrade in production
3. **Test first** - New module versions may have breaking changes
4. **Monitor** - Some modules use significant memory

---

## 17. Common Key Patterns

### Why naming matters
Consistent naming makes your code searchable and debuggable.

### Key Naming Methodology from Course

The course emphasizes a systematic approach to key naming:

| Component | Description |
|-----------|-------------|
| **Entity Type** | What kind of data (user, product, order) |
| **Entity ID** | Specific identifier |
| **Attribute** | Optional: specific field or purpose |

**Format:** `entityType:entityID:attribute`

### Common Key Patterns from Course

| Purpose | Pattern | Example |
|---------|---------|---------|
| User data | `user:{id}` | `user:123` |
| Session | `session:{token}` | `session:abc123xyz` |
| Product | `product:{id}` | `product:100` |
| User session | `session:user:{id}` | `session:user:123` |
| Cache | `cache:{type}:{id}` | `cache:user:123` |
| Queue | `queue:{name}` | `queue:emails` |
| Leaderboard | `leaderboard:{game}` | `leaderboard:game1` |
| Rate limit | `rate:{type}:{id}` | `rate:ip:192.168.1.1` |
| Counter | `counter:{type}:{id}` | `counter:views:product:123` |

### Good practices
- Use colons for hierarchy
- Include type in key (makes debugging easier)
- Keep consistent across all keys
- Consider key length vs. clarity (shorter is fine if obvious)

---

## 18. Redis Performance - Why It's Fast

Redis is incredibly fast. Here's why:

### Reason 1: In-Memory Storage

```
Memory Access: ~0.001 ms (nanoseconds)
Disk Access: ~10 ms (milliseconds)

10,000x faster to access data in memory vs disk!
```

Redis keeps ALL data in memory by default:
- No disk seeks required
- Instant read/write operations
- Data is lost on server restart (unless persistence configured)

**The tradeoff:** Your data must fit in RAM.

**Solutions for large datasets:**
- Use Redis as cache, not primary store
- Configure persistence (RDB/AOF)
- Use Redis Cluster to distribute data

### Reason 2: Optimized Data Structures

Redis uses simple, well-known data structures:
- Strings, Lists, Hashes, Sets, Sorted Sets, etc.
- Each has predictable performance (O(1), O(log n), etc.)
- No complex query parsing or indexing overhead

**You know exactly how your data performs** - no hidden slow queries.

### Reason 3: Simple Architecture

```
Other databases: Complex query → Parser → Optimizer → Executor → Disk
Redis: Your command → Direct execution → Memory
```

No:
- Query parsing overhead
- Query optimizer decisions
- Transaction logs
- Index maintenance
- Table joins

**Simpler = Faster**

### Performance Numbers (Typical)

| Operation | Latency |
|-----------|---------|
| Read/Write (single key) | 0.1 - 1 ms |
| Pipelined commands | 0.01 ms per command |
| Lua script execution | 0.1 - 1 ms |

**Throughput:** 100,000 - 1,000,000 operations/second (depending on operation type and server)

### When Redis Might Be Slow

Even though Redis is fast, be careful with:

1. **HGETALL on large hashes** → Returns everything at once
2. **SMEMBERS on large sets** → Returns everything at once
3. **KEYS *** → Scans ALL keys (blocks Redis!)
4. **Large values** → Network transfer takes time
5. **Many small commands** → Use pipelining instead
6. **No connection pooling** → Connection overhead adds up

### Best Practices for Speed

1. **Use pipelining** - Batch multiple commands
2. **Keep values small** - < 10KB is ideal
3. **Use appropriate data structures** - Don't use Hash when String works
4. **Use SCAN instead of KEYS** - Non-blocking iteration
5. **Use connection pooling** - Reuse connections
6. **Store serialized data efficiently** - JSON is fine, but know the size cost

### Memory vs Disk

| Storage | Speed | Durability |
|---------|-------|------------|
| Redis (memory only) | Fastest | None (data lost on restart) |
| Redis + RDB | Fast | Periodic snapshots |
| Redis + AOF | Fast | Every write logged |
| Database on disk | Slower | Always persistent |

---

## 19. Redis Configuration

### Configuration File

Redis uses `redis.conf` for configuration. Key locations:
- `/etc/redis/redis.conf` (Linux)
- `redis.conf` in working directory

### Essential Configurations

**Network:**
```conf
bind 127.0.0.1              # Listen on localhost
port 6379                   # Default port
timeout 300                # Close idle connections (seconds)
```

**Memory:**
```conf
maxmemory 2gb               # Limit Redis memory usage
maxmemory-policy allkeys-lru  # Eviction policy when full
```

**Persistence:**
```conf
# RDB Snapshots
save 900 1                 # Save every 900s if 1 key changed
save 300 10                # Save every 300s if 10 keys changed
save 60 10000              # Save every 60s if 10000 keys changed

# AOF
appendonly yes
appendfsync everysec       # Sync every second
auto-aof-rewrite-percentage 100
```

**Replication:**
```conf
replicaof 192.168.1.1 6379  # Make this a replica
replica-read-only yes      # Replicas are read-only
```

**Logging:**
```conf
loglevel notice
logfile /var/log/redis/redis.log
```

### Runtime Commands

**Get config:**
```redis
CONFIG GET maxmemory
CONFIG GET port
```

**Set config (runtime):**
```redis
CONFIG SET maxmemory 1gb
CONFIG SET maxmemory-policy allkeys-lru
```

**Important settings to know:**

| Setting | Purpose | Default |
|---------|---------|---------|
| `maxmemory` | Max RAM to use | All available |
| `maxmemory-policy` | What to drop when full | noeviction |
| `timeout` | Connection timeout | 0 (never) |
| `tcp-keepalive` | Keep connections alive | 300 |
| `databases` | Number of DBs | 16 |
| `maxclients` | Max connections | 10000 |

### Memory Management

**Eviction Policies:**
```
noeviction        - Return error when full
allkeys-lru       - Remove least recently used keys
volatile-lru      - Remove LRU keys with TTL only
allkeys-random    - Remove random keys
volatile-random  - Remove random keys with TTL
volatile-ttl     - Remove keys with shortest TTL
allkeys-lfu       - Remove least frequently used
volatile-lfu      - Remove LFU keys with TTL
```

```redis
CONFIG SET maxmemory-policy allkeys-lru
```

### Security

**Basic auth:**
```conf
requirepass yourpassword
```

```redis
AUTH yourpassword
```

**Rename dangerous commands:**
```conf
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG "CONFIG_c9f3a8b2"
```

### Slow Logs

```conf
slowlog-log-slower-than 10000  # Log queries > 10ms
slowlog-max-len 128             # Keep last 128 slow queries
```

```redis
SLOWLOG GET 10                 # Get last 10 slow queries
SLOWLOG LEN                    # Count of slow queries
```

### Monitoring

**INFO command:**
```redis
INFO                           # All stats
INFO memory                    # Memory info
INFO replication              # Replication status
INFO stats                    # General stats
INFO clients                 # Connected clients
```

**DEBUG command (use with caution):**
```redis
DEBUG SLEEP 1                 # Simulate delay
DEBUG SEGFAULT                # Force crash ( DON'T in production!)
```

---

## 20. Expiration

### What it is
Expiration allows Redis keys to automatically expire (be deleted) after a specified time or at a specific timestamp.

### When to use
- Caching (data that's only valid for a period)
- Session data
- Rate limiting tokens
- Temporary data
- TTL-based features

### Commands explained

**EXPIRE - Set TTL (time to live)**
```redis
SET user:session:123 "data"
EXPIRE user:session:123 3600          # Delete after 3600 seconds (1 hour)
```
Returns `1` if timeout was set, `0` if key doesn't exist.

**TTL - Check remaining time**
```redis
TTL user:session:123                  # Returns 3595 (seconds left)
TTL user:session:123                  # Returns -1 (no expiration)
TTL user:session:123                  # Returns -2 (key doesn't exist)
```
- `-1` = key exists but has no expiration
- `-2` = key doesn't exist

**SET with EX option**
```redis
SET user:session:123 "data" EX 3600   # Set + expire in one command
```
This is more efficient than separate SET + EXPIRE.

**EXPIREAT - Set specific time**
```redis
EXPIREAT user:session:123 1704700800  # Expire at Unix timestamp
```

**PEXPIRE/PTTL - Millisecond precision**
```redis
PEXPIRE user:session:123 3600000       # 1 hour in milliseconds
PTTL user:session:123                  # Returns milliseconds
```

**PERSIST - Remove expiration**
```redis
EXPIRE user:session:123 3600
PERSIST user:session:123               # Removes expiration, key stays forever
```

**KEYS with expiration**
```redis
SETEX user:cache:123 300 "value"      # SET + EX in one command (String only)
PSETEX user:cache:123 300000 "value"  # Same but milliseconds
```

### Important notes

- Expiration works on any Redis data type (String, Hash, List, Set, etc.)
- Setting a new value on a key RESETS its expiration
- EXPIRE on non-existent key returns 0 (no effect)
- DEL on a key removes expiration automatically
- You can only set expiration on whole keys, not individual fields in hashes

### Real examples

**Cache with TTL:**
```redis
SET cache:product:456 '{"name":"Laptop","price":999}' EX 300
# After 5 minutes, key automatically deleted
# Next request will fetch from database and cache again
```

**Rate limiter:**
```redis
INCR rate_limit:user:123
EXPIRE rate_limit:user:123 60          # Reset every minute
```

**Session management:**
```redis
SET session:abc123 '{"userId":456}' EX 1800
# 30-minute session, auto-cleanup

---

## 21. Pub/Sub (Publish/Subscribe)

### What it is
Pub/Sub is a messaging pattern where publishers send messages to channels, and subscribers receive messages from channels they subscribed to. It's real-time communication between services.

### When to use
- Real-time notifications
- Chat systems
- Service-to-service communication
- Broadcasting updates to multiple clients
- Event-driven architectures
- Cache invalidation signals

### Core Concepts

**Publisher** → Sends message to channel → **Subscriber** receives message

```
Publisher: PUBLISH channel message
Subscriber: SUBSCRIBE channel
```

### Basic Commands

**SUBSCRIBE - Listen to channel**
```redis
SUBSCRIBE notifications
SUBSCRIBE channel1 channel2          # Subscribe to multiple
```
Client enters "subscription mode" - can only run subscribe/unsubscribe/ping commands.

**PUBLISH - Send message**
```redis
PUBLISH notifications "Hello subscribers!"
```
Returns number of subscribers who received the message.

**UNSUBSCRIBE - Stop listening**
```redis
UNSUBSCRIBE notifications
UNSUBSCRIBE                          # Unsubscribe from all
```

---

### Pattern Subscriptions (PSUBSCRIBE)

Subscribe to multiple channels using glob patterns:

| Pattern | Matches | Doesn't Match |
|---------|---------|---------------|
| `events.*` | `events.user`, `events.order` | `events`, `other.events` |
| `user:?:updated` | `user:1:updated`, `user:a:updated` | `user:123:updated` |
| `orders:*:created` | `orders:1:created`, `orders:a:created` | `orders:created` |

```redis
PSUBSCRIBE events.*
PSUBSCRIBE user:*:login
PUNSUBSCRIBE events.*                # Unsubscribe from pattern
```

**Message types:**
- `message` - from SUBSCRIBE
- `pmessage` - from PSUBSCRIBE (includes pattern info)

```javascript
// In code, you get different message types
subscriber.on('message', (channel, message) => {
    // Regular SUBSCRIBE message
});

subscriber.on('pmessage', (pattern, channel, message) => {
    // Pattern-matched message
    console.log(`Pattern: ${pattern}, Channel: ${channel}`);
});
```

---

### Sharded Pub/Sub (Redis 7+)

New in Redis 7: sharded Pub/Sub uses consistent hashing to distribute channels across cluster nodes.

**Commands:**
```redis
SSUBSCRIBE orders                     # Subscribe to shard
SPUBLISH orders "message"             # Publish to shard
SUNSUBSCRIBE orders                   # Unsubscribe
```

Difference from regular Pub/Sub:
- Messages stay on their assigned shard
- Better scaling in cluster mode

---

### PUBSUB - Inspect System

```redis
PUBSUB CHANNELS                      # List active channels
PUBSUB CHANNELS pattern:*             # Filter by pattern
PUBSUB NUMSUB notifications          # Subscriber count for channel
PUBSUB NUMPAT                        # Total pattern subscriptions
PUBSUB SHARDNUMSUB notifications     # Sharded subscriber count
```

---

### Message Routing Patterns

**1. Fan-out** - Message to all subscribers
```
Channel: "alerts"
  → Subscriber A gets message
  → Subscriber B gets message
  → Subscriber C gets message
```

**2. Topic-based** - Using patterns
```
PUBLISH user:123:login "user logged in"
  → PSUBSCRIBE user:* → gets it
  → PSUBSCRIBE user:123:* → gets it
```

**3. Direct** - Specific channel
```
PUBLISH notifications:user:123 "your order shipped"
SUBSCRIBE notifications:user:123 → gets it
```

---

### Real-World Examples

**Example 1: Multi-tenant event system**
```javascript
// Publisher - send tenant-specific events
const publisher = new Redis();
await publisher.publish(`tenant:${tenantId}:orders`, JSON.stringify(order));
await publisher.publish(`tenant:${tenantId}:users`, JSON.stringify(user));

// Subscriber - listen to all tenant events
const subscriber = new Redis();
subscriber.psubscribe('tenant:*', (message) => {
    const event = JSON.parse(message);
    // Handle event from any tenant
});
```

**Example 2: Service-wide notifications**
```javascript
// All services subscribe to critical events
PSUBSCRIBE "service:critical:*"

// Payment service publishes
PUBLISH "service:critical:payment" JSON.stringify({type: 'payment_down'})
```

**Example 3: Cache invalidation**
```redis
# When data changes, publish invalidation event
PUBLISH cache:invalidations "user:123"

# Cache service listens
SUBSCRIBE cache:invalidations
# On message: DEL cache:user:123
```

---

### Pub/Sub in Clusters

In Redis Cluster:
- Each node has its own Pub/Sub
- PUBLISH to any node → cluster forwards to correct node
- PUBSUB commands only show local info

**Sharded Pub/Sub** (Redis 7+):
- Uses slot-based distribution
- More efficient in clusters
- Use SSUBSCRIBE/SPUBLISH

---

### Pub/Sub vs Streams

| Feature | Pub/Sub | Streams |
|---------|---------|---------|
| Message history | No | Yes |
| Consumer groups | No | Yes |
| Re-read messages | No | Yes |
| Persistence | No | Yes |
| Latency | Lower | Higher |
| Complexity | Simple | More features |
| At-least-once delivery | No | Yes |
| Scalability | Limited | Better |

---

### Limitations

1. **No persistence** - Messages lost if no subscriber
2. **No delivery guarantee** - Fire-and-forget
3. **No consumer groups** - All subscribers get all messages
4. **Memory pressure** - Slow subscribers can cause memory buildup
5. **No backpressure** - Publisher doesn't know subscriber speed

---

### When NOT to Use Pub/Sub

- Need message history → Use Streams
- Need exactly-once delivery → Use Streams
- Need load distribution → Use Streams
- Offline consumers → Use Streams
- Need message acknowledgment → Use Streams

---

### Best Practices

1. **Keep messages small** - Under 1KB ideal
2. **Use patterns wisely** - Don't have thousands of patterns
3. **Handle disconnects** - Subscribers should reconnect
4. **Monitor PUBSUB NUMSUB** - Know your subscriber counts
5. **Consider Streams for complex flows** - When Pub/Sub isn't enough
|---------|---------|---------|
| Message history | No | Yes |
| Consumer groups | No | Yes |
| Re-read messages | No | Yes |
| Persistence | No | Yes |
| Latency | Lower | Higher |
| Complexity | Simple | More features |

### Important notes
- Messages are not persisted
- If no subscriber, message is discarded
- Subscribers must be connected when message is published
- Can scale with Redis Cluster but limited

### Commands explained

**EXPIRE - Set TTL**
```redis
SET user:123:token "abc"
EXPIRE user:123:token 3600
```
Sets time-to-live in seconds.

**TTL/PTTL - Check remaining time**
```redis
TTL user:123:token          # Returns seconds, -1 if no expiry, -2 if key doesn't exist
PTTL user:123:token         # Returns milliseconds
```

**PERSIST - Remove expiration**
```redis
PERSIST user:123:token      # Key will never expire
```

**SET with EX option**
```redis
SET user:123:token "abc" EX 3600    # Set + expire in one command
SETEX user:123:token 3600 "abc"     # Same, different order
```

**EXPIREAT - Set exact time**
```redis
EXPIREAT user:123:token 1704067200   # Unix timestamp
```

### Key points
- Expiration works on any Redis type
- Setting a new value on key resets expiration
- EXPIRE on non-existent key returns 0 (no effect)
- Key deletion removes expiration automatically

---

## 26. Common Redis Gotchas and Edge Cases

### 1. HSET Return Value Surprises

HSET behavior can be confusing:

```redis
HSET user:1 name "Alice"               # Returns 1 (added 1 field)
HSET user:1 name "Bob"                # Returns 0 (updated existing field!)
HSET user:1 name "Bob" age "25"       # Returns 1 (added 1 new field)
```
**Gotcha:** HSET returns number of fields ADDED (not modified). Updating returns 0!

**Workaround:** Use HSETNX (set if not exists) or just accept the return value means "new fields added".

### 2. HGETALL on Large Hashes

```redis
HSET user:1000 field1 "value1" field2 "value2" ... field5000 "value5000"
HGETALL user:1000                      # Returns 10000 items (field+value)!
```
**Problem:** HGETALL returns ALL fields at once - can be huge!

**Solution:** Use HSCAN for large hashes:
```redis
HSCAN user:1000 MATCH field* COUNT 100
```
- Returns in batches
- Use MATCH to filter
- COUNT is a hint, not exact

### 3. SET with NX/XX and Expiration

```redis
SET key "value" NX EX 10               # Only set if not exists, with 10s expiry
```
Works as expected, but be careful:
- If NX fails (key exists), no expiration is set on existing key
- If XX fails (key doesn't exist), nothing happens

### 4. SCARD vs SMEMBERS for Count

```redis
SADD myset "a" "b" "c"
SCARD myset           # Returns 3 - O(1) operation, fast!
SMEMBERS myset        # Returns ["a","b","c"] - O(n), slower
```
**Gotcha:** Use SCARD for counting, not LLEN on lists.

### 5. Lists and Negative Indices

```redis
RPUSH mylist "a" "b" "c" "d"
LRANGE mylist -3 -1         # Returns ["b","c","d"]
LRANGE mylist 0 -1          # Returns all
LRANGE mylist -10 -1         # Returns all (if less than 10 items)
```
**Gotcha:** -1 is last, -2 is second to last, etc.

### 6. Sorted Sets and Ties

```redis
ZADD leaderboard 100 "player1" 100 "player2"
ZRANGE leaderboard 0 -1         # Returns in alphabetical order when scores tie!
```
**Gotcha:** When scores are equal, members are sorted alphabetically.

### 7. INCR on Non-Numeric Strings

```redis
SET mykey "hello"
INCR mykey                      # Error: ERR value is not an integer
```
**Gotcha:** INCR fails if value isn't a number. Use GET first or handle errors.

### 8. Key Expiration Reset on Update

```redis
SET mykey "value" EX 100
TTL mykey                       # Returns 99
SET mykey "newvalue"            # Updates value
TTL mykey                       # Returns -1 (no expiration!)
```
**Gotcha:** SET overwrites the key, resetting expiration! Use SET with EX to preserve.

```redis
SET mykey "newvalue" EX 100     # Sets new value AND keeps expiration
```

### 9. WATCH and EXEC Behavior

```redis
WATCH mykey
GET mykey
MULTI
DECR mykey
EXEC                  # Returns nil if key changed!
```
**Gotcha:** If WATCH detects change, EXEC returns nil (null array). Don't check for errors, check for nil!

### 10. Streams and Consumer Groups

```redis
XREADGROUP GROUP mygroup consumer1 COUNT 1 STREAMS mystream >
```
**Gotcha:** The `>` symbol means "only new messages not yet delivered". Once delivered, they're "pending" until XACK.

### 11. HyperLogLog Precision

```redis
PFADD mykey "item1" "item2" "item3"
PFCOUNT mykey              # Returns 3 (usually exact)
```
**Gotcha:** For very small sets (< 256), precision is good. For billions, expect ~0.81% error.

---

## Quick Reference: When to Use What

| Scenario | Redis Type |
|----------|------------|
| Cache API response | String + EX |
| User profile | Hash |
| Article tags | Set |
| Leaderboard | Sorted Set |
| Job queue | List |
| Unique visitors (analytics) | HyperLogLog |
| Daily active users | Bitmap |
| Event log | Stream |
| Atomic check-then-update | Lua Script |
| Batch performance | Pipeline |
| Multiple servers coordination | Distributed Lock |
| Product search | RediSearch |
| Atomic counter | String INCR |
| User follows/followers | Set |
| Recently viewed items | List |
| Time-ordered events | Sorted Set or Stream |

---

## 22. SORT Command

### What it is
The SORT command returns or stores the elements contained in a list, set, or sorted set in order. It's like SQL's ORDER BY but for Redis data structures.

### Why it exists
While Sorted Sets sort by score, sometimes you need to sort by:
- A field inside a hash
- Alphabetically
- Numerically
- By reference to another key

### Basic Examples

**Sort a list:**
```redis
RPUSH mylist 3 1 4 1 5 9 2 6
SORT mylist                    # Returns: 1, 1, 2, 3, 4, 5, 6, 9
SORT mylist DESC               # Returns: 9, 6, 5, 4, 3, 2, 1, 1
```

**Sort a set:**
```redis
SADD scores player1 100 player2 250 player3 50
SORT scores                    # By member value (alphabetical for sets!)
SORT scores BY score           # But wait - sets don't have scores!
```

This is where SORT really shines - sorting BY something else!

### Sort by Hash Field (ALPHA/BY)

```redis
# Store user ages in hash
HSET user:1 age 25
HSET user:2 age 30
HSET user:3 age 20

# Get user IDs
SADD users 1 2 3

# Sort users by their age (stored in hash)
SORT users BY user:*->age

# Returns: 3, 1, 2 (user3=20, user1=25, user2=30 - sorted by age!)
```

The `*` is replaced by each member, and `->age` gets the field from the hash.

### Sort and GET Multiple Fields

```redis
# For each user, get name and age
SORT users BY user:*->age GET user:*->name GET user:*->age

# Returns: name1, age1, name2, age2, ...
```

### Sort with Store

```redis
SORT users BY user:*->age STORE sorted_users
# Results are stored in sorted_users list instead of returned
```

### Important Notes

- **Sets**: Sort alphabetically by member name (not by scores)
- **Lists**: Sort numerically by default
- **BY with sets**: Can sort by hash fields, not just by set members
- **Performance**: O(N + M log M) where N = number of elements, M = result size

### Real Example: E-commerce Items by Views

```redis
# Store item view counts
HSET item:1 views 100
HSET item:2 views 500
HSET item:3 views 50

# Add item IDs to a set
SADD popular_items 1 2 3

# Sort by view count
SORT popular_items BY item:*->views DESC
# Returns: 2, 1, 3 (most viewed first!)
```

---

## Memory Comparison

| Data Type | 1 Million Items | 1 Billion Items |
|-----------|-----------------|-----------------|
| Strings | ~200 MB | ~200 GB |
| Sets | ~150 MB | ~150 GB |
| Sorted Sets | ~200 MB | ~200 GB |
| Hashes | ~100 MB | ~100 GB |
| HyperLogLog | 12 KB | 12 KB |
| Bitmaps | ~125 KB | ~125 MB |

---

## 23. Redis Sentinel - High Availability

### What it is
Redis Sentinel is a system that provides high availability for Redis. It monitors master-replica setups, detects failures, and automatically promotes a replica to master when the master fails.

### The Problem It Solves

```
Single Redis Server:
┌─────────────────┐
│   Redis Master  │ ← If this fails, app goes down!
└─────────────────┘
```

```
With Sentinel:
┌─────────────────┐     ┌─────────────────┐
│   Redis Master  │────▶│     Sentinel    │
└─────────────────┘     └─────────────────┘
         ↑                      │
         │                      ▼
┌─────────────────┐     ┌─────────────────┐
│   Redis Slave  │◀────│   (monitors,    │
└─────────────────┘     │   promotes)     │
```

### Sentinel Responsibilities

1. **Monitoring** - Continuously check if master and replicas are alive
2. **Notification** - Send alerts when something goes wrong
3. **Automatic Failover** - Promote replica to master when master fails
4. **Configuration Provider** - Tell clients where the current master is

### How Failover Works

```
1. Sentinel detects master is down (multiple sentinels must agree - quorum)

2. Sentinel picks the best replica and promotes it:
   Slave → becomes new Master

3. Sentinel tells all other replicas to follow new master:
   Slave1 → follow new Master
   Slave2 → follow new Master

4. Clients automatically connect to new master
```

### Setup (Minimum)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Redis    │     │   Redis    │     │   Redis    │
│   Master   │────▶│   Slave    │◀────│   Slave    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                      │
       └────────────┬────────────────────────┘
                    │
              ┌─────▼─────┐
              │ Sentinel  │
              │ Sentinel  │
              │ Sentinel  │
              └───────────┘
```

**Minimum 3 Sentinel nodes** (odd number needed for quorum)

### Quorum

- **Quorum** = minimum number of sentinels that must agree master is down
- If you have 3 sentinels, quorum = 2
- This prevents false failover if one sentinel has network issues

### Commands

```redis
SENTINEL masters                     # List all masters
SENTINEL slaves master-name         # List slaves of a master
SENTINEL get-master-addr-by-name master-name  # Get current master address
SENTINEL failover master-name       # Force failover (for maintenance)
```

### In Application Code

```javascript
// Instead of connecting to single Redis
const redis = new Redis('redis://localhost:6379');

// Connect via Sentinel
const sentinel = new Sentinel(['localhost:26379', 'localhost:26380']);
const redis = sentinel MASTER_OF mymaster;
```

Sentinel-aware clients automatically:
- Connect to current master
- Reconnect when failover happens
- Can also route read queries to replicas

### When to Use Sentinel

✅ **Use Sentinel when:**
- Dataset fits in single server memory
- Need automatic failover
- Don't need to scale beyond one machine
- Write throughput fits single master

❌ **Don't use Sentinel when:**
- Data exceeds single server memory → Use Cluster
- Need horizontal scaling → Use Cluster

---

## 24. Redis Cluster - Horizontal Scaling

### What it is
Redis Cluster provides horizontal scaling by sharding (splitting) data across multiple Redis nodes. Each node holds a portion of the data, and the cluster automatically manages data distribution and failover.

### Why Sentinel Isn't Enough

Sentinel gives you:
- High availability for ONE master
- Read scaling (read from replicas)
- But NO write scaling (still one master)

```
Sentinel: Data stays on one machine
┌─────────────────────┐
│      All Data       │  ← Can't scale beyond this!
│  (Master + Replica)│
└─────────────────────┘
```

```
Cluster: Data split across machines
┌───────────┐ ┌───────────┐ ┌───────────┐
│  Data 1   │ │  Data 2   │ │  Data 3   │  ← Can scale!
│ (Shard 1) │ │ (Shard 2) │ │ (Shard 3) │
└───────────┘ └───────────┘ └───────────┘
```

### How Sharding Works

Redis Cluster uses **hash slots**:
- Total: 16,384 slots (0-16383)
- Each key is assigned to a slot based on hash
- Each master node owns a range of slots

```
Key "user:123" → hash → slot 5432
Slot 5432 → owned by master:6380
```

**Hash Tags** - Force related keys to same slot:
```
user:123:profile   → uses hash of entire key → random slot
user:{123}:profile → uses hash of 123 → same slot as user:{123}:orders
```

### Cluster Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Master 1     │    │ Master 2     │    │ Master 3     │
│ Slots 0-5460│    │Slots 5461-   │    │Slots 10923-  │
│              │    │   10922      │    │   16383      │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Replica 1    │    │ Replica 2    │    │ Replica 3    │
│ (backup)     │    │ (backup)     │    │ (backup)     │
└──────────────┘    └──────────────┘    └──────────────┘
```

### Failover in Cluster

If Master 2 fails:
1. Its replica (Replica 2) detects failure
2. Replica promotes to Master
3. Cluster updates slot ownership
4. Clients automatically use new master

### Key Commands

```redis
CLUSTER INFO                      # Cluster status
CLUSTER NODES                      # List all nodes
CLUSTER SLOTS                     # Show slot ranges
CLUSTER KEYSLOT key              # Show which slot a key goes to
CLUSTER REPLICATE master-id       # Make current node replica of master
CLUSTER FAILOVER                  # Force failover (for maintenance)
```

### Limitations

1. **Multi-key operations** - Only work if keys share same slot:
   ```
   # Works (same slot):
   MGET key:1 key:2  ✓
   
   # Doesn't work (different slots):
   MGET user:1:name user:2:name  ✗
   
   # Works with hash tags:
   MGET user:{1}:name user:{2}:name  ✓
   ```

2. **Only one database** - No DB0, DB1 like standard Redis
3. **Pub/Sub limitations** - Messages may not reach all nodes
4. **Client requirements** - Must be cluster-aware

### When to Use Cluster

✅ **Use Cluster when:**
- Data exceeds single server memory
- Need to scale writes beyond single master
- Need high throughput
- Can design app for sharding

❌ **Don't use Cluster when:**
- Data fits in one server
- Need complex multi-key operations
- Simplicity is more important than scaling

---

## 25. Redis Persistence - RDB and AOF

### What it is
By default, Redis stores everything in memory. Persistence saves data to disk so it survives restarts.

### RDB (Redis Database)

**How it works:**
- Takes periodic snapshots of all data
- Creates a file (dump.rdb) with all data at that moment
- Fast to restore

**Configuration:**
```
save 900 1      # Save every 900 sec if at least 1 key changed
save 300 10     # Save every 300 sec if at least 10 keys changed
save 60 10000   # Save every 60 sec if at least 10000 keys changed
```

**Pros:**
- Fast to restore (just load the file)
- Compact (one file)
- Good for backups

**Cons:**
- Can lose data between snapshots (up to minutes)
- Blocking during snapshot (can impact performance)

### AOF (Append Only File)

**How it works:**
- Every write command is appended to a log
- Can replay log to restore data
- Three sync modes:
  - `always` - Every write synced to disk (slowest, safest)
  - `everysec` - Every second (default, good balance)
  - `no` - Let OS decide (fastest, riskiest)

**Configuration:**
```
appendonly yes
appendfsync everysec
```

**Pros:**
- More durable (can lose at most 1 second)
- Append-only = no corruption
- Can rewrite old logs to keep small

**Cons:**
- Larger files than RDB
- Slower to restore (replay all commands)

### Which to Use?

| Scenario | Recommendation |
|----------|----------------|
| Cache only (data OK to lose) | RDB or none |
| Need data durability | AOF |
| Best of both | Both (RDB + AOF) |

**Typical production:**
```
# Enable both
save 900 1
save 300 10
save 60 10000

appendonly yes
appendfsync everysec
```

---

## Common Pitfalls

1. **Using HGETALL on large hashes** → Use HSCAN instead
2. **Using SMEMBERS on large sets** → Use SSCAN
3. **Keys without expiration** → Always use EX for cache keys
4. **No error handling** → Redis commands can fail (connection issues)
5. **No key prefixing** → Makes debugging impossible
6. **Blocking in loop** → Don't use BLPOP inside a loop
7. **Not using connection pooling** → Each command creates new connection overhead
8. **Using INCR on strings** → Will fail if not numeric
9. **SET resets expiration** → Use SET with EX to preserve
10. **WATCH failure returns nil** → Check for nil, not errors

---

## 27. SCAN Operations (Iterating Large Data)

When dealing with millions of keys, don't use KEYS * - it blocks Redis. Use SCAN instead.

### SCAN - Iterate keys
```redis
SCAN 0 MATCH user:* COUNT 1000    # Returns cursor and matching keys
SCAN 12345 MATCH * COUNT 1000     # Continue from cursor 12345
```
- Returns cursor (use in next call to continue)
- MATCH filters by pattern
- COUNT is a hint (not exact)

### SSCAN - Iterate set members
```redis
SSCAN myset 0 MATCH user:1* COUNT 100
```

### HSCAN - Iterate hash fields
```redis
HSCAN myhash 0 MATCH field:* COUNT 100
```

### ZSCAN - Iterate sorted set members
```redis
ZSCAN myzset 0 MATCH player* COUNT 100
```

**Pattern:** Always loop until cursor returns "0".

```python
cursor = 0
while True:
    cursor, keys = redis.scan(cursor, match="user:*", count=1000)
    # process keys
    if cursor == "0":
        break
```
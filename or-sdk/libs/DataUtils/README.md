# DataUtils

This package provides various data utilities, including:
- Encoding/decoding
- Redis connections

## Summary

The following functions/macros are available:

|Function|Description|
|---|---|
| `encode` | Encode vector of numbers to base64, with option to deflate with Libz |
| `decode`| Decode vector of numbers from base64, with option to infate with Libz |
| `redis_connect`| Connect to Redis database and perform a function |
| `redis_set`| Set a key-value pair to Redis database |
| `redis_open_connection`| Open connection to Redis database |
| `redis_close_connection`| Close connection to Redis database |

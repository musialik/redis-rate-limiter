# Rate limiter demo

To run an example with 10 callers (you'll need a Redis server running on localhost:6379):

```
ruby run.rb 10
```

Try running twice with 5 callers each time.
The limiter should keep all callers running, one call every second, as long as you keep the total number of callers smaller than the timeout (15 seconds).

To run the tests:

```
bundle exec rspec ./
```

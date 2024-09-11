.PHONY: test
test:
	MIX_ENV=test mix test

.PHONY: format
format:
	MIX_ENV=test mix format
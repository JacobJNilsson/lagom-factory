.PHONY: test

# Run every test in test/. Stop at the first failure.
test:
	@for t in test/*.sh; do echo "== $$t"; sh "$$t" || exit 1; done

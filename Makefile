.PHONY: app test
app:
	./scripts/build.sh
test:
	bash scripts/swift.sh test

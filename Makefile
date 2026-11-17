.PHONY: app dev info test
app:
	./scripts/build.sh
dev:
	CONFIGURATION=debug BUILD_CHANNEL=dev ./scripts/build.sh
info:
	@bash scripts/build-info.sh
test:
	bash scripts/swift.sh test

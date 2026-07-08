FLUTTER := flutter
DART := dart

.PHONY: help get upgrade run analyze test format fix gen clean build-apk build-aab release-check

help:
	@printf "\n常用命令:\n"
	@printf "  make get            安装或同步依赖\n"
	@printf "  make upgrade        升级依赖\n"
	@printf "  make run            启动应用\n"
	@printf "  make analyze        执行静态检查\n"
	@printf "  make test           运行测试\n"
	@printf "  make format         格式化 Dart 代码\n"
	@printf "  make fix            自动应用 Dart 可修复项\n"
	@printf "  make gen            执行代码生成\n"
	@printf "  make clean          清理构建产物\n"
	@printf "  make build-apk      构建 Android release APK（按 ABI 拆分）\n"
	@printf "  make build-aab      构建 Android release AAB\n"
	@printf "  make release-check  发布前执行检查与测试\n\n"

get:
	$(FLUTTER) pub get

upgrade:
	$(FLUTTER) pub upgrade

run:
	$(FLUTTER) run

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

format:
	$(DART) format lib test

fix:
	$(DART) fix --apply

gen:
	$(DART) run build_runner build --delete-conflicting-outputs

clean:
	$(FLUTTER) clean

build-apk:
	$(FLUTTER) build apk --release --split-per-abi

build-aab:
	$(FLUTTER) build appbundle --release

release-check: analyze test

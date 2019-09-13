PASSWORD_STORE_DIR ?= ~/.password-store

SHELL = /bin/bash

.PHONY: install
install: | pass-initialized
	mkdir -p $(PASSWORD_STORE_DIR)/.extensions
	cp vault.bash $(PASSWORD_STORE_DIR)/.extensions
	chmod +x $(PASSWORD_STORE_DIR)/.extensions/vault.bash
	@echo
	@echo "Complete the installation with the following commands:"
	@echo "    export PASSWORD_STORE_ENABLE_EXTENSIONS=true"
	@echo "    echo 'export PASSWORD_STORE_ENABLE_EXTENSIONS=true' >> ~/.bashrc"
	@echo
	@echo 'See `pass vault help` for usage information.'

.PHONY: pass-initialized
pass-initialized:
	@pass


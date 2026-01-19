################################################################################################
# Environment Variables
################################################################################################

VERSION = $(shell grep version Project.toml | grep -o '[0-9]\+.[0-9]\.[0-9]\+')
LIB_NAME = $(shell grep name Project.toml | sed 's/name//g;s/"//g;s/ //g;s/=//g')
PWD = $(shell pwd)

# The help/usage information
define USAGE
The following targets are available:

  make local-setup (not implemented)  # Sets up the local workspace for development.
  make unit-test (not implemented)    # Runs the unit testing.
  make register-version               # Registers version in or-julia-registry

endef
export USAGE

# Print out the usage information
help:
	@printf "\n$$USAGE\n\n"

################################################################################################
# Local Development Targets
################################################################################################

.PHONY: register-version
register-version:
ifneq ($(wildcard ~/.julia/registries/or-julia-registry),)
	@if cd ~/.julia/registries/or-julia-registry && \
		git pull origin main && \
		git branch $(LIB_NAME)-version-v$(VERSION) && \
		git checkout $(LIB_NAME)-version-v$(VERSION) && \
		git push origin $(LIB_NAME)-version-v$(VERSION) && \
		julia -e 'using Pkg; Pkg.activate(;temp=true); Pkg.add(name="LocalRegistry", version="0.5"); using LocalRegistry; Pkg.develop(path="$(PWD)"); register("$(LIB_NAME)", registry="or-julia-registry", push=false)' && \
		git push origin $(LIB_NAME)-version-v$(VERSION); then \
		cd ~/.julia/registries/or-julia-registry && \
			git checkout main && \
			echo "*** New Branch for Registration PR Successfully Created ***"; \
	else \
		cd ~/.julia/registries/or-julia-registry && \
			git checkout main && \
			git branch -d $(LIB_NAME)-version-v$(VERSION) && \
			git push origin --delete $(LIB_NAME)-version-v$(VERSION) && \
			echo "*** Registering Failed - See Log Above ***"; \
	fi
else
    $(error or-julia-registry is not installed, please install using LocalRegistry)
endif
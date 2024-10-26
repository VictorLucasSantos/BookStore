# Defina isso para usar em todo o projeto
PYTHON_VERSION ?= 3.12.1
# os diretórios contendo os módulos da biblioteca que este repositório constrói
LIBRARY_DIRS = mylibrary
# artefatos de construção organizados neste Makefile
BUILD_DIR ?= build

# Opções do PyTest
PYTEST_HTML_OPTIONS = --html=$(BUILD_DIR)/report.html --self-contained-html
PYTEST_TAP_OPTIONS = --tap-combined --tap-outdir $(BUILD_DIR)
PYTEST_COVERAGE_OPTIONS = --cov=$(LIBRARY_DIRS)
PYTEST_OPTIONS ?= $(PYTEST_HTML_OPTIONS) $(PYTEST_TAP_OPTIONS) $(PYTEST_COVERAGE_OPTIONS)

# Opções de verificação de tipos MyPy
MYPY_OPTS ?= --python-version $(basename $(PYTHON_VERSION)) --show-column-numbers --pretty --html-report $(BUILD_DIR)/mypy
# Artefatos de instalação do Python
PYTHON_VERSION_FILE=.python-version
ifeq ($(shell which pyenv),)
# pyenv não está instalado, adivinhe o caminho eventual para o que vale a pena
PYENV_VERSION_DIR ?= $(HOME)/.pyenv/versions/$(PYTHON_VERSION)
else
# pyenv está instalado
PYENV_VERSION_DIR ?= $(shell pyenv root)/versions/$(PYTHON_VERSION)
endif
PIP ?= pip3

POETRY_OPTS ?=
POETRY ?= poetry $(POETRY_OPTS)
RUN_PYPKG_BIN = $(POETRY) run

COLOR_ORANGE = \033[33m
COLOR_RESET = \033[0m

##@ Utilitário

.PHONY: help
help:  ## Exibe esta ajuda
	@awk 'BEGIN {FS = ":.*##"; printf "\nUso:\n  make \033[36m\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: version-python
version-python: ## Exibe a versão do Python em uso
	@echo $(PYTHON_VERSION)

##@ Testes

.PHONY: test
test: ## Executa os testes
	$(RUN_PYPKG_BIN) pytest \
		$(PYTEST_OPTIONS) \
		tests/*.py

##@ Construção e Publicação

.PHONY: build
build: ## Executa a construção
	$(POETRY) build

.PHONY: publish
publish: ## Publica uma construção no repositório configurado
	$(POETRY) publish $(POETRY_PUBLISH_OPTIONS_SET_BY_CI_ENV)

.PHONY: deps-py-update
deps-py-update: pyproject.toml ## Atualiza dependências do Poetry, por exemplo, após adicionar uma nova manualmente
	$(POETRY) update

##@ Configuração
# detecção dinâmica do diretório de instalação do Python com pyenv
$(PYENV_VERSION_DIR):
	pyenv install --skip-existing $(PYTHON_VERSION)
$(PYTHON_VERSION_FILE): $(PYENV_VERSION_DIR)
	pyenv local $(PYTHON_VERSION)

.PHONY: deps
deps: deps-brew deps-py  ## Instala todas as dependências

.PHONY: deps-brew
deps-brew: Brewfile ## Instala dependências de desenvolvimento do Homebrew
	brew bundle --file=Brewfile
	@echo "$(COLOR_ORANGE)Certifique-se de que o pyenv está configurado no seu shell.$(COLOR_RESET)"
	@echo "$(COLOR_ORANGE)Deve haver algo como 'eval \$$(pyenv init -)'$(COLOR_RESET)"

.PHONY: deps-py
deps-py: $(PYTHON_VERSION_FILE) ## Instala dependências de desenvolvimento e tempo de execução do Python
	$(PIP) install --upgrade \
		--index-url $(PYPI_PROXY) \
		pip
	$(PIP) install --upgrade \
		--index-url $(PYPI_PROXY) \
		poetry
	$(POETRY) install

##@ Qualidade do Código

.PHONY: check
check: check-py ## Executa linters e outras ferramentas importantes

.PHONY: check-py
check-py: check-py-flake8 check-py-black check-py-mypy ## Verifica apenas arquivos Python

.PHONY: check-py-flake8
check-py-flake8: ## Executa o linter flake8
	$(RUN_PYPKG_BIN) flake8 .

.PHONY: check-py-black
check-py-black: ## Executa o black em modo de verificação (sem alterações)
	$(RUN_PYPKG_BIN) black --check --line-length 118 --fast .

.PHONY: check-py-mypy
check-py-mypy: ## Executa o mypy
	$(RUN_PYPKG_BIN) mypy $(MYPY_OPTS) $(LIBRARY_DIRS)

.PHONY: format-py
format-py: ## Executa o black, fazendo alterações onde necessário
	$(RUN_PYPKG_BIN) black .

.PHONY: format-autopep8
format-autopep8: ## Executa o autopep8 para formatar o código
	$(RUN_PYPKG_BIN) autopep8 --in-place --recursive .

.PHONY: format-isort
format-isort: ## Executa o isort para ordenar importações
	$(RUN_PYPKG_BIN) isort --recursive .

.PHONY: migrate
migrate: ## Executa migrações do banco de dados
	docker-compose exec web python manage.py migrate --noinput

.PHONY: seed
seed: ## Popula o banco de dados com dados iniciais
	poetry run python manage.py seed

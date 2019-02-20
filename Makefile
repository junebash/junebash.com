SHELL := /bin/bash
NPM := npm
VENDOR_DIR = assets/vendor/
JEKYLL := bundle exec jekyll
PUBLIC_WWW := /home/public

PROJECT_DEPS := package.json

.PHONY: all clean install update

all : serve

check:
	$(JEKYLL) doctor
	$(HTMLPROOF) --check-html \
		--http-status-ignore 999 \
		--internal-domains localhost:4000 \
		--assume-extension \
		_site

install:
	bundle install

update:
	bundle update

build:
	JEKYLL_ENV=production $(JEKYLL) build

serve:
	$(JEKYLL) serve

deploy:
	JEKYLL_ENV=production $(JEKYLL) build --destination $(PUBLIC_WWW)

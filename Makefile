SHELL := /bin/bash
JEKYLL := bundle exec jekyll
PUBLIC_WWW := /home/public
DEPLOY_REPO := /home/private/site.git

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
	JEKYLL_ENV=production $(JEKYLL) build -I

serve:
	$(JEKYLL) serve

deploy:
	bundle install --gemfile=$(DEPLOY_REPO)
	JEKYLL_ENV=production $(JEKYLL) build --source $(DEPLOY_REPO) --destination $(PUBLIC_WWW)

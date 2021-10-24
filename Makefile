REPO=hasura-client
SRC=src
ENTRY_POINT=$(SRC)/$(REPO).cr

Update_shards:
	shards install

Test:
	crystal spec --error-trace

Test_gen-types:
	crystal run src/schema/gen-types.cr

Deploy_DEV:
	git checkout develop
	sed -i shard.yml -E -e 's/^(version: [0-9]+\.[0-9]+\.)[0-9]+/\1'$$(( $$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+$$') + 1 ))/
	git add shard.yml
	git commit -m 'updated version number to '$$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$$')
	git push

Deploy_PROD:
	git checkout master
	git merge develop
	git push
	git checkout develop

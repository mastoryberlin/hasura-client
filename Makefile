REPO=hasura-client
SRC=src
ENTRY_POINT=$(SRC)/$(REPO).cr

Update_shards:
	shards install

Test:
	crystal spec --error-trace

Test_gen-types:
	crystal run src/schema/gen-types.cr

Retrieve_Graphql_schema:
	gq https://prod-graphql-engine.mastory.io/v1/graphql -H "X-Hasura-Admin-Secret: $${HASURA_ADMIN_SECRET}" --introspect --format json > ${SRC}/schema/schema.json
	git add ${SRC}/schema/schema.json
	git commit -m 'updated schema'

Deploy:
	sed -i shard.yml -E -e 's/^(version: [0-9]+\.[0-9]+\.)[0-9]+/\1'$$(( $$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+$$') + 1 ))/
	git add shard.yml
	git commit -m 'updated version number to '$$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$$')
	git tag v$$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$$')
	git push --tags
	curl -X POST -u feritarou:$${GITHUB_TOKEN} -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/mastoryberlin/${REPO}/releases -d '{"tag_name":"'"v$$(cat shard.yml | grep -P 'version: [0-9]+\.[0-9]+\.[0-9]+' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$$')"'"}'

# Load required extensions
load('ext://uibutton', 'cmd_button', 'text_input', 'choice_input')

# Environment variables for database connection
env = {
    "POSTGRES_DB": "assets_db",
    "POSTGRES_USER": "user",
    "POSTGRES_PASSWORD": "password",
    "POSTGRES_HOST": "localhost",
    "POSTGRES_PORT": "5432",
}

# Helper function to convert env dict to list of strings
def toList(env):
  return ["%s=%s" % (k, v) for k, v in env.items()]

# Run Docker Compose to set up the PostgreSQL container
docker_compose("docker-compose.yaml")

# Database initialization
# This resource runs the init.sql script to set up the database schema
local_resource(
    name="db-setup",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f ./database/init.sql",
    deps=["./database/init.sql"],
    env=env
)

# Clear database and recreate schema
local_resource(
    name="clear-and-recreate-database",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"DROP SCHEMA public CASCADE; CREATE SCHEMA public;\" && PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f ./database/init.sql",
    deps=["./database/init.sql"],
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button to clear database and recreate schema
cmd_button(
    name="clear-and-recreate-database",
    text="Clear and Recreate Database",
    resource="clear-and-recreate-database",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"DROP SCHEMA public CASCADE; CREATE SCHEMA public;\" && PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f ./database/init.sql"],
    env=toList(env)
)

# Mock data insertion
# This resource inserts a larger set of mock data from mock_data.sql
local_resource(
    name="insert-mock-data",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f ./database/mock_data.sql",
    deps=["./database/mock_data.sql"],
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button for inserting mock data
cmd_button(
    name="insert-mock-data",
    text="Insert Mock Data",
    resource="insert-mock-data",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f ./database/mock_data.sql"],
    env=toList(env)
)

# View all assets
# This resource displays all assets in the database
local_resource(
    name="view-all-assets",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM asset_details;\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button to view all assets
cmd_button(
    name="view-all-assets",
    text="View All Assets",
    resource="view-all-assets",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM asset_details;\""],
    env=toList(env)
)

# Test full-text search functionality
local_resource(
    name="test-search",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM search_assets('nature');\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button for custom search
cmd_button(
    name="custom-search",
    text="Custom Search",
    resource="custom-search",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM search_assets('$query')\""],
    env=toList(env),
    inputs=[
        text_input("query", "Enter search query")
    ]
)

# Test caching mechanism
local_resource(
    name="test-cache",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT set_cache('test_key', '{\\\"data\\\": \\\"test\\\"}', INTERVAL '1 hour'); SELECT get_cache('test_key');\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# Test message queue
local_resource(
    name="test-message-queue",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT enqueue_message('{\\\"task\\\": \\\"test_task\\\"}'); SELECT * FROM dequeue_message();\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# Refresh materialized view (simulating scheduled task)
local_resource(
    name="refresh-cache",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT refresh_asset_counts()\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# Local resource for inserting a custom asset
local_resource(
    name="insert-custom-asset",
    cmd="echo 'Use the UI button to insert a custom asset'",
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button for inserting a custom asset
cmd_button(
    name="insert-custom-asset",
    text="Insert Custom Asset",
    resource="insert-custom-asset",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"INSERT INTO assets (asset_type, file_name, file_path, file_size) VALUES ('$type', '$filename', '$filepath', $filesize)\""],
    env=toList(env),
    inputs=[
        choice_input("type", choices=["image", "video"]),
        text_input("filename", "Enter file name"),
        text_input("filepath", "Enter file path"),
        text_input("filesize", "Enter file size in bytes")
    ]
)

# Local resource for adding a tag to an asset
local_resource(
    name="add-tag-to-asset",
    cmd="echo 'Use the UI button to add a tag to an asset'",
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button for adding a tag to an asset
cmd_button(
    name="add-tag-to-asset",
    text="Add Tag to Asset",
    resource="add-tag-to-asset",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT add_tag_to_asset($asset_id, '$tag_name')\""],
    env=toList(env),
    inputs=[
        text_input("asset_id", "Enter asset ID"),
        text_input("tag_name", "Enter tag name")
    ]
)

# Local resource for viewing audit log
local_resource(
    name="view-audit-log",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM audit_log ORDER BY changed_at DESC LIMIT 10\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button to view audit log
cmd_button(
    name="view-audit-log",
    text="View Audit Log",
    resource="view-audit-log",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT * FROM audit_log ORDER BY changed_at DESC LIMIT 10\""],
    env=toList(env)
)

# Local resource for finding nearby assets
local_resource(
    name="nearby-assets",
    cmd="echo 'Use the UI button to find nearby assets'",
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button to test geospatial query
cmd_button(
    name="nearby-assets",
    text="Find Nearby Assets",
    resource="nearby-assets",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT id, file_name, ST_Distance(location, ST_SetSRID(ST_MakePoint($lon, $lat), 4326)) as distance FROM assets ORDER BY location <-> ST_SetSRID(ST_MakePoint($lon, $lat), 4326) LIMIT 5\""],
    env=toList(env),
    inputs=[
        text_input("lon", "Enter longitude"),
        text_input("lat", "Enter latitude")
    ]
)

# Resource to show database stats
local_resource(
    "db-stats",
    cmd="PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT relname as table_name, n_live_tup as row_count FROM pg_stat_user_tables ORDER BY n_live_tup DESC;\"",
    env=env,
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL
)

# UI Button to show database stats
cmd_button(
    name="show-db-stats",
    text="Show Database Stats",
    resource="db-stats",
    argv=["sh", "-c", "PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c \"SELECT relname as table_name, n_live_tup as row_count FROM pg_stat_user_tables ORDER BY n_live_tup DESC;\""],
    env=toList(env)
)

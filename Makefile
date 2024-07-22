deps/mini.test:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.test $@

# Run all test files
test: deps/mini.test
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

local plugin = require("mongo")

describe("setup", function()
  it("works with default", function()
    assert("", plugin.setup())
  end)

  it("works with custom config", function()
    local custom_configs = {
      default_url = "mongodb://user:password@localhost:27017",
      find_on_collection_selected = true,
    }

    plugin.setup(custom_configs)

    assert(custom_configs.default_url, plugin.config.default_url)
    assert(custom_configs.find_on_collection_selected, plugin.config.find_on_collection_selected)
  end)
end)

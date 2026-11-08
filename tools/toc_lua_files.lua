-- Simulate the client TOC loader's per-file game type gate in offline tests.
return function(toc, section, gameType)
    local lines = io.lines(toc)
    return function()
        for line in lines do
            local path, attributes = line:match("^%s*(" .. section .. "[\\/][^%[]-%.lua)%s*(.*)$")
            if path then
                local allowed = attributes:match("%[AllowLoadGameType%s+([^%]]+)%]")
                if not allowed or allowed == gameType then return path:gsub("\\", "/") end
            end
        end
    end
end

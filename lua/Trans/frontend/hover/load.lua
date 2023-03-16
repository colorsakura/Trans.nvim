local node = require('Trans').util.node
local it, conjunction = node.item, node.conjunction
local interval = (' '):rep(4)


---@alias TransHoverFormatter fun(hover:TransHover, result: TransResult)
---@alias TransHoverRenderer table<string, TransHoverFormatter>


---@type TransHoverRenderer
local default = {
    str = function(hover, result)
        hover.buffer:setline(it(result.str, 'TransWord'))
    end,
    translation = function(hover, result)
        local translation = result.translation
        if not translation then return end

        local buffer = hover.buffer
        buffer:setline(conjunction('中文翻译'))

        for _, value in ipairs(translation) do
            buffer:setline(
                it(interval .. value, 'TransTranslation')
            )
        end

        buffer:setline('')
    end,
    definition = function(hover, result)
        local definition = result.definition
        if not definition then return end

        local buffer = hover.buffer
        buffer:setline(conjunction('英文注释'))

        for _, value in ipairs(definition) do
            buffer:setline(
                it(interval .. value, 'TransDefinition')
            )
        end

        buffer:setline('')
    end,
}

---@diagnostic disable-next-line: assign-type-mismatch
default.__index = default

---@type table<string, TransHoverRenderer>
local renderer = setmetatable({}, {
    __index = function(tbl, key)
        local status, method = pcall(require, 'Trans.frontend.hover.' .. key)
        if not status then
            print(key)
            return
        end
        tbl[key] = setmetatable(method, default)
        return method
    end,
})

-- FIXME :


---@class TransHover
---@field load fun(hover: TransHover, result: TransResult, name: string, order: string[])
return function(hover, result, name, order)
    order = order or hover.opts.order.default

    local method = renderer[name]

    for _, field in ipairs(order) do
        method[field](hover, result)
    end
end

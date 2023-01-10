local M = {}
local type_check = require("Trans.util.debug").type_check

-- NOTE :中文字符及占两个字节宽，但是在lua里是3个字节长度
-- 为了解决中文字符在lua的长度和neovim显示不一致的问题
function string:width()
    return vim.fn.strdisplaywidth(self)
end

local s_to_b = true -- 从小到大排列

local m_win_width -- 需要被格式化窗口的高度
local m_fields -- 待格式化的字段
local m_tot_width -- 所有字段加起来的长度(不包括缩进和间隔)
local m_item_width -- 每个字段的宽度
local m_interval -- 每个字段的间隔
local m_size -- 字段的个数

local function caculate_format()
    local width = m_win_width - m_item_width[1]
    local cols = 0
    for i = 2, m_size do
        width = width - m_item_width[i] - m_interval
        if width < 0 then
            cols = i - 1
            break
        else
            cols = i
        end
    end

    return math.ceil(m_size / cols), cols
end

local function format_to_line()
    local line = m_fields[1]
    if m_size == 1 then
        --- Center Align
        local space = math.floor((m_win_width - m_item_width[1]) / 2)
        line = (' '):rep(space) .. line
    else
        local space = math.floor((m_win_width - m_tot_width) / m_size - 1)
        for i = 2, m_size do
            line = line .. (' '):rep(space) .. m_fields[i]
        end
    end
    return line
end

local function sort_tables()
    table.sort(m_item_width, function(a, b)
        return a > b
    end)

    table.sort(m_fields, function(a, b)
        return a:width() > b:width() -- 需要按照width排序
    end)
end

local function format_to_multilines(rows, cols)
    local lines = {}

    local rest = m_size % cols
    if rest == 0 then
        rest = cols
    end

    local s_width = m_item_width[1] -- 列中最宽的字符串宽度
    for i = 1, rows do
        local idx = s_to_b and rows - i + 1 or i
        lines[idx] = {}

        local space = (' '):rep(s_width - m_item_width[i])
        local item = m_fields[i] .. space

        lines[idx][1] = item
        lines[idx].interval = m_interval
    end


    local index = rows + 1 -- 最宽字符的下标

    for j = 2, cols do -- 以列为单位遍历
        s_width = m_item_width[index]
        local stop = (j > rest and rows - 1 or rows)
        for i = 1, stop do
            local idx      = s_to_b and stop - i + 1 or i -- 当前操作的行数
            local item_idx = index + i - 1 -- 当前操作的字段数
            local space    = (' '):rep(s_width - m_item_width[item_idx]) -- 对齐空格
            local item     = m_fields[item_idx] .. space

            lines[idx][j] = item -- 插入图标
        end
        index = index + stop -- 更新最宽字符的下标
    end

    return lines -- TODO : evaluate the width
end

local function formatted_lines()
    local lines = {}
    -- NOTE : 判断能否格式化成一行
    if m_tot_width + (m_size * m_indent) > m_win_width then
        sort_tables()
        --- NOTE ： 计算应该格式化成多少行和列
        local rows, cols = caculate_format()
        lines = format_to_multilines(rows, cols)
    else
        lines[1] = format_to_line()
    end

    return lines
end

-- EXAMPLE : 接受的形式
-- local content = {
--     { word, 'TransWord' },
--     { phonetic, 'TransPhonetic' },
--     collins,
--     oxford
--     -- { phonetic, 'TransPhonetic' },
--  NOTE :
-- 可选的:
-- 1. highlight 整个content的高亮
-- 2. indent    缩进
-- 2. space     各个组件的及间隔
-- }


-- EXAMPLE : 返回的形式
-- local lines = {
--     { items, opts },
--     { items, opts },
--     { items, opts },
--     -- items: string[]
--     -- opts {
--     --     highlight
--     --     indent
--     -- }
-- }


---@alias formatted_items table
---将组件格式化成相应的vim支持的lines格式
---@param win_size string 窗口的宽度和高度
---@param component table 需要格式化的字段
---@return formatted_items[] lines
M.format = function(win_width, component)
    type_check {
        style = { style, { 'string' } },
        component = { component, { 'table' } },
    }

    local length = 0
    local width = 0
    local item_size = {}
    for i, v in ipairs(fields) do
        width = v:width()
        item_size[i] = width
        length = length + width
    end

    m_win_width  = win_width
    m_fields     = fields
    m_size       = #m_fields
    m_tot_width  = length
    m_item_width = item_size

    return formatted_lines()
end


---合并多个数组, 第一个数组将会被使用
---@param ... string[] 需要被合并的数组
---@return table res   合并后的数组
M.extend_array = function(...)
    local arrays = { ... }
    local res = arrays[1]
    local index = #res
    for i = 2, #arrays do
        for _, value in ipairs(arrays[i]) do
            res[index] = value
            index = index + 1
        end
    end
    return res
end


return M

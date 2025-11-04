-- reference: https://docs.fluentbit.io/manual/filter/lua#callback-prototype

JSON = require("/fluent-bit/etc/JSON")

-- record["log"] comes as:
--    'This is the first line\n{\"log\":\" and this is #2\",\"stream\":\"stdout\",\"attrs\":{\"io.kubernetes.container.name\":\"main\",\"io.kubernetes.pod.name\":\"my-pod\",\"io.kubernetes.pod.namespace\":\"dev\"},\"time\":\"2019-02-18T14:26:15.303296418Z\"}\n{\"log\":\" and this is #3\",\"stream\":\"stdout\",\"attrs\":{\"io.kubernetes.container.name\":\"main\",\"io.kubernetes.pod.name\":\"my-pod\",\"io.kubernetes.pod.namespace\":\"dev\"},\"time\":\"2019-02-18T14:26:16.303296418Z\"}\n{\"log\":\" and this is #4\",\"stream\":\"stdout\",\"attrs\":{\"io.kubernetes.container.name\":\"main\",\"io.kubernetes.pod.name\":\"my-pod\",\"io.kubernetes.pod.namespace\":\"dev\"},\"time\":\"2019-02-18T14:26:17.303296418Z\"}\n{\"log\":\" and this is #5\",\"stream\":\"stdout\",\"attrs\":{\"io.kubernetes.container.name\":\"main\",\"io.kubernetes.pod.name\":\"my-pod\",\"io.kubernetes.pod.namespace\":\"dev\"},\"time\":\"2019-02-18T14:26:18.303296418Z\"}'
-- with '<first line's log>\n<escaped json of multi line>\n<escaped json of multi line>'
local function merge_log(record)
    if record["log"] then
        local buff = {}
        local str = record["log"]

        -- init positions
        local pos, end_pos = 1, str.len(str)

        -- if 'log' contains '\n', it **might** be our dirty hack that is appending multi lines logs to
        -- the same field (in their raw json format)
        local first_line = str:match("[^\n]+")

        if first_line then
            -- this dirty hack is a quick workaround as the first_line is not properly escaped by lua,
            -- while other lines are escaped by the JSON library
            local l = string.gsub(first_line, "\\n", "\n")
            table.insert(buff, l)
            pos = str.len(first_line) + 1
        end

        -- trying to recursively JSON parse the rest of the string to extract the value of 'log'
        while(pos < end_pos)
        do
            local success, value, next_i = pcall(JSON.grok_one, JSON, str, pos, {})
            if success then
                table.insert(buff, value["log"])
                pos = next_i
            else
                -- if we can't parse as JSON, just append the rest of the line into the buffer
                table.insert(buff, string.sub(str, pos))
                break
            end
        end

        record["log"] = table.concat(buff, "")
    end

    return record
end

function process(tag, timestamp, record)
    return 1, timestamp, merge_log(record)
end
-- Shared helper so price text looks right whether or not the schema
-- defines a custom currency (ix.currency.Get formats things like "$50"
-- or "50 credits" depending on the schema's setup).
function PLUGIN:FormatMoney(amount)
    amount = math.floor(tonumber(amount) or 0)

    if (ix.currency and ix.currency.Get) then
        local ok, result = pcall(ix.currency.Get, amount)

        if (ok and result) then
            return result
        end
    end

    return "$" .. amount
end

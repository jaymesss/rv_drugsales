local QBCore = exports[Config.CoreName]:GetCoreObject()

QBCore.Functions.CreateCallback('rv_drugsales:server:GetItemAmount', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local item = Player.Functions.GetItemByName(item)
    if item == nil then
        TriggerClientEvent('QBCore:Notify', src, Locale.Error.missing_drug, 'error')
        cb(0)
        return
    end
    cb(item.amount)
end)

RegisterNetEvent('rv_drugsales:server:SellDrugs', function(drug, amount, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem(drug.ItemName, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ItemName], 'remove')
    Player.Functions.AddMoney('cash', price * amount)
end)
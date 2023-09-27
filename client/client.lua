local QBCore = exports[Config.CoreName]:GetCoreObject()
local CurrentDrug = nil
local CurrentSell = nil
local Blip = nil
local Ped = nil
local Negotiated = false
local SellingAmount = 0
local BuyingPrice = 0

Citizen.CreateThread(function()
    for k,v in pairs(Config.PhoneBoothModels) do
        exports[Config.TargetName]:AddTargetModel(v, {
            options = {
                {
                    type = "client",
                    event = "rv_drugsales:client:OpenPhoneBooth",
                    icon = "fas fa-pills",
                    label = Locale.Info.phone_booth_target
                }
            }
        })
    end
end)

RegisterNetEvent('rv_drugsales:client:OpenPhoneBooth', function ()
    local options = {}
    for k,v in pairs(Config.Drugs) do
        options[#options+1] = {
            title = Locale.Info.sell .. ' ' .. v.Name,
            description = v.Description,
            icon = v.Icon,
            onSelect = function()
                TriggerEvent('rv_drugsales:client:SellDrug', v)
            end
        }
    end
    lib.registerContext({
        id = 'drug_phonebooth',
        title = Locale.Info.sell_drugs,
        options = options,
    })
    lib.showContext('drug_phonebooth')
end)

RegisterNetEvent('rv_drugsales:client:SellDrug', function(drug)
    local p = promise.new()
    local amount
    QBCore.Functions.TriggerCallback('rv_drugsales:server:GetItemAmount', function(result)
        p:resolve(result)
    end, drug.ItemName)
    amount = Citizen.Await(p)
    if amount <= 0 then
        return
    end
    QBCore.Functions.Notify(Locale.Success.looking_for_buyer, 'success', 5000)
    -- Citizen.Wait(5000)
    Citizen.Wait(60000, 180000)
    BuyingPrice = math.random(drug.SellPrice.minimum, drug.SellPrice.maximum)
    SellingAmount = math.random(1, amount)
    TriggerServerEvent(Config.PhoneMailEvent, {
        sender = Locale.Info.mail_sender,
        subject = Locale.Info.mail_subject,
        message = string.gsub(string.gsub(Locale.Info.mail_message, 'amount', BuyingPrice), 'count', SellingAmount),
        button = {}
    })
    CurrentDrug = drug

    CurrentSell = Config.Clients[math.random(#Config.Clients)]
    Blip = AddBlipForCoord(CurrentSell.x, CurrentSell.y, CurrentSell.z)
    SetBlipSprite(Blip, 8)
    SetBlipColour(Blip, 3)
    SetBlipRoute(Blip, true)
    SetBlipRouteColour(Blip, 3)
    local model = Config.PedModels[math.random(#Config.PedModels)]
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Wait(1)
    end
    Ped = CreatePed(5, GetHashKey(model), vector3(CurrentSell.x, CurrentSell.y, CurrentSell.z - 1), false, false)
    FreezeEntityPosition(Ped, true)
    SetEntityInvincible(Ped, true)
    SetBlockingOfNonTemporaryEvents(Ped, true)
    SetEntityHeading(Ped, CurrentSell.w)
    exports[Config.TargetName]:AddBoxZone('sell-drugs', vector3(CurrentSell.x, CurrentSell.y, CurrentSell.z), 1.5, 1.6, {
        name = "sell-drugs",
        heading = CurrentSell.w,
        debugPoly = false
    }, {
        options = {
            {
                type = "client",
                action = function()
                    exports[Config.TargetName]:RemoveZone('sell-drugs')
                    local p = promise.new()
                    local amount
                    QBCore.Functions.TriggerCallback('rv_drugsales:server:GetItemAmount', function(result)
                        p:resolve(result)
                    end, CurrentDrug.ItemName)
                    amount = Citizen.Await(p)
                    if amount < SellingAmount then
                        QBCore.Functions.Notify(Locale.Error.missing_drugs, 'error', 5000)
                        RemoveJob()
                        return
                    end
                    LoadAnimDict('pickup_object')
                    TaskPlayAnim(PlayerPedId(), "pickup_object", "pickup_low", 8.0, -8.0, -1, 0, 0, false, false, false)
                    QBCore.Functions.Progressbar("selling", Locale.Info.selling_drugs, math.random(5000, 12500), false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true
                    }, {
                    }, {}, {}, function() -- Done
                        ClearPedTasks(PlayerPedId())
                        LoadAnimDict('mp_ped_interaction')
                        TaskPlayAnim(PlayerPedId(), 'mp_ped_interaction', "handshake_guy_a", 8.0, 8.0, -1, 0, 0, false, false, false)
                        TaskPlayAnim(Ped, 'mp_ped_interaction', "handshake_guy_a", 8.0, 8.0, -1, 0, 0, false, false, false)
                        Wait(2800)
                        ClearPedTasks(PlayerPedId())
                        ClearPedTasks(Ped)
                        TriggerServerEvent('rv_drugsales:server:SellDrugs', CurrentDrug, SellingAmount, BuyingPrice)
                        RemoveJob()
                    end, function() -- Cancel
                    end)
                end,
                icon = "fas fa-pills",
                label = Locale.Info.sell_drugs
            },
            {
                type = "client",
                action = function()
                    if Negotiated then
                        QBCore.Functions.Notify(Locale.Error.already_negotiated, 'error', 5000)
                        return
                    end
                    Negotiated = true
                    TriggerEvent('animations:client:EmoteCommandStart', {"hhands"})
                    QBCore.Functions.Progressbar("negotiating", Locale.Info.negotiating, 5000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true
                    }, {
                    }, {}, {}, function() -- Done
                        TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                        local amount = math.random(10, 35)
                        if math.random(100) < 50 then
                            BuyingPrice = BuyingPrice + amount 
                            QBCore.Functions.Notify(string.gsub(Locale.Success.brought_price_up, 'amount', BuyingPrice), 'success', 5000)
                            return
                        end
                        BuyingPrice = BuyingPrice - amount 
                        QBCore.Functions.Notify(string.gsub(Locale.Error.brought_price_down, 'amount', BuyingPrice), 'error', 5000)

                    end, function() -- Cancel
                    end)
                end,
                icon = "fas fa-cash-register",
                label = Locale.Info.negotiate  
            },
            {
                type = "client",
                action = function()
                    exports[Config.TargetName]:RemoveZone('sell-drugs')
                    TriggerEvent('animations:client:EmoteCommandStart', {"wave4"})
                    QBCore.Functions.Progressbar("negotiating", Locale.Info.cancelling_sale, 2000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true
                    }, {
                    }, {}, {}, function() -- Done
                        QBCore.Functions.Notify(Locale.Success.job_cancelled, 'success', 5000)
                        RemoveJob()
                        TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    end, function() -- Cancel
                    end)
                end,
                icon = "fas fa-x",
                label = Locale.Info.cancel_sale  
            }
        }
    })
end)

function RemoveJob()
    RemoveBlip(Blip)
    local CurrentDrug = nil
    local CurrentSell = nil
    local Blip = nil
    FreezeEntityPosition(Ped, false)
    SetEntityInvincible(Ped, false)
    SetBlockingOfNonTemporaryEvents(Ped, false)
    local Ped = nil
    local SellingAmount = 0
    local BuyingPrice = 0
end

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

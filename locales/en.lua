local Translations = {
    error = {
        ["canceled"] = "Canceled",
        ["911_chatmessage"] = "911 MESSAGE",
        ["take_off"] = "/divingsuit to take off your diving suit",
        ["not_wearing"] = "You are not wearing a diving gear ..",
        ["no_coral"] = "You don't have any coral to sell..",
        ["not_standing_up"] = "You need to be standing up to put on the diving gear",
    },
    success = {
        ["took_out"] = "You took your wetsuit off",
    },
    info = {
        ["collecting_coral"] = "Collecting coral",
        ["diving_area"] = "Diving Area",
        ["collect_coral"] = "Collect coral",
        ["collect_coral_dt"] = "[E] - Collect Coral",
        ["checking_pockets"] = "Checking Pockets To Sell Coral",
        ["sell_coral"] = "Sell Coral",
        ["sell_coral_dt"] = "[E] - Sell Coral",
        ["blip_text"] = "911 - Dive Site",
        ["put_suit"] = "Putting on a diving suit",
        ["pullout_suit"] = "Taking off your diving suit ..",
        ["cop_msg"] = "This coral may be stolen",
        ["cop_title"] = "Illegal diving",
        ["command_diving"] = "Take off your diving suit",
    },
    warning = {
        ["oxygen_five_minutes"] = "You have 5 minutes of air remaining",
        ["oxygen_one_minute"] = "You have less than 1 minute of air remaining",
        ["oxygen_running_out"] = "Your diving gear is running out of air",
    },
}
Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
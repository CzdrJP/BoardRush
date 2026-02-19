return {
	REMOTE_EVENT_NAME = "RequestEquipSkateboard",
	REMOTE_PURCHASE_NAME = "RequestPurchaseSkateboard",
	
	-- Player Attributes
	ATTR_IS_EQUIPPED = "SkateboardEquipped", -- boolean
	ATTR_EQUIPPED_ID = "EquippedSkateboard", -- string
	ATTR_UNLOCKED_PREFIX = "ItemUnlocked_",  -- boolean (e.g. ItemUnlocked_Skateboard2)
	
	-- Model Names
	DEFAULT_BOARD_NAME = "Skateboard",
	EQUIPPED_INSTANCE_NAME = "EquippedSkateboard",
	
	-- ボードリスト（複数ボード対応）
	BOARD_LIST = {
		{ id = "Skateboard",  displayName = "Skateboard",  templateName = "SkateboardTemplate",  price = 0 },
		{ id = "Skateboard2", displayName = "Skateboard2", templateName = "SkateboardTemplate2", price = 1000 },
	},
}
